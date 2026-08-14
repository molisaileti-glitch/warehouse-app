import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_dependant_model.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_model.dart';
import 'package:warehouse_app/features/farmer/domain/repositories/farmer_repository.dart';

class DriftFarmerRepository implements FarmerRepository {
  final FarmerDao _dao;
  final CropDao _cropDao;
  final Dio _dio;

  const DriftFarmerRepository({
    required FarmerDao dao,
    required CropDao cropDao,
    required Dio dio,
  })  : _dao = dao,
        _cropDao = cropDao,
        _dio = dio;

  @override
  Stream<List<Farmer>> watchAllFarmers() => _dao.watchAllFarmers();

  @override
  Stream<Farmer?> watchFarmerById(int id) => _dao.watchFarmerById(id);

  @override
  Stream<List<FarmerDependant>> watchDependantsForFarmer(int farmerId) {
    return _dao.watchDependantsForFarmer(farmerId);
  }

  @override
  Future<int> pullFromServer({required Set<int> amcosIds}) async {
    var count = 0;
    final sortedIds = amcosIds.where((id) => id > 0).toList()..sort();

    for (final amcosId in sortedIds) {
      final response = await _dio.get('/farmers/amcos/$amcosId');
      final rows = _asList(response.data);
      for (final row in rows) {
        final model = FarmerModel.fromJson(row);
        if (model.id <= 0) continue;
        await _ensureCropReference(model.mainCrop);
        await _ensureCropReference(model.secondaryCrop);
        await _dao.upsertFarmer(model.toCompanion());
        count++;
      }
    }

    developer.log(
      '[FarmerSync] amcosIds=$sortedIds farmers=$count',
      name: 'sync.farmer',
    );
    return count;
  }

  @override
  Future<FarmerCreateResult> createFarmer({
    required FarmerCreateInput farmer,
    List<FarmerDependantInput> dependants = const [],
  }) async {
    try {
      final payload = {
        ...farmer.toJson(),
        'uuid': const Uuid().v4(),
      };
      developer.log('POST /farmers payload: $payload', name: 'farmer.api');
      final res = await _dio.post('/farmers', data: payload);
      final data = _asMap(res.data);
      final model = FarmerModel.fromJson(data);
      await _ensureCropReference(model.mainCrop);
      await _ensureCropReference(model.secondaryCrop);
      await _dao.upsertFarmer(model.toCompanion());

      var createdDependants = 0;
      final dependantErrors = <String>[];
      for (final dependant in dependants) {
        final result = await addDependant(
          farmerId: model.id,
          dependant: dependant,
        );
        if (result.success) {
          createdDependants++;
        } else {
          dependantErrors.add(result.error ?? 'Failed to create dependant');
        }
      }

      final saved = await _dao.getFarmerById(model.id);
      return FarmerCreateResult.success(
        farmer: saved!,
        createdDependants: createdDependants,
        dependantErrors: dependantErrors,
      );
    } on DioException catch (e) {
      developer.log(
        'POST /farmers failed: '
        'status=${e.response?.statusCode}, data=${e.response?.data}',
        name: 'farmer.api',
      );
      return FarmerCreateResult.failure(_dioMessage(e));
    } catch (e) {
      return FarmerCreateResult.failure(e.toString());
    }
  }

  @override
  Future<FarmerDependantCreateResult> addDependant({
    required int farmerId,
    required FarmerDependantInput dependant,
  }) async {
    try {
      final beforeCount = (await _dao.getDependantsForFarmer(farmerId)).length;
      final payload = [dependant.toJson()];
      developer.log(
        'POST /farmer-dependants/$farmerId payload: $payload',
        name: 'farmer.api',
      );
      final res = await _dio.post(
        '/farmer-dependants/$farmerId',
        data: payload,
      );
      developer.log(
        'POST /farmer-dependants/$farmerId response: ${res.data}',
        name: 'farmer.api',
      );
      final data = _asMap(res.data);
      final responseDependants = data['dependants'] ?? data['farmerDependants'];
      if (responseDependants is List) {
        final farmerModel = FarmerModel.fromJson(data);
        if (farmerModel.id > 0) {
          await _ensureCropReference(farmerModel.mainCrop);
          await _ensureCropReference(farmerModel.secondaryCrop);
          await _dao.upsertFarmer(farmerModel.toCompanion());
        }
        final dependants = responseDependants
            .whereType<Map>()
            .map(
              (json) => FarmerDependantModel.fromJson(
                _asMap(json),
                fallbackFarmerId: farmerModel.id > 0
                    ? farmerModel.id
                    : farmerId,
              ).toCompanion(),
            )
            .toList();
        await _dao.upsertDependants(dependants);
        await _ensureDependantSaved(
          farmerId: farmerId,
          dependant: dependant,
          beforeCount: beforeCount,
        );
        return FarmerDependantCreateResult.success();
      }

      if (res.data is List) {
        final dependants = (res.data as List)
            .whereType<Map>()
            .map(
              (json) => FarmerDependantModel.fromJson(
                _asMap(json),
                fallbackFarmerId: farmerId,
              ).toCompanion(),
            )
            .toList();
        await _dao.upsertDependants(dependants);
        await _ensureDependantSaved(
          farmerId: farmerId,
          dependant: dependant,
          beforeCount: beforeCount,
        );
        return FarmerDependantCreateResult.success();
      }

      if (data.isNotEmpty && !_looksLikeDependant(data)) {
        final farmerModel = FarmerModel.fromJson(data);
        if (farmerModel.id > 0) {
          await _ensureCropReference(farmerModel.mainCrop);
          await _ensureCropReference(farmerModel.secondaryCrop);
          await _dao.upsertFarmer(farmerModel.toCompanion());
        }
        await _dao.deleteInvalidDependantsForFarmer(farmerId);
        await _insertLocalSubmittedDependant(
          farmerId: farmerId,
          dependant: dependant,
        );
        await _ensureDependantSaved(
          farmerId: farmerId,
          dependant: dependant,
          beforeCount: beforeCount,
        );
        return FarmerDependantCreateResult.success();
      }

      final dependantData = data.isEmpty
          ? _localDependantJson(farmerId: farmerId, dependant: dependant)
          : data;
      final model = FarmerDependantModel.fromJson(
        dependantData,
        fallbackFarmerId: farmerId,
      );
      await _dao.upsertDependant(model.toCompanion());
      await _ensureDependantSaved(
        farmerId: farmerId,
        dependant: dependant,
        beforeCount: beforeCount,
      );
      return FarmerDependantCreateResult.success();
    } on DioException catch (e) {
      developer.log(
        'POST /farmer-dependants/$farmerId failed: '
        'status=${e.response?.statusCode}, data=${e.response?.data}',
        name: 'farmer.api',
      );
      return FarmerDependantCreateResult.failure(_dioMessage(e));
    } catch (e) {
      developer.log(
        'POST /farmer-dependants/$farmerId failed: $e',
        name: 'farmer.api',
      );
      return FarmerDependantCreateResult.failure(e.toString());
    }
  }

  Future<void> _ensureDependantSaved({
    required int farmerId,
    required FarmerDependantInput dependant,
    required int beforeCount,
  }) async {
    final saved = await _dao.getDependantsForFarmer(farmerId);
    developer.log(
      'Local dependants for farmer $farmerId: '
      'before=$beforeCount, after=${saved.length}',
      name: 'farmer.local',
    );
    if (saved.length > beforeCount) return;

    final fallback = FarmerDependantModel.fromJson(
      _localDependantJson(farmerId: farmerId, dependant: dependant),
      fallbackFarmerId: farmerId,
    );
    await _dao.upsertDependant(fallback.toCompanion());
    final afterFallback = await _dao.getDependantsForFarmer(farmerId);
    developer.log(
      'Inserted local fallback dependant for farmer $farmerId. '
      'after=${afterFallback.length}',
      name: 'farmer.local',
    );
  }

  Future<void> _insertLocalSubmittedDependant({
    required int farmerId,
    required FarmerDependantInput dependant,
  }) async {
    final model = FarmerDependantModel.fromJson(
      _localDependantJson(farmerId: farmerId, dependant: dependant),
      fallbackFarmerId: farmerId,
    );
    await _dao.upsertDependant(model.toCompanion());
  }

  Map<String, dynamic> _localDependantJson({
    required int farmerId,
    required FarmerDependantInput dependant,
  }) {
    return {
      ...dependant.toJson(),
      'id': -DateTime.now().microsecondsSinceEpoch,
      'farmerId': farmerId,
    };
  }

  bool _looksLikeDependant(Map<String, dynamic> data) {
    return data.containsKey('relationship') && data.containsKey('gender');
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<Map<String, dynamic>> _asList(Object? data) {
    final raw = data is Map<String, dynamic>
        ? data['content'] ?? data['records'] ?? data['results'] ?? data['data']
        : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => _asMap(row))
        .toList();
  }

  Future<void> _ensureCropReference(int cropId) async {
    if (cropId <= 0) return;
    final existing = await _cropDao.getCropById(cropId);
    if (existing != null) return;
    await _cropDao.upsertCrops([
      CropTableCompanion.insert(
        id: Value(cropId),
        name: 'Crop #$cropId',
      ),
    ]);
  }

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'] ??
          data['detail'] ??
          data['messages'] ??
          data['errors'] ??
          data['violations'] ??
          data['error'];
      if (msg is String) return msg;
      if (msg is List) return msg.join(', ');
      if (msg is Map) {
        return msg.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(', ');
      }
    }
    if (data is String && data.trim().isNotEmpty) return data;
    return switch (e.response?.statusCode) {
      400 => 'Invalid farmer details.',
      401 => 'Please sign in again.',
      403 => 'You are not allowed to perform this action.',
      404 => 'The requested farmer was not found.',
      409 => 'A matching record already exists.',
      429 => 'Too many attempts. Try again shortly.',
      _ => e.message ?? 'Network error. Please try again.',
    };
  }
}
