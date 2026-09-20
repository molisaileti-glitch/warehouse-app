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

  Future<SyncResult> sync(
      {void Function(SyncProgress progress)? onProgress}) async {
    var pushed = 0;
    var pulled = 0;
    final errors = <String>[];
    final conflictDetails = <String>[];
    final runStartedAt = DateTime.now();

    void progress(int step, String message) {
      onProgress?.call(
        SyncProgress(currentStep: step, totalSteps: 5, message: message),
      );
      developer.log(
        '[SyncRun] step=$step/5 message="$message"',
        name: 'sync.run',
      );
    }

    developer.log(
      '[SyncRun] start at=${runStartedAt.toIso8601String()}',
      name: 'sync.run',
    );
    progress(1, 'Preparing local queue');

    await _syncDao.purgeUnsupportedEntityTypes();
    final pendingAfterPurge = await _syncDao.getPendingCount();
    developer.log(
      '[SyncRun] pendingAfterPurge=$pendingAfterPurge',
      name: 'sync.run',
    );

    try {
      progress(2, 'Uploading pending records');
      pushed = await _push(
        passName: 'before-pull',
        conflictDetails: conflictDetails,
      );
    } catch (e) {
      errors.add('Push failed: $e');
      developer.log('[SyncRun] pushFailed error=$e', name: 'sync.run');
    }

    try {
      progress(3, 'Downloading latest records');
      pulled = await _roleStrategy.pull(await _getLastSyncTime());
      developer.log('[SyncRun] pulled=$pulled', name: 'sync.run');
      final retriedAfterPull = await _push(
        passName: 'after-pull',
        conflictDetails: conflictDetails,
      );
      pushed += retriedAfterPull;
      progress(4, 'Saving sync checkpoint');
      await _saveLastSyncTime(DateTime.now());
    } catch (e) {
      errors.add('Pull failed: $e');
      developer.log('[SyncRun] pullFailed error=$e', name: 'sync.run');
    }

    progress(5, 'Finishing sync');
    await _syncDao.purgeSync();
    final remainingPending = await _syncDao.getPendingCount();
    final conflicts = await _syncDao.getConflicts();
    final conflictCount = conflicts.length;
    for (final conflict in conflicts) {
      final description = _describeQueuedConflict(conflict);
      if (!conflictDetails.contains(description)) {
        conflictDetails.add(description);
      }
    }
    developer.log(
      '[SyncRun] finish pushed=$pushed pulled=$pulled '
      'remainingPending=$remainingPending conflicts=$conflictCount '
      'errors=$errors',
      name: 'sync.run',
    );
    return SyncResult(
      pushed: pushed,
      pulled: pulled,
      errors: errors,
      remainingPending: remainingPending,
      conflicts: conflictCount,
      conflictDetails: conflictDetails,
    );
  }

  Future<int> pullReferenceData({DateTime? since}) {
    return _roleStrategy.pullReferenceData(since: since);
  }

  Future<int> _push({
    required String passName,
    required List<String> conflictDetails,
  }) async {
    final batch = await _syncDao.getNextBatch(
      limit: _batchSize,
      entityTypes: backendSupportedSyncEntityTypes,
    );
    var successCount = 0;
    final adjustedStockBagUuidsThisPass = <String>{};

    developer.log(
      '[SyncPush] pass=$passName batchSize=${batch.length} '
      'order=${batch.map(_queueEntrySummary).join(' -> ')}',
      name: 'sync.push',
    );

    var index = 0;
    for (final entry in batch) {
      index++;
      developer.log(
        '[SyncPush] pass=$passName start $index/${batch.length} '
        '${_queueEntrySummary(entry)} payload=${_logPreview(_safeQueuedPayloadForLog(entry.payload))}',
        name: 'sync.push',
      );

      if (entry.retryCount >= _maxRetries) {
        await _syncDao.markConflict(entry.id);
        developer.log(
          '[SyncPush] pass=$passName conflict ${_queueEntrySummary(entry)} '
          'reason=maxRetries retry=${entry.retryCount}',
          name: 'sync.push',
        );
        continue;
      }

      if (_dispatchUsesAdjustedStockBag(
        entry,
        adjustedStockBagUuidsThisPass,
      )) {
        developer.log(
          '[SyncPush] pass=$passName deferred ${_queueEntrySummary(entry)} '
          'because a selected stock bag was adjusted earlier in this sync pass. '
          'adjustedStockBagUuids=$adjustedStockBagUuidsThisPass',
          name: 'sync.push',
        );
        continue;
      }

      try {
        await _pushEntry(entry);
        await _syncDao.markSynced(entry.id);
        await _markEntitySynced(entry.entityType, entry.entityId);
        await _markStockBagMutationSynced(entry);
        if (entry.entityType == 'stockAdjustments') {
          adjustedStockBagUuidsThisPass.addAll(
            _stockBagUuidsFromQueuedPayload(entry.payload),
          );
        }
        successCount++;
        developer.log(
          '[SyncPush] pass=$passName success ${_queueEntrySummary(entry)}',
          name: 'sync.push',
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        developer.log(
          '[SyncPush] pass=$passName failure ${_queueEntrySummary(entry)} '
          'path=${e.requestOptions.path} status=$status '
          'retry=${entry.retryCount + 1} '
          'response=${e.response?.data} '
          'payload=${_logPreview(_safeQueuedPayloadForLog(entry.payload))}',
          name: 'sync.push',
        );
        if (status == 409 || _isPermanentValidationConflict(e)) {
          await _syncDao.markConflict(entry.id);
          await _markEntityConflict(entry.entityType, entry.entityId);
          final detail = _describeDioConflict(entry, e);
          if (!conflictDetails.contains(detail)) {
            conflictDetails.add(detail);
          }
        } else {
          if (status != null && status >= 400) {
            final detail = _describeDioRetryFailure(entry, e);
            if (!conflictDetails.contains(detail)) {
              conflictDetails.add(detail);
            }
          }
          // 400/422 are validation errors - the payload may be fixable on the
          // next sync (e.g. a parent reference that wasn't synced yet).
          // Treat them as retryable failures, not permanent conflicts.
          await _syncDao.recordFailureWithCount(entry.id, entry.retryCount + 1);
        }
      } catch (e, stackTrace) {
        developer.log(
          '[SyncPush] pass=$passName failure ${_queueEntrySummary(entry)} '
          'error=$e',
          name: 'sync.push',
          error: e,
          stackTrace: stackTrace,
        );
        await _syncDao.recordFailureWithCount(entry.id, entry.retryCount + 1);
      }
    }

    return successCount;
  }

  Future<void> _markStockBagMutationSynced(SyncQueueData entry) async {
    if (entry.entityType != 'dispatches') return;
    final stockBagUuids = _stockBagUuidsFromQueuedPayload(entry.payload);
    await _warehouseOperationsDao.markCachedStockBags(
      uuids: stockBagUuids,
      status: 'DISPATCHED',
    );
    await _warehouseOperationsDao.refreshInventorySummariesForCachedStockBags(
      uuids: stockBagUuids,
    );
  }

  String _queueEntrySummary(SyncQueueData entry) {
    return '#${entry.id}:${entry.entityType}/${entry.operation}'
        ':${entry.entityId}:retry=${entry.retryCount}';
  }

  bool _dispatchUsesAdjustedStockBag(
    SyncQueueData entry,
    Set<String> adjustedStockBagUuids,
  ) {
    if (entry.entityType != 'dispatches' || adjustedStockBagUuids.isEmpty) {
      return false;
    }

    final dispatchBagUuids = _stockBagUuidsFromQueuedPayload(entry.payload);
    return dispatchBagUuids.any(adjustedStockBagUuids.contains);
  }

  Set<String> _stockBagUuidsFromQueuedPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      final data = _asMap(decoded);
      final bags = data['bags'];
      if (bags is! List) return const <String>{};

      return bags
          .whereType<Map>()
          .map((bag) => bag['stockBagUuid']?.toString().trim() ?? '')
          .where((uuid) => uuid.isNotEmpty)
          .toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  Future<void> _pushEntry(SyncQueueData entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final originalPayload = _asMap(jsonDecode(entry.payload));
    if (entry.entityType == 'amcos' && entry.operation == 'create') {
      _normalizeAmcosCreatePayload(payload);
      developer.log(
        '[AmcosSync] POST /amcos uuid=${entry.entityId} '
        'normalizedPayload=${_logPreview(payload)} '
        'json=${_logPreview(jsonEncode(payload))}',
        name: 'sync.amcos',
      );
      try {
        final response = await _dio.post('/amcos', data: payload);
        developer.log(
          '[AmcosSync] POST /amcos success uuid=${entry.entityId} '
          'status=${response.statusCode} response=${_logPreview(response.data)}',
          name: 'sync.amcos',
        );
        await _applyAmcosCreateResponse(
          uuid: entry.entityId,
          responseData: response.data,
        );
      } on DioException catch (e) {
        developer.log(
          '[AmcosSync] POST /amcos failure uuid=${entry.entityId} '
          'status=${e.response?.statusCode} '
          'response=${_logPreview(e.response?.data)} '
          'normalizedPayload=${_logPreview(payload)} '
          'json=${_logPreview(jsonEncode(payload))}',
          name: 'sync.amcos',
          error: e,
        );
        rethrow;
      }
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
      _normalizeHarvestPayloadForPost(payload);
    }
    if (_isWarehouseOperation(entry.entityType) &&
        entry.operation != 'delete') {
      await _normalizeWarehouseOperationPayload(
        entityType: entry.entityType,
        entityId: entry.entityId,
        payload: payload,
      );
    }
    final path = _entityPath(entry.entityType, entry.entityId);
    if (entry.entityType == 'farmerHarvests' && entry.operation == 'create') {
      developer.log(
        '[HarvestSync] POST payload=${_logPreview(payload)}',
        name: 'sync.harvest',
      );
    }

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
          await _cacheHarvestReportActivity(entry.entityId);
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
        } else if (_isWarehouseOperation(entry.entityType)) {
          developer.log(
            '[WarehouseOperationSync] create entity=${entry.entityType} '
            'uuid=${entry.entityId} payload=${_logPreview(payload)} '
            'response=${_logPreview(response.data)}',
            name: 'sync.warehouse.operation',
          );
          await _cacheWarehouseOperationReportActivity(
            entityType: entry.entityType,
            entityId: entry.entityId,
            originalPayload: originalPayload,
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
    final dependantUuid = payload['uuid']?.toString();
    if (dependantUuid == null || dependantUuid.isEmpty) {
      throw StateError('Dependant has no UUID.');
    }
    // The endpoint path param is the farmer UUID (not the integer server ID).
    // Ensure the farmer is synced so the server can resolve the UUID.
    await _farmerServerId(farmerUuid); // throws if farmer not synced yet
    final response = await _dio.post(
      '/farmer-dependants/$farmerUuid',
      data: [payload],
    );
    developer.log(
      '[FarmerDependantSync] create farmerUuid=$farmerUuid '
      'uuid=$dependantUuid response=${_logPreview(response.data)}',
      name: 'sync.farmer',
    );
  }

  Future<void> _resolveHarvestFarmer(Map<String, dynamic> payload) async {
    final farmerUuid = payload['farmerUuid']?.toString();
    if (farmerUuid == null || farmerUuid.isEmpty) return;
    final serverId = await _farmerServerId(farmerUuid);
    payload['guarantor'] = serverId.toString();
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

  void _normalizeAmcosCreatePayload(Map<String, dynamic> payload) {
    final before = Map<String, dynamic>.from(payload);
    payload['tinNumber'] ??= '';
    payload['email'] ??= '';
    payload['contactPersonName'] ??= '';
    payload['contactPersonPhoneNumber'] ??= '';
    payload['contactPersonEmail'] ??= '';
    payload['contactPersonTitle'] ??= '';
    payload['website'] ??= '';
    payload['status'] ??= 'ACTIVE';
    if (payload['crops'] is String && payload['crops'].toString().isEmpty) {
      payload.remove('crops');
    }
    payload['idCounter'] ??= 0;
    developer.log(
      '[AmcosSync] normalized create payload '
      'before=${_logPreview(before)} after=${_logPreview(payload)}',
      name: 'sync.amcos',
    );
  }

  Object? _safeQueuedPayloadForLog(String payload) {
    try {
      return _redactForLog(jsonDecode(payload));
    } catch (_) {
      return payload;
    }
  }

  bool _isPermanentValidationConflict(DioException error) {
    final status = error.response?.statusCode;
    if (status != 400 && status != 422) return false;

    final text = error.response?.data?.toString().toLowerCase() ?? '';
    return text.contains('already in use') ||
        text.contains('already exist') ||
        text.contains('already exists') ||
        text.contains('duplicate') ||
        text.contains('stock bag is not available');
  }

  String _describeDioConflict(SyncQueueData entry, DioException error) {
    final backendMessage = _extractBackendMessage(error.response?.data);
    final queuedRecord = _describeQueuedConflict(entry);
    if (backendMessage.isEmpty) return queuedRecord;

    final normalized = backendMessage.toLowerCase();
    if (entry.entityType == 'users' &&
        (normalized.contains('email') || normalized.contains('phone'))) {
      return '$queuedRecord Server says the email or phone number already exists.';
    }
    if (normalized.contains('already') || normalized.contains('duplicate')) {
      return '$queuedRecord Server says this record already exists.';
    }
    if (entry.entityType == 'dispatches' &&
        normalized.contains('stock bag is not available')) {
      return '$queuedRecord The selected stock bag is no longer available on '
          'the server. Please create a new dispatch using a currently '
          'available bag.';
    }
    return '$queuedRecord Server message: $backendMessage';
  }

  String _describeDioRetryFailure(SyncQueueData entry, DioException error) {
    final queuedRecord = _describeQueuedConflict(entry);
    final status = error.response?.statusCode;
    if (status == 403) {
      return '$queuedRecord Server rejected this request with 403 Forbidden. '
          'The logged-in account may not have permission to create this record.';
    }
    final backendMessage = _extractBackendMessage(error.response?.data);
    if (backendMessage.isEmpty) return queuedRecord;
    return '$queuedRecord Server message: $backendMessage';
  }

  String _describeQueuedConflict(SyncQueueData entry) {
    final payload = _decodePayloadMap(entry.payload);
    final name = _string(
      payload['fullName'] ??
          payload['name'] ??
          payload['farmerName'] ??
          payload['businessName'],
    );
    final email = _string(payload['email']);
    final phone = _string(payload['phoneNumber'] ?? payload['phone']);
    final entity = _entityLabel(entry.entityType);
    final parts = <String>[
      if (name.isNotEmpty) name,
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
    ];
    final identity = parts.isEmpty ? entry.entityId : parts.join(' / ');
    return '$entity "$identity" could not sync.';
  }

  Map<String, dynamic> _decodePayloadMap(String payload) {
    try {
      return _asMap(jsonDecode(payload));
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  String _extractBackendMessage(Object? data) {
    if (data == null) return '';
    if (data is String) return data.trim();
    if (data is Map) {
      for (final key in const ['message', 'detail', 'error', 'errors']) {
        final value = data[key];
        if (value == null) continue;
        if (value is List) {
          return value.map((item) => item.toString()).join(', ').trim();
        }
        if (value is Map) {
          return value.values.map((item) => item.toString()).join(', ').trim();
        }
        return value.toString().trim();
      }
    }
    return data.toString().trim();
  }

  String _entityLabel(String entityType) {
    return switch (entityType) {
      'users' => 'Worker',
      'farmers' => 'Farmer',
      'farmerDependants' => 'Farmer dependant',
      'farmerHarvests' => 'Harvest',
      'warehouses' => 'Warehouse',
      'amcos' => 'AMCOS',
      'dispatches' => 'Dispatch',
      'stockCounts' => 'Stock count',
      'stockAdjustments' => 'Stock adjustment',
      _ => 'Record',
    };
  }

  Future<void> _cacheHarvestReportActivity(String harvestUuid) async {
    final harvest = await _harvestDao.getHarvestByUuid(harvestUuid);
    if (harvest == null) return;
    final warehouse = await _warehouseDao.getWarehouseById(harvest.warehouseId);
    final bags = await _harvestDao.getBagsForHarvest(harvestUuid);

    await _warehouseOperationsDao.cacheWarehouseReportActivity(
      activity: {
        'uuid': harvest.uuid,
        'activityType': 'RECEIVING',
        'warehouseId': harvest.warehouseId,
        'collectionCenterUuid': warehouse?.uuid ?? harvest.warehouseId,
        'collectionCenterName': harvest.collectionCenterName,
        'crop': harvest.crop,
        'cropName': harvest.cropName,
        'totalBags': bags.isNotEmpty ? bags.length : 1,
        'totalGrossWeight': harvest.grossWeight,
        'totalNetWeight': harvest.netWeight,
        'workerId': harvest.receivedBy,
        'workerName': harvest.receivedByName ?? '',
        'activityAt': harvest.receivedAt,
        'farmerName': harvest.farmerName,
        'farmerPhoneNumber': harvest.farmerPhoneNumber,
        'receiptNumber': harvest.receiptNumber,
      },
      bags: [
        for (final bag in bags)
          {
            'stockBagUuid': bag.id,
            'tagNumber': bag.tag,
            'grossWeight': bag.grossWeight,
            'packagingWeight': bag.packagingWeight,
            'netWeight': bag.netWeight,
            'moistureContent': bag.moistureContent,
          },
      ],
    );
  }

  Future<void> _cacheWarehouseOperationReportActivity({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> originalPayload,
  }) async {
    if (entityType == 'dispatches') {
      final dispatch =
          await _warehouseOperationsDao.getDispatchByUuid(entityId);
      if (dispatch == null) return;
      await _warehouseOperationsDao.cacheWarehouseReportActivity(
        activity: {
          'uuid': dispatch.uuid,
          'activityType': 'DISPATCH',
          'warehouseId': dispatch.warehouseId,
          'collectionCenterUuid': dispatch.collectionCenterUuid,
          'collectionCenterName':
              dispatch.collectionCenterName ?? dispatch.collectionCenterUuid,
          'crop': dispatch.crop,
          'cropName': dispatch.cropName,
          'totalBags': dispatch.totalBags,
          'totalGrossWeight': dispatch.totalGrossWeight,
          'totalNetWeight': dispatch.totalNetWeight,
          'workerId': dispatch.dispatchedBy,
          'workerName': dispatch.dispatchedByName ?? '',
          'activityAt': dispatch.dispatchedAt,
          'recipientType': dispatch.recipientType,
          'recipientName': dispatch.recipientName,
          'recipientPhone': dispatch.recipientPhone,
        },
        bags: _reportBagsFromPayload(originalPayload['bags']),
      );
      return;
    }

    if (entityType == 'stockAdjustments') {
      final adjustment =
          await _warehouseOperationsDao.getStockAdjustmentByUuid(entityId);
      if (adjustment == null) return;
      final changeSign =
          adjustment.adjustmentType.toUpperCase() == 'DECREASE' ? -1 : 1;
      await _warehouseOperationsDao.cacheWarehouseReportActivity(
        activity: {
          'uuid': adjustment.uuid,
          'activityType': 'STOCK_ADJUSTMENT',
          'warehouseId': adjustment.warehouseId,
          'collectionCenterUuid': adjustment.collectionCenterUuid,
          'collectionCenterName':
              adjustment.collectionCenterName ?? adjustment.collectionCenterUuid,
          'crop': adjustment.crop,
          'cropName': adjustment.cropName,
          'totalBags': adjustment.bags,
          'totalGrossWeight': adjustment.grossWeight,
          'totalNetWeight': adjustment.netWeight,
          'workerId': adjustment.adjustedBy,
          'workerName': adjustment.adjustedByName ?? '',
          'activityAt': adjustment.adjustedAt,
          'adjustmentType': adjustment.adjustmentType,
          'reason': adjustment.reason,
          'netWeightChange': changeSign * adjustment.netWeight,
        },
        bags: _reportBagsFromPayload(
          _hasNonEmptyList(originalPayload['bags'])
              ? originalPayload['bags']
              : originalPayload['newBags'],
          netWeightChangeSign: changeSign,
        ),
      );
    }
  }

  List<Map<String, Object?>> _reportBagsFromPayload(
    Object? value, {
    int netWeightChangeSign = 1,
  }) {
    if (value is! List) return const <Map<String, Object?>>[];
    return value.whereType<Map>().map((raw) {
      final bag = _asMap(raw);
      final grossWeight = _double(
        bag['measuredGrossWeight'] ?? bag['grossWeight'],
      );
      final packagingWeight = _double(
        bag['measuredPackagingWeight'] ?? bag['packagingWeight'],
      );
      final netWeight = _double(bag['measuredNetWeight'] ?? bag['netWeight']);
      final diff = bag['netWeightDifference'] == null
          ? null
          : _double(bag['netWeightDifference']);
      return <String, Object?>{
        'stockBagUuid': bag['stockBagUuid'] ?? bag['uuid'] ?? '',
        'tagNumber': bag['tagNumber'] ?? '',
        'grossWeight': grossWeight,
        'packagingWeight': packagingWeight,
        'netWeight': netWeight,
        'previousNetWeight': bag['previousNetWeight'],
        'netWeightDifference': diff ?? (netWeightChangeSign * netWeight),
        'moistureContent': _double(bag['moistureContent']),
      };
    }).toList();
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

  double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
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

  void _normalizeHarvestPayloadForPost(Map<String, dynamic> payload) {
    if (payload['uom'] != null) {
      payload['uom'] = payload['uom'].toString();
    }
    if (payload['guarantor'] != null) {
      payload['guarantor'] = payload['guarantor'].toString();
    }

    payload.remove('farmer');
    payload.remove('farmerName');
    payload.remove('farmerPhoneNumber');
    payload.remove('amcosName');
    payload.remove('amcosUuid');
    payload.remove('mcuName');
    payload.remove('receivedBy');
    payload.remove('receivedByName');
    payload.remove('cropName');
    payload.remove('cropGradeName');
    payload.remove('warehouseId');
    payload.remove('warehouseUuid');
    payload.remove('collectionCenterId');
    payload.remove('collectionCenterName');
  }

  bool _isWarehouseOperation(String entityType) {
    return entityType == 'dispatches' ||
        entityType == 'stockCounts' ||
        entityType == 'stockAdjustments';
  }

  Future<void> _normalizeWarehouseOperationPayload({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    if (entityType == 'dispatches') {
      _ensureMeasuredBags(
        payload,
        count: _int(payload['totalBags']),
        grossWeight: _double(payload['totalGrossWeight']),
        packagingWeight: _double(payload['totalPackagingWeight']),
        netWeight: _double(payload['totalNetWeight']),
        moistureContent: _double(payload['moistureContent']),
        measuredAt: payload['dispatchedAt']?.toString(),
      );
      _assertMeasuredBagsHaveStockBagUuids(payload);
      await _refreshDispatchStockBagUuids(payload);
      payload.remove('totalBags');
      payload.remove('totalGrossWeight');
      payload.remove('totalPackagingWeight');
      payload.remove('totalNetWeight');
      payload.remove('moistureContent');
      payload.remove('dispatchedBy');
      return;
    }

    if (entityType == 'stockCounts') {
      _ensureMeasuredBags(
        payload,
        count: _int(payload['countedBags']),
        grossWeight: _double(payload['countedGrossWeight']),
        packagingWeight: _double(payload['countedPackagingWeight']),
        netWeight: _double(payload['countedNetWeight']),
        moistureContent: _double(payload['moistureContent']),
        measuredAt: payload['countedAt']?.toString(),
      );
      _assertMeasuredBagsHaveStockBagUuids(payload);
      payload.remove('countedBags');
      payload.remove('countedGrossWeight');
      payload.remove('countedPackagingWeight');
      payload.remove('countedNetWeight');
      payload.remove('moistureContent');
      payload.remove('countedBy');
      return;
    }

    if (entityType == 'stockAdjustments') {
      final count = _int(payload['totalBags'] ?? payload['bags']);
      final grossWeight = _double(payload['grossWeight']);
      final packagingWeight = _double(payload['packagingWeight']);
      final netWeight = _double(payload['netWeight']);
      final moistureContent = _double(payload['moistureContent']);

      _ensureMeasuredBags(
        payload,
        count: count,
        grossWeight: grossWeight,
        packagingWeight: packagingWeight,
        netWeight: netWeight,
        moistureContent: moistureContent,
        measuredAt: payload['adjustedAt']?.toString(),
      );

      final adjustmentType = payload['adjustmentType']?.toString().toUpperCase();
      if (adjustmentType == 'INCREASE') {
        final adjustsExistingStockBags = _measuredBagsHaveStockBagUuids(payload);
        if (adjustsExistingStockBags) {
          payload.remove('newBags');
        } else if (!_hasNonEmptyList(payload['newBags'])) {
          payload['newBags'] = _newWarehouseBags(
            entityId: entityId,
            count: count,
            grossWeight: grossWeight,
            packagingWeight: packagingWeight,
            netWeight: netWeight,
            moistureContent: moistureContent,
          );
        }
        if (!adjustsExistingStockBags) {
          payload['bags'] = <Map<String, dynamic>>[];
        }
      } else {
        _assertMeasuredBagsHaveStockBagUuids(payload);
      }
      payload.remove('totalBags');
      payload.remove('grossWeight');
      payload.remove('packagingWeight');
      payload.remove('netWeight');
      payload.remove('moistureContent');
      payload.remove('adjustedBy');
    }
  }

  Future<void> _refreshDispatchStockBagUuids(
    Map<String, dynamic> payload,
  ) async {
    final collectionCenterUuid = payload['collectionCenter']?.toString().trim();
    final cropId = _int(payload['crop']);
    final bags = payload['bags'];
    if (collectionCenterUuid == null ||
        collectionCenterUuid.isEmpty ||
        cropId == null ||
        bags is! List ||
        bags.isEmpty) {
      return;
    }

    Response<dynamic> response;
    try {
      response = await _dio.get(
        '/stock-bags/collection-center/$collectionCenterUuid/crop/$cropId',
        queryParameters: {'status': 'IN_STOCK'},
      );
    } on DioException catch (e) {
      developer.log(
        '[DispatchBagRefresh] failed collectionCenter=$collectionCenterUuid '
        'crop=$cropId status=${e.response?.statusCode} '
        'response=${_logPreview(e.response?.data)}',
        name: 'sync.warehouse.operation',
      );
      return;
    }

    final records = _responseRecords(response.data);
    developer.log(
      '[DispatchBagRefresh] current IN_STOCK bags '
      'collectionCenter=$collectionCenterUuid crop=$cropId '
      'options=${_logPreview(_stockBagOptionsForLog(records))}',
      name: 'sync.warehouse.operation',
    );
    final inStockByUuid = <String, Map<String, dynamic>>{};
    final inStockByTag = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final uuid = record['uuid']?.toString().trim();
      final tag = record['tagNumber']?.toString().trim().toLowerCase();
      if (uuid != null && uuid.isNotEmpty) {
        inStockByUuid[uuid] = record;
      }
      if (tag != null && tag.isNotEmpty) {
        inStockByTag[tag] = record;
      }
    }

    for (final bag in bags) {
      if (bag is! Map) continue;
      final currentUuid = bag['stockBagUuid']?.toString().trim();
      if (currentUuid == null || currentUuid.isEmpty) continue;
      if (inStockByUuid.containsKey(currentUuid)) continue;

      final tag = bag['tagNumber']?.toString().trim().toLowerCase();
      final replacement = tag == null || tag.isEmpty ? null : inStockByTag[tag];
      final replacementUuid = replacement?['uuid']?.toString().trim();
      if (replacementUuid != null && replacementUuid.isNotEmpty) {
        developer.log(
          '[DispatchBagRefresh] replacing stale stockBagUuid '
          'tag=${bag['tagNumber']} old=$currentUuid new=$replacementUuid '
          'collectionCenter=$collectionCenterUuid crop=$cropId',
          name: 'sync.warehouse.operation',
        );
        bag['stockBagUuid'] = replacementUuid;
      } else {
        developer.log(
          '[DispatchBagRefresh] stale stockBagUuid still not available '
          'tag=${bag['tagNumber']} uuid=$currentUuid '
          'collectionCenter=$collectionCenterUuid crop=$cropId '
          'inStockCount=${records.length} '
          'options=${_logPreview(_stockBagOptionsForLog(records))}',
          name: 'sync.warehouse.operation',
        );
      }
    }
  }

  List<Map<String, dynamic>> _responseRecords(Object? data) {
    if (data is List) {
      return data.whereType<Map>().map(_asMap).toList();
    }
    if (data is Map) {
      final records = data['records'];
      if (records is List) {
        return records.whereType<Map>().map(_asMap).toList();
      }
      return [_asMap(data)];
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _stockBagOptionsForLog(
    List<Map<String, dynamic>> records,
  ) {
    return records
        .map(
          (record) => {
            'uuid': record['uuid'],
            'tagNumber': record['tagNumber'],
            'grossWeight': record['grossWeight'],
            'packagingWeight': record['packagingWeight'],
            'netWeight': record['netWeight'],
            'status': record['status'],
          },
        )
        .toList();
  }

  void _ensureMeasuredBags(
    Map<String, dynamic> payload, {
    required int? count,
    required double grossWeight,
    required double packagingWeight,
    required double netWeight,
    required double moistureContent,
    required String? measuredAt,
  }) {
    if (_hasNonEmptyList(payload['bags'])) return;

    final safeCount = count == null || count <= 0 ? 1 : count;
    payload['bags'] = List.generate(safeCount, (index) {
      return {
        'stockBagUuid': '',
        'measuredGrossWeight': _splitWeight(grossWeight, safeCount, index),
        'measuredPackagingWeight':
            _splitWeight(packagingWeight, safeCount, index),
        'measuredNetWeight': _splitWeight(netWeight, safeCount, index),
        'moistureContent': _roundWeight(moistureContent),
        'measuredAt': measuredAt ?? DateTime.now().toIso8601String(),
      };
    });
  }

  void _assertMeasuredBagsHaveStockBagUuids(Map<String, dynamic> payload) {
    if (_measuredBagsHaveStockBagUuids(payload)) return;
    throw StateError(
      'Select the exact stock bag by visible tag before syncing this warehouse operation.',
    );
  }

  bool _measuredBagsHaveStockBagUuids(Map<String, dynamic> payload) {
    final bags = payload['bags'];
    if (bags is! List || bags.isEmpty) return false;

    for (var index = 0; index < bags.length; index++) {
      final bag = bags[index];
      if (bag is! Map) return false;

      final stockBagUuid = bag['stockBagUuid']?.toString().trim();
      if (stockBagUuid == null || stockBagUuid.isEmpty) {
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> _newWarehouseBags({
    required String entityId,
    required int? count,
    required double grossWeight,
    required double packagingWeight,
    required double netWeight,
    required double moistureContent,
  }) {
    final safeCount = count == null || count <= 0 ? 1 : count;
    return List.generate(safeCount, (index) {
      final perGross = _splitWeight(grossWeight, safeCount, index);
      final perPackaging = _splitWeight(packagingWeight, safeCount, index);
      return {
        'uuid': '$entityId-bag-${index + 1}',
        'grossWeight': perGross,
        'packagingWeight': perPackaging,
        'loadWeight': _roundWeight(perGross - perPackaging),
        'netWeight': _splitWeight(netWeight, safeCount, index),
        'moistureContent': _roundWeight(moistureContent),
        'tagNumber': 'ADJ-${entityId.substring(0, 8)}-${index + 1}',
        'tagType': 'GENERATED',
      };
    });
  }

  bool _hasNonEmptyList(Object? value) {
    return value is List && value.isNotEmpty;
  }

  double _splitWeight(double total, int count, int index) {
    if (count <= 1) return _roundWeight(total);
    final firstPieces = _roundWeight(total / count);
    if (index < count - 1) return firstPieces;
    return _roundWeight(total - (firstPieces * (count - 1)));
  }

  double _roundWeight(double value) => double.parse(value.toStringAsFixed(3));

  String _logPreview(Object? data) {
    final text = data.toString();
    if (text.length <= 700) return text;
    return '${text.substring(0, 700)}...';
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
  final int remainingPending;
  final int conflicts;
  final List<String> conflictDetails;
  bool get hasErrors => errors.isNotEmpty;
  bool get hasRemainingWork => remainingPending > 0 || conflicts > 0;

  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.errors,
    required this.remainingPending,
    required this.conflicts,
    this.conflictDetails = const [],
  });
}

class SyncProgress {
  final int currentStep;
  final int totalSteps;
  final String message;

  const SyncProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.message,
  });

  double get fraction {
    if (totalSteps <= 0) return 0;
    return (currentStep / totalSteps).clamp(0, 1).toDouble();
  }
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
    if (!mounted) return;
    if (state.isSyncing) return;
    state = const SyncState.syncing(
      currentStep: 1,
      totalSteps: 5,
      progressMessage: 'Preparing local queue',
    );
    try {
      final result = await _manager.sync(
        onProgress: (progress) {
          if (!mounted) return;
          state = SyncState.syncing(
            currentStep: progress.currentStep,
            totalSteps: progress.totalSteps,
            progressMessage: progress.message,
          );
        },
      );
      if (!mounted) return;
      state = result.hasErrors
          ? SyncState.error(
              result.errors.first,
              remainingPending: result.remainingPending,
              conflicts: result.conflicts,
              conflictDetails: result.conflictDetails,
            )
          : SyncState.done(
              pushed: result.pushed,
              pulled: result.pulled,
              remainingPending: result.remainingPending,
              conflicts: result.conflicts,
              conflictDetails: result.conflictDetails,
            );
    } catch (e) {
      if (!mounted) return;
      state = SyncState.error(e.toString());
    }
  }
}

class SyncState {
  final bool isSyncing;
  final bool isDone;
  final String? error;
  final int pushed;
  final int pulled;
  final int remainingPending;
  final int conflicts;
  final List<String> conflictDetails;
  final int currentStep;
  final int totalSteps;
  final String progressMessage;

  const SyncState({
    this.isSyncing = false,
    this.isDone = false,
    this.error,
    this.pushed = 0,
    this.pulled = 0,
    this.remainingPending = 0,
    this.conflicts = 0,
    this.conflictDetails = const [],
    this.currentStep = 0,
    this.totalSteps = 5,
    this.progressMessage = '',
  });

  const SyncState.idle() : this();
  const SyncState.syncing({
    int currentStep = 0,
    int totalSteps = 5,
    String progressMessage = 'Syncing data',
  }) : this(
          isSyncing: true,
          currentStep: currentStep,
          totalSteps: totalSteps,
          progressMessage: progressMessage,
        );
  factory SyncState.done({
    required int pushed,
    required int pulled,
    int remainingPending = 0,
    int conflicts = 0,
    List<String> conflictDetails = const [],
  }) =>
      SyncState(
        isDone: true,
        pushed: pushed,
        pulled: pulled,
        remainingPending: remainingPending,
        conflicts: conflicts,
        conflictDetails: conflictDetails,
      );
  factory SyncState.error(
    String error, {
    int remainingPending = 0,
    int conflicts = 0,
    List<String> conflictDetails = const [],
  }) =>
      SyncState(
        error: error,
        remainingPending: remainingPending,
        conflicts: conflicts,
        conflictDetails: conflictDetails,
      );
  bool get hasErrors => error != null;
  bool get hasRemainingWork => remainingPending > 0 || conflicts > 0;
  double get progressFraction {
    if (totalSteps <= 0) return 0;
    return (currentStep / totalSteps).clamp(0, 1).toDouble();
  }
}

final syncNotifierProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref.watch(syncManagerProvider)),
);
