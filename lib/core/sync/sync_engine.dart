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
import 'package:warehouse_app/features/additional.data/amcos/presentation/providers/amcos_providers.dart';
import 'package:warehouse_app/features/additional.data/crop/presentation/providers/crop_providers.dart';
import 'package:warehouse_app/features/additional.data/location/presentation/providers/location_providers.dart';
import 'package:warehouse_app/features/farmer/presentation/providers/farmer_providers.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_model.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_providers.dart';
import 'package:warehouse_app/features/warehouse/presentation/providers/warehouse_providers.dart';
import 'package:warehouse_app/features/worker/presentation/providers/worker_providers.dart';

const _maxRetries = 5;
const _batchSize = 30;
const _lastSyncKey = 'last_sync_timestamp';
const _syncableEntityTypes = <String>{
  'warehouses',
  'users',
  'farmers',
  'farmerDependants',
  'farmerHarvests',
};

class SyncManager {
  final Dio _dio;
  final SyncQueueDao _syncDao;
  final WarehouseDao _warehouseDao;
  final InventoryDao _inventoryDao;
  final AuditLogDao _auditDao;
  final HarvestDao _harvestDao;
  final FarmerDao _farmerDao;
  final SyncRoleStrategy _roleStrategy;
  final Future<int> Function() _currentMcuId;

  SyncManager({
    required Dio dio,
    required SyncQueueDao syncDao,
    required WarehouseDao warehouseDao,
    required InventoryDao inventoryDao,
    required AuditLogDao auditDao,
    required HarvestDao harvestDao,
    required FarmerDao farmerDao,
    required SyncRoleStrategy roleStrategy,
    required Future<int> Function() currentMcuId,
  })  : _dio = dio,
        _syncDao = syncDao,
        _warehouseDao = warehouseDao,
        _inventoryDao = inventoryDao,
        _auditDao = auditDao,
        _harvestDao = harvestDao,
        _farmerDao = farmerDao,
        _roleStrategy = roleStrategy,
        _currentMcuId = currentMcuId;

  Future<SyncResult> sync() async {
    var pushed = 0;
    var pulled = 0;
    final errors = <String>[];

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
        } else if (status == 400 || status == 422) {
          await _syncDao.markConflict(entry.id);
        } else {
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
    if (entry.entityType == 'farmerDependants' && entry.operation == 'create') {
      await _pushFarmerDependant(payload);
      return;
    }
    if (entry.entityType == 'warehouses' && entry.operation != 'delete') {
      payload['mcu'] = await _currentMcuId();
    }
    if (entry.entityType == 'farmerHarvests' && entry.operation != 'delete') {
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
        }
      case 'update':
        await _dio.patch(path, data: payload);
      case 'delete':
        await _dio.delete(path);
    }
  }

  Future<bool> _linkDuplicateFarmer({
    required String uuid,
    required Map<String, dynamic> payload,
    required DioException error,
  }) async {
    final status = error.response?.statusCode;
    final message = error.response?.data?.toString().toLowerCase() ?? '';
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

  Future<void> _applyFarmerCreateResponse({
    required String uuid,
    required Object? responseData,
  }) async {
    final data = _asMap(responseData);
    data['uuid'] ??= uuid;
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

  Future<void> _pushFarmerDependant(Map<String, dynamic> payload) async {
    final farmerUuid = payload.remove('farmerUuid')?.toString();
    if (farmerUuid == null || farmerUuid.isEmpty) {
      throw StateError('Dependant has no farmer UUID.');
    }
    final serverId = await _farmerServerId(farmerUuid);
    payload.remove('uuid');
    await _dio.post('/farmer-dependants/$serverId', data: [payload]);
  }

  Future<void> _resolveHarvestFarmer(Map<String, dynamic> payload) async {
    final farmerUuid = payload['farmerUuid']?.toString();
    if (farmerUuid == null || farmerUuid.isEmpty) return;
    final serverId = await _farmerServerId(farmerUuid);
    payload['farmer'] = serverId;
    payload['guarantor'] = serverId;
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
      case 'warehouses':
        await _warehouseDao.markWarehouseSynced(entityId);
      case 'inventoryItems':
        await _inventoryDao.markItemSynced(entityId);
      case 'stockMovements':
        await _inventoryDao.markMovementSynced(entityId);
      case 'auditLogs':
        await _auditDao.markLogSynced(entityId);
      case 'farmerHarvests':
        await _harvestDao.markHarvestSynced(entityId);
      case 'users':
        await _roleStrategy.markUserSynced(entityId);
    }
  }

  Future<void> _markEntityConflict(String entityType, String entityId) async {
    switch (entityType) {
      case 'warehouses':
        await _warehouseDao.markWarehouseConflict(entityId);
      case 'inventoryItems':
        await _inventoryDao.markItemConflict(entityId);
      case 'farmerHarvests':
        await _harvestDao.markHarvestConflict(entityId);
      case 'users':
        await _roleStrategy.markUserConflict(entityId);
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
    if (type == 'users') return '/auth/signup';
    if (type == 'warehouses') return '/collection-centers';
    if (type == 'farmers') return '/farmers';
    if (type == 'farmerHarvests') return '/farmer-harvests';
    return '/${_typeToPath(type)}/';
  }

  String _typeToPath(String type) => switch (type) {
        'warehouses' => 'collection-centers',
        'users' => 'users',
        'inventoryItems' => 'inventory',
        'stockMovements' => 'movements',
        'auditLogs' => 'audit-logs',
        'farmers' => 'farmers',
        'farmerDependants' => 'farmer-dependants',
        'farmerHarvests' => 'farmer-harvests',
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
    count += await _ref
        .read(harvestRepositoryProvider)
        .pullFromServer(amcosIds: amcosIds);
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
    count += await _ref
        .read(harvestRepositoryProvider)
        .pullFromCollectionCenter(collectionCenterId: collectionCenterId);
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
    auditDao: ref.watch(auditLogDaoProvider),
    harvestDao: ref.watch(harvestDaoProvider),
    farmerDao: ref.watch(farmerDaoProvider),
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
