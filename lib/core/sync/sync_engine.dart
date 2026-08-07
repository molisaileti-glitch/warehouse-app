import 'dart:convert';
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
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_providers.dart';
import 'package:warehouse_app/features/warehouse/presentation/providers/warehouse_providers.dart';

const _maxRetries = 5;
const _batchSize = 30;
const _lastSyncKey = 'last_sync_timestamp';

class SyncManager {
  final Dio _dio;
  final SyncQueueDao _syncDao;
  final WarehouseDao _warehouseDao;
  final InventoryDao _inventoryDao;
  final AuditLogDao _auditDao;
  final HarvestDao _harvestDao;
  final SyncRoleStrategy _roleStrategy;

  SyncManager({
    required Dio dio,
    required SyncQueueDao syncDao,
    required WarehouseDao warehouseDao,
    required InventoryDao inventoryDao,
    required AuditLogDao auditDao,
    required HarvestDao harvestDao,
    required SyncRoleStrategy roleStrategy,
  })  : _dio = dio,
        _syncDao = syncDao,
        _warehouseDao = warehouseDao,
        _inventoryDao = inventoryDao,
        _auditDao = auditDao,
        _harvestDao = harvestDao,
        _roleStrategy = roleStrategy;

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
      pulled += await _pullMutableEntities(await _getLastSyncTime());
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
    final batch = await _syncDao.getNextBatch(limit: _batchSize);
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
        if (status == 409) {
          await _syncDao.markConflict(entry.id);
          await _markEntityConflict(entry.entityType, entry.entityId);
        } else if (status != null && status >= 400 && status < 500) {
          await _syncDao.markConflict(entry.id);
        } else {
          await _syncDao.recordFailureWithCount(entry.id, entry.retryCount + 1);
        }
      }
    }

    return successCount;
  }

  Future<void> _pushEntry(SyncQueueData entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final path = _entityPath(entry.entityType, entry.entityId);

    switch (entry.operation) {
      case 'create':
        await _dio.post(_entityCollectionPath(entry.entityType), data: payload);
      case 'update':
        await _dio.patch(path, data: payload);
      case 'delete':
        await _dio.delete(path);
    }
  }

  Future<int> _pullMutableEntities(DateTime? since) async {
    final params = since != null
        ? {'updated_since': since.toIso8601String()}
        : <String, dynamic>{};
    var count = 0;
    count += await _pullEntity('/inventory/', params, _upsertInventoryItem);
    count += await _pullEntity('/movements/', params, _upsertMovement);
    count += await _pullEntity('/audit-logs/', params, _upsertAuditLog);
    return count;
  }

  Future<int> _pullEntity(
    String path,
    Map<String, dynamic> params,
    Future<void> Function(Map<String, dynamic>) upsert,
  ) async {
    try {
      final res = await _dio.get(path, queryParameters: params);
      final raw = res.data is Map<String, dynamic> ? res.data['results'] : res.data;
      final list = (raw as List? ?? const []).cast<Map<String, dynamic>>();
      for (final json in list) {
        await upsert(json);
      }
      return list.length;
    } on DioException {
      return 0;
    }
  }

  Future<void> _upsertInventoryItem(Map<String, dynamic> json) {
    return _inventoryDao.upsertItem(
      InventoryItemsCompanion.insert(
        id: json['id'] as String,
        warehouseId: json['warehouse_id'] as String,
        name: json['name'] as String,
        sku: Value(json['sku'] as String?),
        category: Value(json['category'] as String?),
        unit: Value(json['unit'] as String? ?? 'pcs'),
        quantityOnHand:
            Value((json['quantity_on_hand'] as num?)?.toDouble() ?? 0),
        reorderLevel: Value((json['reorder_level'] as num?)?.toDouble() ?? 0),
        syncStatus: const Value('synced'),
        updatedAt: Value(
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
              DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _upsertMovement(Map<String, dynamic> json) {
    return _inventoryDao.upsertMovement(
      StockMovementsCompanion.insert(
        id: json['id'] as String,
        inventoryItemId: json['inventory_item_id'] as String,
        warehouseId: json['warehouse_id'] as String,
        movementType: json['movement_type'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        quantityBefore: (json['quantity_before'] as num).toDouble(),
        recordedById: json['recorded_by_id'] as String,
        notes: Value(json['notes'] as String?),
        relatedWarehouseId: Value(json['related_warehouse_id'] as String?),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<void> _upsertAuditLog(Map<String, dynamic> json) {
    return _auditDao.upsertLog(
      AuditLogsCompanion.insert(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        action: json['action'] as String,
        warehouseId: Value(json['warehouse_id'] as String?),
        metadata: Value(json['metadata'] as String?),
        origin: Value(json['origin'] as String? ?? 'online'),
        syncStatus: const Value('synced'),
      ),
    );
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
  String _entityCollectionPath(String type) {
    if (type == 'users') return '/auth/signup';
    return '/${_typeToPath(type)}/';
  }

  String _typeToPath(String type) => switch (type) {
        'warehouses' => 'warehouses',
        'users' => 'users',
        'inventoryItems' => 'inventory',
        'stockMovements' => 'movements',
        'auditLogs' => 'audit-logs',
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
    count += await _ref.read(warehouseRepoProvider).pullFromServer(since: since);
    return count;
  }

  @override
  Future<int> pullReferenceData({DateTime? since}) async {
    var count = 0;
    count += await _ref.read(cropRepositoryProvider).pullDownstream();
    count += await _ref.read(harvestRepositoryProvider).pullReferenceData();
    count += await _ref.read(locationRepositoryProvider).pullDownstream(since: since);
    count += await _ref.read(amcosRepositoryProvider).pullDownstream(since: since);
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
    count += await _ref.read(warehouseRepoProvider).pullFromServer(since: since);
    return count;
  }

  @override
  Future<int> pullReferenceData({DateTime? since}) async {
    var count = 0;
    count += await _ref.read(cropRepositoryProvider).pullDownstream();
    count += await _ref.read(harvestRepositoryProvider).pullReferenceData();
    count += await _ref.read(locationRepositoryProvider).pullDownstream(since: since);
    count += await _ref.read(amcosRepositoryProvider).pullDownstream(since: since);
    return count;
  }

  @override
  Future<void> markUserSynced(String id) async {}

  @override
  Future<void> markUserConflict(String id) async {}
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
    roleStrategy: strategy,
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
