import 'dart:convert';
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
        await _upsertServerFarmer(model);
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
      final uuid = const Uuid().v4();
      final localId = _localRowId(uuid);
      final now = DateTime.now();
      final payload = {...farmer.toJson(), 'uuid': uuid};
      final model = FarmerModel.fromJson({
        ...payload,
        'id': localId,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      final dependantRows = <FarmerDependantsCompanion>[];
      final queueEntries = <SyncQueueCompanion>[
        SyncQueueCompanion.insert(
          entityType: 'farmers',
          entityId: uuid,
          operation: 'create',
          payload: jsonEncode(payload),
          createdAt: Value(now),
        ),
      ];

      for (var index = 0; index < dependants.length; index++) {
        final dependant = dependants[index];
        final dependantUuid = const Uuid().v4();
        final dependantId = _localRowId(dependantUuid);
        dependantRows.add(
          FarmerDependantModel.fromJson({
            ...dependant.toJson(),
            'id': dependantId,
            'farmerId': localId,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          }).toCompanion(),
        );
        queueEntries.add(
          SyncQueueCompanion.insert(
            entityType: 'farmerDependants',
            entityId: dependantUuid,
            operation: 'create',
            payload: jsonEncode({
              'uuid': dependantUuid,
              'farmerUuid': uuid,
              ...dependant.toJson(),
            }),
            createdAt: Value(now.add(Duration(microseconds: index + 1))),
          ),
        );
      }

      await _dao.insertPendingFarmer(
        farmer: model.toCompanion(
          localId: localId,
          serverId: null,
          uuidOverride: uuid,
        ),
        dependants: dependantRows,
        queueEntries: queueEntries,
      );
      final saved = await _dao.getFarmerByUuid(uuid);
      return FarmerCreateResult.success(
        farmer: saved!,
        createdDependants: dependants.length,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Saving farmer locally failed',
        name: 'farmer.local',
        error: e,
        stackTrace: stackTrace,
      );
      return FarmerCreateResult.failure(e.toString());
    }
  }

  @override
  Future<FarmerDependantCreateResult> addDependant({
    required int farmerId,
    required FarmerDependantInput dependant,
  }) async {
    try {
      final farmer = await _dao.getFarmerById(farmerId);
      final farmerUuid = farmer?.uuid;
      if (farmer == null || farmerUuid == null || farmerUuid.isEmpty) {
        return FarmerDependantCreateResult.failure(
          'Farmer UUID is unavailable.',
        );
      }

      final uuid = const Uuid().v4();
      final now = DateTime.now();
      final model = FarmerDependantModel.fromJson({
        ...dependant.toJson(),
        'id': _localRowId(uuid),
        'farmerId': farmerId,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      await _dao.insertPendingDependant(
        dependant: model.toCompanion(),
        queueEntry: SyncQueueCompanion.insert(
          entityType: 'farmerDependants',
          entityId: uuid,
          operation: 'create',
          payload: jsonEncode({
            'uuid': uuid,
            'farmerUuid': farmerUuid,
            ...dependant.toJson(),
          }),
        ),
      );
      return FarmerDependantCreateResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Saving dependant locally failed',
        name: 'farmer.local',
        error: e,
        stackTrace: stackTrace,
      );
      return FarmerDependantCreateResult.failure(e.toString());
    }
  }

  Future<void> _upsertServerFarmer(
    FarmerModel model, {
    String? fallbackUuid,
  }) async {
    final uuid = model.uuid ?? fallbackUuid;
    final existing = uuid == null ? null : await _dao.getFarmerByUuid(uuid);
    await _dao.upsertFarmer(
      model.toCompanion(
        localId: existing?.id ?? model.id,
        serverId: model.id,
        uuidOverride: uuid,
      ),
    );
  }

  int _localRowId(String uuid) {
    final compact = uuid.replaceAll('-', '');
    final value = int.parse(compact.substring(0, 15), radix: 16);
    return value == 0 ? -1 : -value;
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
    return raw.whereType<Map>().map((row) => _asMap(row)).toList();
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
}
