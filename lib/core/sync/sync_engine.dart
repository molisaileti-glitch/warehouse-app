import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/enums/sync_status.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart'
    as repository_providers;
import 'package:warehouse_app/features/additional.data/amcos/presentation/providers/amcos_providers.dart';
import 'package:warehouse_app/features/additional.data/crop/presentation/providers/crop_providers.dart';
import 'package:warehouse_app/features/additional.data/location/presentation/providers/location_providers.dart';
import 'package:warehouse_app/features/farmer/presentation/providers/farmer_providers.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_model.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_providers.dart';
import 'package:warehouse_app/features/warehouse/domain/models/warehouse_model.dart';
import 'package:warehouse_app/features/warehouse/presentation/providers/warehouse_providers.dart';
import 'package:warehouse_app/features/worker/presentation/providers/worker_providers.dart';

const _maxRetries = 5;
const _batchSize = 30;
const _lastSyncKey = 'last_sync_timestamp';
const _syncableEntityTypes = <String>{
  'amcos',
  'warehouses',
  'users',
  'farmers',
  'farmerDependants',
  'farmerHarvests',
  'dispatches',
  'stockCounts',
  'stockAdjustments',
};

class SyncManager {
  final Dio _dio;
  final SyncQueueDao _syncDao;
  final WarehouseDao _warehouseDao;
  final InventoryDao _inventoryDao;
  final WarehouseOperationsDao _warehouseOperationsDao;
  final AuditLogDao _auditDao;
  final HarvestDao _harvestDao;
  final FarmerDao _farmerDao;
  final AmcosDao _amcosDao;
  final SyncRoleStrategy _roleStrategy;
  final Future<int> Function() _currentMcuId;

  SyncManager({
    required Dio dio,
    required SyncQueueDao syncDao,
    required WarehouseDao warehouseDao,
    required InventoryDao inventoryDao,
    required WarehouseOperationsDao warehouseOperationsDao,
    required AuditLogDao auditDao,
    required HarvestDao harvestDao,
    required FarmerDao farmerDao,
    required AmcosDao amcosDao,
    required SyncRoleStrategy roleStrategy,
    required Future<int> Function() currentMcuId,
  })  : _dio = dio,
        _syncDao = syncDao,
        _warehouseDao = warehouseDao,
        _inventoryDao = inventoryDao,
        _warehouseOperationsDao = warehouseOperationsDao,
        _auditDao = auditDao,
        _harvestDao = harvestDao,
        _farmerDao = farmerDao,
        _amcosDao = amcosDao,
        _roleStrategy = roleStrategy,
        _currentMcuId = currentMcuId;

  Future<SyncResult> sync() async {
    var pushed = 0;
    var pulled = 0;
    final errors = <String>[];

    // Recover any entries that were wrongly stuck in 'conflict' by a prior
    // version of the sync logic that treated 400/422 as permanent conflicts.
    await _syncDao.resetConflictsToPending();

    try {
      pushed = await _push();
    } catch (e) {
      errors.add('Push failed: $e');
    }

    try {
      pulled = await _roleStrategy.pull(await _getLastSyncTime());
      await _saveLastSyncTime(DateTime.now());
    } catch (e) {
      errors.add('Pull failed: $e');
    }

    await _syncDao.purgeSync();
    return SyncResult(pushed: pushed, pulled: pulled, errors: errors);
  }

  Future<int> pullReferenceData({DateTime? since}) {
    return _roleStrategy.pullReferenceData(since: since);
  }

  Future<int> _push() async {
    final batch = await _syncDao.getNextBatch(
      limit: _batchSize,
      entityTypes: _syncableEntityTypes,
    );
    var successCount = 0;

    for (final entry in batch) {
      if (entry.retryCount >= _maxRetries) {
        await _syncDao.markConflict(entry.id);
        continue;
      }

      try {
        await _pushEntry(entry);
        await _syncDao.markSynced(entry.id);
        await _markEntitySynced(entry.entityType, entry.entityId);
        successCount++;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        developer.log(
          '[SyncPush] entity=${entry.entityType} operation=${entry.operation} '
          'path=${e.requestOptions.path} status=$status response=${e.response?.data}',
          name: 'sync.push',
        );
        if (status == 409) {
          await _syncDao.markConflict(entry.id);
          await _markEntityConflict(entry.entityType, entry.entityId);
        } else {
          // 400/422 are validation errors — the payload may be fixable on the
          // next sync (e.g. a parent reference that wasn't synced yet).
          // Treat them as retryable failures, not permanent conflicts.
          await _syncDao.recordFailureWithCount(entry.id, entry.retryCount + 1);
        }
      } catch (e, stackTrace) {
        developer.log(
          '[SyncPush] entity=${entry.entityType} operation=${entry.operation} failed=$e',
          name: 'sync.push',
          error: e,
          stackTrace: stackTrace,
        );
        await _syncDao.recordFailureWithCount(entry.id, entry.retryCount + 1);
      }
    }

    return successCount;
  }

  Future<void> _pushEntry(SyncQueueData entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    if (entry.entityType == 'amcos' && entry.operation == 'create') {
      final response = await _dio.post('/amcos', data: payload);
      await _applyAmcosCreateResponse(
        uuid: entry.entityId,
        responseData: response.data,
      );
      return;
    }
    if (entry.entityType == 'farmerDependants' && entry.operation == 'create') {
      await _pushFarmerDependant(payload);
      return;
    }
    if (entry.entityType == 'warehouses' && entry.operation != 'delete') {
      payload['mcu'] = await _currentMcuId();
      await _resolveAmcosReference(payload);
    }
    if (entry.entityType == 'farmers' && entry.operation != 'delete') {
      await _resolveAmcosReference(payload);
    }
    if (entry.entityType == 'users' && entry.operation != 'delete') {
      payload['uuid'] ??= entry.entityId;
      await _resolveAmcosReference(payload);
      await _resolveUserWarehouse(payload);
      payload.remove('amcosId');
      payload.remove('amcos_id');
    }
    if (entry.entityType == 'farmerHarvests' && entry.operation != 'delete') {
      await _resolveAmcosReference(payload);
      await _resolveHarvestWarehouse(payload, entry.entityId);
      await _resolveHarvestFarmer(payload);
      _normalizeHarvestBagTags(payload);
    }
    final path = _entityPath(entry.entityType, entry.entityId);

    switch (entry.operation) {
      case 'create':
        Response<dynamic> response;
        try {
          response = await _dio.post(
            _entityCollectionPath(entry.entityType),
            data: payload,
          );
        } on DioException catch (e) {
          if (entry.entityType == 'farmers' &&
              await _linkDuplicateFarmer(
                uuid: entry.entityId,
                payload: payload,
                error: e,
              )) {
            return;
          }
          rethrow;
        }
        if (entry.entityType == 'warehouses') {
          await _applyWarehouseCreateResponse(
            localId: entry.entityId,
            responseData: response.data,
          );
          developer.log(
            '[WarehouseSync] create mcu=${payload['mcu']} '
            'response=${response.data}',
            name: 'sync.warehouse',
          );
        } else if (entry.entityType == 'farmerHarvests') {
          developer.log(
            '[HarvestSync] create uuid=${entry.entityId} '
            'response=${response.data}',
            name: 'sync.harvest',
          );
        } else if (entry.entityType == 'farmers') {
          await _applyFarmerCreateResponse(
            uuid: entry.entityId,
            responseData: response.data,
          );
        } else if (entry.entityType == 'users') {
          _logUserSyncResponse(
            operation: 'create',
            payload: payload,
            responseData: response.data,
          );
        }
        break;
      case 'update':
        final response = await _dio.patch(path, data: payload);
        if (entry.entityType == 'users') {
          _logUserSyncResponse(
            operation: 'update',
            payload: payload,
            responseData: response.data,
          );
        }
        break;
      case 'delete':
        await _dio.delete(path);
        break;
    }
  }

  Future<bool> _linkDuplicateFarmer({
    required String uuid,
    required Map<String, dynamic> payload,
    required DioException error,
  }) async {
    final status = error.response?.statusCode;
    final message = error.response?.data?.toString().toLowerCase() ?? '';

    // Case 1: UUID duplicate — server says "Farmer with uuid X already exist".
    // Fetch the existing farmer by UUID and mark it synced locally.
    if (status == 400 &&
        message.contains('uuid') &&
        message.contains('already exist')) {
      try {
        final amcosId = _int(payload['amcos']);
        if (amcosId == null || amcosId <= 0) return false;
        final response = await _dio.get('/farmers/amcos/$amcosId');
        final rows = _asList(response.data);
        final matched = rows.cast<Map<String, dynamic>?>().firstWhere(
            (r) => r?['uuid']?.toString() == uuid,
            orElse: () => null);
        if (matched == null) return false;
        matched['uuid'] ??= uuid;
        final model = FarmerModel.fromJson(matched);
        if (model.id <= 0) return false;
        final local = await _farmerDao.getFarmerByUuid(uuid);
        // Resolve server AMCOS ID to local ID before upsert.
        final serverAmcosId = _int(matched['amcos']);
        if (serverAmcosId != null && serverAmcosId > 0) {
          final localAmcos = await _amcosDao.getAmcosByServerId(serverAmcosId);
          if (localAmcos != null && localAmcos.id != serverAmcosId) {
            matched['amcos'] = localAmcos.id;
          }
        }
        await _farmerDao.upsertFarmer(
          model.toCompanion(
            localId: local?.id ?? model.id,
            serverId: model.id,
            uuidOverride: uuid,
          ),
        );
        developer.log(
          '[FarmerSync] UUID duplicate resolved uuid=$uuid serverId=${model.id}',
          name: 'sync.farmer',
        );
        return true;
      } catch (_) {
        return false;
      }
    }

    // Case 2: AMCOS member ID duplicate — server says "amcos member id exists".
    final amcosId = _int(payload['amcos']);
    final amcosMemberId = payload['amcosMemberID']?.toString().trim();
    if (status != 400 ||
        amcosId == null ||
        amcosMemberId == null ||
        amcosMemberId.isEmpty ||
        !message.contains('amcos member id') ||
        !message.contains('exists')) {
      return false;
    }

    final response = await _dio.get('/farmers/amcos/$amcosId');
    final rows = _asList(response.data);
    final duplicate = rows.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row?['amcosMemberID']?.toString().trim() == amcosMemberId,
          orElse: () => null,
        );
    if (duplicate == null) return false;

    duplicate['uuid'] ??= uuid;
    final model = FarmerModel.fromJson(duplicate);
    if (model.id <= 0) return false;

    final local = await _farmerDao.getFarmerByUuid(uuid);
    await _farmerDao.upsertFarmer(
      model.toCompanion(
        localId: local?.id ?? model.id,
        serverId: model.id,
        uuidOverride: uuid,
      ),
    );

    developer.log(
      '[FarmerSync] linked duplicate amcosMemberID=$amcosMemberId '
      'uuid=$uuid serverId=${model.id}',
      name: 'sync.farmer',
    );
    return true;
  }

  Future<void> _applyAmcosCreateResponse({
    required String uuid,
    required Object? responseData,
  }) async {
    final data = _asMap(responseData);
    final serverId = _int(data['id']);
    if (serverId == null || serverId <= 0) {
      throw StateError('AMCOS create response has no server ID.');
    }
    await _amcosDao.markAmcosSynced(uuid, serverId: serverId);
    developer.log(
      '[AmcosSync] create uuid=$uuid serverId=$serverId',
      name: 'sync.amcos',
    );
  }

  Future<void> _applyFarmerCreateResponse({
    required String uuid,
    required Object? responseData,
  }) async {
    final data = _asMap(responseData);
    data['uuid'] ??= uuid;

    // The server returns the AMCOS by its server ID (e.g. amcos=9).
    // Locally, an offline-created AMCOS lives under a negative id.
    // Replace the server AMCOS id with the local id to satisfy FK constraints.
    final serverAmcosId = _int(data['amcos']);
    if (serverAmcosId != null && serverAmcosId > 0) {
      final localAmcos = await _amcosDao.getAmcosByServerId(serverAmcosId);
      if (localAmcos != null && localAmcos.id != serverAmcosId) {
        data['amcos'] = localAmcos.id; // use negative local id
      }
    }

    final model = FarmerModel.fromJson(data);
    if (model.id <= 0) {
      throw StateError('Farmer create response has no server ID.');
    }
    final local = await _farmerDao.getFarmerByUuid(uuid);
    await _farmerDao.upsertFarmer(
      model.toCompanion(
        localId: local?.id ?? model.id,
        serverId: model.id,
        uuidOverride: uuid,
      ),
    );
    developer.log(
      '[FarmerSync] create uuid=$uuid serverId=${model.id}',
      name: 'sync.farmer',
    );
  }

  Future<void> _applyWarehouseCreateResponse({
    required String localId,
    required Object? responseData,
  }) async {
    final data = _asMap(responseData);
    data['uuid'] ??= localId;
    final model = WarehouseModel.fromJson(data);
    if (int.tryParse(model.id) == null) {
      throw StateError('Warehouse create response has no server ID.');
    }

    await _warehouseDao.ensureWarehouseReferences(
      amcosId: model.amcos,
      amcosName: model.amcosName,
      mcu: _int(data['mcu'] ?? model.ownerId),
      mcuName: data['mcuName']?.toString() ?? data['mcu_name']?.toString(),
      villageId: model.village,
      villageName: model.villageName,
    );

    final companion = model.toCompanion(
      syncStatus: 'synced',
      updatedAt: model.updatedAt ?? DateTime.now(),
      syncedValue: true,
    );
    final existing = await _warehouseDao.getWarehouseByUuid(model.uuid);
    if (existing != null && existing.id != model.id) {
      await _warehouseDao.reconcileWarehouseId(
        localId: existing.id,
        serverWarehouse: companion,
      );
    } else {
      await _warehouseDao.upsertWarehouse(companion);
    }

    developer.log(
      '[WarehouseSync] reconciled local=$localId server=${model.id} '
      'uuid=${model.uuid}',
      name: 'sync.warehouse',
    );
  }

  /// Resolves the AMCOS reference in a push payload.
  ///
  /// Warehouses and farmers store the local AMCOS integer ID in their payload.
  /// If that ID is negative, the AMCOS was created offline and we must replace
  /// it with the real server ID before pushing.
  Future<int?> _resolveAmcosReference(Map<String, dynamic> payload) async {
    final rawAmcos =
        payload['amcos'] ?? payload['amcosId'] ?? payload['amcos_id'];
    final amcosId = _int(rawAmcos);
    if (amcosId == null || amcosId == 0) return null;

    // Negative ID → locally-created AMCOS. Look it up by local integer ID.
    final amcos = await _amcosDao.getAmcosById(amcosId);
    final serverId = amcosId < 0 ? amcos?.serverId : amcos?.serverId ?? amcosId;
    if (serverId == null || serverId <= 0) {
      throw StateError('AMCOS (id=$amcosId) has not been synced yet.');
    }
    payload['amcos'] = serverId;
    if (payload.containsKey('amcosId')) payload['amcosId'] = serverId;
    if (payload.containsKey('amcos_id')) payload['amcos_id'] = serverId;
    final amcosName = amcos?.name;
    if (amcosName != null) payload['amcosName'] = amcosName;
    // Some endpoints (e.g. collection-centers) also require the AMCOS UUID.
    final amcosUuid = amcos?.uuid;
    if (amcosUuid != null) payload['amcosUuid'] = amcosUuid;
    return serverId;
  }

  Future<void> _pushFarmerDependant(Map<String, dynamic> payload) async {
    final farmerUuid = payload.remove('farmerUuid')?.toString();
    if (farmerUuid == null || farmerUuid.isEmpty) {
      throw StateError('Dependant has no farmer UUID.');
    }
    // The endpoint path param is the farmer UUID (not the integer server ID).
    // Ensure the farmer is synced so the server can resolve the UUID.
    await _farmerServerId(farmerUuid); // throws if farmer not synced yet
    payload.remove('uuid');
    await _dio.post('/farmer-dependants/$farmerUuid', data: [payload]);
  }

  Future<void> _resolveHarvestFarmer(Map<String, dynamic> payload) async {
    final farmerUuid = payload['farmerUuid']?.toString();
    if (farmerUuid == null || farmerUuid.isEmpty) return;
    final serverId = await _farmerServerId(farmerUuid);
    payload['farmer'] = serverId;
    payload['guarantor'] = serverId;
  }

  Future<void> _resolveUserWarehouse(Map<String, dynamic> payload) async {
    final rawId = _referenceId(
      payload['warehouseId'] ??
          payload['warehouse_id'] ??
          payload['collectionCenterId'] ??
          payload['collection_center_id'] ??
          payload['collectionCenter'] ??
          payload['warehouse'],
    );
    if (rawId == null) return;

    final directServerId = int.tryParse(rawId);
    if (directServerId != null && directServerId > 0) {
      payload['collectionCenterId'] = directServerId;
      _removeUserWarehouseAliases(payload);
      return;
    }

    final warehouse = await _warehouseFromReference(rawId);
    final serverId = warehouse == null ? null : int.tryParse(warehouse.id);
    if (warehouse == null || serverId == null) {
      throw StateError('Worker warehouse $rawId has not synced yet.');
    }

    payload['collectionCenterId'] = serverId;
    _removeUserWarehouseAliases(payload);
    payload['collectionCenterName'] = warehouse.name;
  }

  void _removeUserWarehouseAliases(Map<String, dynamic> payload) {
    payload.remove('warehouseId');
    payload.remove('warehouse_id');
    payload.remove('warehouse');
    payload.remove('collectionCenter');
    payload.remove('collection_center_id');
  }

  Future<void> _resolveHarvestWarehouse(
    Map<String, dynamic> payload,
    String harvestUuid,
  ) async {
    final currentCollectionCenter = _int(payload['collectionCenter']);
    if (currentCollectionCenter != null && currentCollectionCenter > 0) {
      payload['collectionCenter'] = currentCollectionCenter;
      payload['collectionCenterId'] = currentCollectionCenter;
      return;
    }

    final payloadReference = _referenceId(
      payload['warehouseId'] ??
          payload['warehouseUuid'] ??
          payload['collectionCenterId'] ??
          payload['collection_center_id'] ??
          payload['warehouse'],
    );
    var warehouse = await _warehouseFromReference(payloadReference);

    final harvest = await _harvestDao.getHarvestByUuid(harvestUuid);
    warehouse ??= await _warehouseFromReference(harvest?.warehouseId);
    final collectionCenterId = warehouse == null
        ? harvest?.collectionCenter
        : int.tryParse(warehouse.id);
    if (collectionCenterId == null) {
      throw StateError('Harvest warehouse has not synced yet.');
    }

    payload['collectionCenter'] = collectionCenterId;
    payload['collectionCenterId'] = collectionCenterId;
    if (warehouse != null) {
      payload['warehouseId'] = warehouse.id;
      payload['collectionCenterName'] = warehouse.name;
    }
  }

  Future<Warehouse?> _warehouseFromReference(String? reference) async {
    if (reference == null || reference.isEmpty) return null;
    return await _warehouseDao.getWarehouseById(reference) ??
        await _warehouseDao.getWarehouseByUuid(reference);
  }

  String? _referenceId(Object? value) {
    if (value is Map) {
      return _referenceId(
        value['id'] ??
            value['warehouseId'] ??
            value['collectionCenterId'] ??
            value['collectionCenter'],
      );
    }
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<int> _farmerServerId(String uuid) async {
    final farmer = await _farmerDao.getFarmerByUuid(uuid);
    final serverId =
        farmer?.serverId ?? ((farmer?.id ?? 0) > 0 ? farmer!.id : null);
    if (serverId == null) {
      throw StateError('Farmer $uuid has not synced yet.');
    }
    return serverId;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return Map.of(value);
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  void _logUserSyncResponse({
    required String operation,
    required Map<String, dynamic> payload,
    required Object? responseData,
  }) {
    developer.log(
      '[WorkerSync] $operation payload=${_redactForLog(payload)} '
      'response=${_redactForLog(responseData)}',
      name: 'sync.worker',
    );
  }

  Object? _redactForLog(Object? value) {
    if (value is Map) {
      return value.map((key, item) {
        final textKey = key.toString();
        final normalized = textKey.toLowerCase();
        final shouldRedact =
            normalized.contains('password') || normalized.contains('token');
        return MapEntry(
          textKey,
          shouldRedact ? '<redacted>' : _redactForLog(item),
        );
      });
    }
    if (value is List) {
      return value.map(_redactForLog).toList();
    }
    return value;
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    final raw = value is Map<String, dynamic>
        ? value['content'] ??
            value['records'] ??
            value['results'] ??
            value['data']
        : value;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => row.map((key, item) => MapEntry(key.toString(), item)))
        .toList();
  }

  int? _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _markEntitySynced(String entityType, String entityId) async {
    switch (entityType) {
      case 'amcos':
        // serverId is already written by _applyAmcosCreateResponse.
        // No extra action needed here.
        break;
      case 'warehouses':
        await _warehouseDao.markWarehouseSynced(entityId);
        break;
      case 'farmers':
        await _farmerDao.markFarmerSynced(entityId);
        break;
      case 'farmerDependants':
        await _farmerDao.markDependantSynced(entityId);
        break;
      case 'inventoryItems':
        await _inventoryDao.markItemSynced(entityId);
        break;
      case 'stockMovements':
        await _inventoryDao.markMovementSynced(entityId);
        break;
      case 'dispatches':
        await _warehouseOperationsDao.markDispatchSynced(entityId);
        break;
      case 'stockCounts':
        await _warehouseOperationsDao.markStockCountSynced(entityId);
        break;
      case 'stockAdjustments':
        await _warehouseOperationsDao.markStockAdjustmentSynced(entityId);
        break;
      case 'auditLogs':
        await _auditDao.markLogSynced(entityId);
        break;
      case 'farmerHarvests':
        await _harvestDao.markHarvestSynced(entityId);
        break;
      case 'users':
        await _roleStrategy.markUserSynced(entityId);
        break;
    }
  }

  Future<void> _markEntityConflict(String entityType, String entityId) async {
    switch (entityType) {
      case 'warehouses':
        await _warehouseDao.markWarehouseConflict(entityId);
        break;
      case 'inventoryItems':
        await _inventoryDao.markItemConflict(entityId);
        break;
      case 'dispatches':
        await _warehouseOperationsDao.markDispatchConflict(entityId);
        break;
      case 'stockCounts':
        await _warehouseOperationsDao.markStockCountConflict(entityId);
        break;
      case 'stockAdjustments':
        await _warehouseOperationsDao.markStockAdjustmentConflict(entityId);
        break;
      case 'farmerHarvests':
        await _harvestDao.markHarvestConflict(entityId);
        break;
      case 'users':
        await _roleStrategy.markUserConflict(entityId);
        break;
    }
  }

  Future<DateTime?> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastSyncKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, time.toIso8601String());
  }

  String _entityPath(String type, String id) => '/${_typeToPath(type)}/$id/';

  void _normalizeHarvestBagTags(Map<String, dynamic> payload) {
    final bags = payload['farmerBags'];
    if (bags is! List) return;

    for (final bag in bags.whereType<Map>()) {
      if (bag['tagNumber'] == null && bag['tag'] != null) {
        bag['tagNumber'] = bag['tag'];
      }
      bag.remove('tag');
    }
  }

  String _entityCollectionPath(String type) {
    if (type == 'users') return '/users';
    if (type == 'warehouses') return '/collection-centers';
    if (type == 'amcos') return '/amcos';
    if (type == 'farmers') return '/farmers';
    if (type == 'farmerHarvests') return '/farmer-harvests';
    if (type == 'dispatches') return '/dispatches';
    if (type == 'stockCounts') return '/stock-counts';
    if (type == 'stockAdjustments') return '/stock-adjustments';
    return '/${_typeToPath(type)}/';
  }

  String _typeToPath(String type) => switch (type) {
        'amcos' => 'amcos',
        'warehouses' => 'collection-centers',
        'users' => 'users',
        'inventoryItems' => 'inventory',
        'stockMovements' => 'movements',
        'auditLogs' => 'audit-logs',
        'farmers' => 'farmers',
        'farmerDependants' => 'farmer-dependants',
        'farmerHarvests' => 'farmer-harvests',
        'dispatches' => 'dispatches',
        'stockCounts' => 'stock-counts',
        'stockAdjustments' => 'stock-adjustments',
        _ => type,
      };
}

abstract class SyncRoleStrategy {
  Future<int> pull(DateTime? since);
  Future<int> pullReferenceData({DateTime? since});
  Future<void> markUserSynced(String id);
  Future<void> markUserConflict(String id);
}

class OwnerSyncStrategy implements SyncRoleStrategy {
  final Ref _ref;
  OwnerSyncStrategy(this._ref);

  @override
  Future<int> pull(DateTime? since) async {
    var count = 0;
    count += await pullReferenceData(since: since);
    final mcuId = await _requireCurrentUserMcu(_ref);
    count +=
        await _ref.read(warehouseRepoProvider).pullFromServer(mcuId: mcuId);
    count += await _ref.read(workerRepoProvider).pullFromServer(mcuId: mcuId);
    final users = await _ref.read(workerDaoProvider).getAllUsers();
    final amcosIds = users
        .where((user) => user.mcu == mcuId && user.amcos != null)
        .map((user) => user.amcos!)
        .where((id) => id > 0)
        .toSet();
    final ownerAmcos = await _ref.read(amcosDaoProvider).getAmcosByMcu(mcuId);
    amcosIds.addAll(ownerAmcos.map((item) => item.id).where((id) => id > 0));
    count += await _ref
        .read(amcosRepositoryProvider)
        .pullByIds(amcosIds, since: since);
    count +=
        await _ref.read(farmerRepoProvider).pullFromServer(amcosIds: amcosIds);
    // Fix G: pull dependants for every synced farmer.
    final allFarmers = await _ref.read(farmerDaoProvider).getAllFarmers();
    count += await _ref
        .read(farmerRepoProvider)
        .pullDependantsForFarmers(allFarmers);
    count += await _ref
        .read(harvestRepositoryProvider)
        .pullFromServer(amcosIds: amcosIds);
    count += await _ref
        .read(repository_providers.warehouseOperationsRepoProvider)
        .pullForMcu(
          mcuId,
        );
    return count;
  }

  @override
  Future<int> pullReferenceData({DateTime? since}) async {
    var count = 0;
    final mcuId = await _requireCurrentUserMcu(_ref);
    count += await _ref.read(cropRepositoryProvider).pullDownstream();
    count += await _ref.read(harvestRepositoryProvider).pullReferenceData();
    count += await _ref
        .read(locationRepositoryProvider)
        .pullDownstream(since: since);
    count += await _ref
        .read(amcosRepositoryProvider)
        .pullDownstream(since: since, mcuId: mcuId);
    return count;
  }

  @override
  Future<void> markUserSynced(String id) {
    return _ref.read(workerDaoProvider).markUserSynced(id);
  }

  @override
  Future<void> markUserConflict(String id) {
    return _ref.read(workerDaoProvider).markUserConflict(id);
  }
}

class WorkerSyncStrategy implements SyncRoleStrategy {
  final Ref _ref;
  WorkerSyncStrategy(this._ref);

  @override
  Future<int> pull(DateTime? since) async {
    var count = 0;
    count += await pullReferenceData(since: since);
    final mcuId = await _requireCurrentUserMcu(_ref);
    count += await _ref.read(workerRepoProvider).pullFromServer(mcuId: mcuId);
    count +=
        await _ref.read(warehouseRepoProvider).pullFromServer(mcuId: mcuId);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      throw StateError('The signed-in worker could not be identified.');
    }
    final worker = await _ref.read(workerDaoProvider).getUserById(userId);
    final amcos = await _ref.read(amcosDaoProvider).getAmcosByMcu(mcuId);
    final amcosIds = amcos.map((item) => item.id).where((id) => id > 0).toSet();
    if (worker?.amcos != null && worker!.amcos! > 0) {
      amcosIds.add(worker.amcos!);
      count += await _ref
          .read(warehouseRepoProvider)
          .pullFromAmcos(amcosId: worker.amcos!);
    }

    var warehouseId = worker?.warehouseId;
    if (warehouseId == null || warehouseId.isEmpty) {
      final candidates = worker?.amcos == null
          ? const <Warehouse>[]
          : await _ref
              .read(warehouseDaoProvider)
              .getWarehousesByAmcos(worker!.amcos!);
      if (candidates.length == 1) {
        warehouseId = candidates.first.id;
        await _ref.read(workerDaoProvider).setUserWarehouse(
              id: userId,
              warehouseId: warehouseId,
            );
      } else if (candidates.isEmpty) {
        throw StateError('No warehouse found for this worker AMCOS.');
      } else {
        throw StateError('Select a warehouse before syncing.');
      }
    }

    final collectionCenterId = int.tryParse(warehouseId);
    if (collectionCenterId == null) {
      throw StateError('The active worker warehouse is not a server ID.');
    }

    count +=
        await _ref.read(farmerRepoProvider).pullFromServer(amcosIds: amcosIds);
    // Fix G: pull dependants for every synced farmer.
    final allFarmers = await _ref.read(farmerDaoProvider).getAllFarmers();
    count += await _ref
        .read(farmerRepoProvider)
        .pullDependantsForFarmers(allFarmers);
    count += await _ref
        .read(harvestRepositoryProvider)
        .pullFromCollectionCenter(collectionCenterId: collectionCenterId);
    final warehouse =
        await _ref.read(warehouseDaoProvider).getWarehouseById(warehouseId);
    if (warehouse != null) {
      count += await _ref
          .read(repository_providers.warehouseOperationsRepoProvider)
          .pullForCollectionCenter(warehouse: warehouse);
    }
    return count;
  }

  @override
  Future<int> pullReferenceData({DateTime? since}) async {
    var count = 0;
    final mcuId = await _requireCurrentUserMcu(_ref);
    count += await _ref.read(cropRepositoryProvider).pullDownstream();
    count += await _ref.read(harvestRepositoryProvider).pullReferenceData();
    count += await _ref
        .read(locationRepositoryProvider)
        .pullDownstream(since: since);
    count += await _ref
        .read(amcosRepositoryProvider)
        .pullDownstream(since: since, mcuId: mcuId);
    return count;
  }

  @override
  Future<void> markUserSynced(String id) async {}

  @override
  Future<void> markUserConflict(String id) async {}
}

Future<int> _requireCurrentUserMcu(Ref ref) async {
  final mcuId = await ref.read(currentUserMcuProvider.future);
  if (mcuId == null) {
    throw StateError('The signed-in user has no MCU assignment.');
  }
  return mcuId;
}

class SyncResult {
  final int pushed;
  final int pulled;
  final List<String> errors;
  bool get hasErrors => errors.isNotEmpty;

  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.errors,
  });
}

final syncManagerProvider = Provider<SyncManager>((ref) {
  final role = ref.watch(currentRoleProvider) ?? UserRole.worker;
  final strategy = switch (role) {
    UserRole.owner || UserRole.superAdmin => OwnerSyncStrategy(ref),
    UserRole.worker => WorkerSyncStrategy(ref),
  };

  return SyncManager(
    dio: ref.watch(apiClientProvider).dio,
    syncDao: ref.watch(syncQueueDaoProvider),
    warehouseDao: ref.watch(warehouseDaoProvider),
    inventoryDao: ref.watch(inventoryDaoProvider),
    warehouseOperationsDao: ref.watch(warehouseOperationsDaoProvider),
    auditDao: ref.watch(auditLogDaoProvider),
    harvestDao: ref.watch(harvestDaoProvider),
    farmerDao: ref.watch(farmerDaoProvider),
    amcosDao: ref.watch(amcosDaoProvider),
    roleStrategy: strategy,
    currentMcuId: () => _requireCurrentUserMcu(ref),
  );
});

final syncEngineProvider = syncManagerProvider;

class SyncNotifier extends StateNotifier<SyncState> {
  final SyncManager _manager;
  SyncNotifier(this._manager) : super(const SyncState.idle());

  Future<void> runSync() async {
    if (state.isSyncing) return;
    state = const SyncState.syncing();
    final result = await _manager.sync();
    state = result.hasErrors
        ? SyncState.error(result.errors.first)
        : SyncState.done(pushed: result.pushed, pulled: result.pulled);
  }
}

class SyncState {
  final bool isSyncing;
  final bool isDone;
  final String? error;
  final int pushed;
  final int pulled;

  const SyncState({
    this.isSyncing = false,
    this.isDone = false,
    this.error,
    this.pushed = 0,
    this.pulled = 0,
  });

  const SyncState.idle() : this();
  const SyncState.syncing() : this(isSyncing: true);
  factory SyncState.done({required int pushed, required int pulled}) =>
      SyncState(isDone: true, pushed: pushed, pulled: pulled);
  factory SyncState.error(String error) => SyncState(error: error);
  bool get hasErrors => error != null;
}

final syncNotifierProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref.watch(syncManagerProvider)),
);
