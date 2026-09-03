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
        // Stamp the uuid and syncStatus so the sync engine can track this row.
        dependantRows.add(
          FarmerDependantModel.fromJson(
            {
              ...dependant.toJson(),
              'id': dependantId,
              'farmerId': localId,
              'uuid': dependantUuid,
              'createdAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            },
            farmerUuid: uuid,
          ).toCompanion(),
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
      // Stamp the uuid and syncStatus='pending' on the local row.
      final model = FarmerDependantModel.fromJson(
        {
          ...dependant.toJson(),
          'id': _localRowId(uuid),
          'farmerId': farmerId,
          'uuid': uuid,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        farmerUuid: farmerUuid,
      );
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

  /// Pulls all dependants for the given [farmers] from the server and saves
  /// them locally. Called after a farmer pull to ensure dependants are
  /// restored after a storage clear or fresh install.
  ///
  /// Skips farmers with no [Farmer.serverId] — they haven't been pushed yet
  /// and their dependants are still sitting in the local sync queue.
  @override
  Future<int> pullDependantsForFarmers(List<Farmer> farmers) async {
    var count = 0;
    for (final farmer in farmers) {
      final serverId = farmer.serverId;
      final farmerUuid = farmer.uuid?.trim();
      if (farmerUuid == null || farmerUuid.isEmpty) continue;
      var pulledForFarmer = 0;
      final path = '/farmer-dependants/$farmerUuid';
      try {
        final response = await _dio.get(path);
        final rows = _asList(response.data);
        developer.log(
          '[FarmerSync] dependants path=$path status=${response.statusCode} '
          'rows=${rows.length} data=${_previewForLog(response.data)}',
          name: 'sync.farmer',
        );
        for (final row in rows) {
          final model = FarmerDependantModel.fromJson(
            row,
            fallbackFarmerId: farmer.id,
            farmerUuid: farmer.uuid,
          );
          final localId = model.id > 0
              ? model.id
              : _localRowId(
                  model.uuid ??
                      '${farmer.id}-${model.firstName}-${model.lastName}',
                );
          // Dependants pulled from server are already synced — upsert preserves
          // any locally-created rows that may already exist.
          await _dao.upsertDependant(
            FarmerDependantsCompanion(
              id: Value(localId),
              farmerId: Value(farmer.id), // use local FK, not server FK
              uuid: Value(model.uuid),
              syncStatus: const Value('synced'),
              firstName: Value(model.firstName),
              middleName: Value(model.middleName),
              lastName: Value(model.lastName),
              relationship: Value(model.relationship),
              dob: Value(model.dob),
              gender: Value(model.gender),
              phoneNumber: Value(model.phoneNumber),
              address: Value(model.address),
              email: Value(model.email),
              createdAt: Value(model.createdAt),
              updatedAt: Value(model.updatedAt),
            ),
          );
          count++;
          pulledForFarmer++;
        }
      } on DioException catch (e) {
        developer.log(
          '[FarmerSync] dependants path=$path failed '
          'status=${e.response?.statusCode} data=${_previewForLog(e.response?.data)}',
          name: 'sync.farmer',
        );
        // Offline or endpoint not found — dependants are already in local DB.
      }
      if (pulledForFarmer == 0) {
        developer.log(
          '[FarmerSync] no dependants for farmer '
          'local=${farmer.id} server=$serverId uuid=$farmerUuid',
          name: 'sync.farmer',
        );
      }
    }
    developer.log(
      '[FarmerSync] pulled dependants=$count for farmers=${farmers.length}',
      name: 'sync.farmer',
    );
    return count;
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

  String _previewForLog(Object? data) {
    final text = data.toString();
    if (text.length <= 700) return text;
    return '${text.substring(0, 700)}...';
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
