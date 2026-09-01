import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';

part 'warehouse_operations_dao.g.dart';

@DriftAccessor(tables: [
  WarehouseInventoryItems,
  WarehouseDispatches,
  WarehouseStockCounts,
  WarehouseStockAdjustments,
  SyncQueue,
])
class WarehouseOperationsDao extends DatabaseAccessor<AppDatabase>
    with _$WarehouseOperationsDaoMixin {
  WarehouseOperationsDao(super.db);

  Stream<List<WarehouseInventory>> watchInventory(String warehouseId) {
    return (select(warehouseInventoryItems)
          ..where((item) => item.warehouseId.equals(warehouseId))
          ..orderBy([(item) => OrderingTerm.asc(item.cropName)]))
        .watch();
  }

  Future<List<WarehouseInventory>> getInventory(String warehouseId) {
    return (select(warehouseInventoryItems)
          ..where((item) => item.warehouseId.equals(warehouseId))
          ..orderBy([(item) => OrderingTerm.asc(item.cropName)]))
        .get();
  }

  Future<WarehouseInventory?> getInventoryByCrop({
    required String warehouseId,
    required int cropId,
  }) {
    return (select(warehouseInventoryItems)
          ..where((item) =>
              item.warehouseId.equals(warehouseId) & item.crop.equals(cropId)))
        .getSingleOrNull();
  }

  Future<void> upsertInventory(WarehouseInventoryItemsCompanion entry) {
    return into(warehouseInventoryItems).insertOnConflictUpdate(entry);
  }

  Stream<List<WarehouseDispatch>> watchDispatches(String warehouseId) {
    return (select(warehouseDispatches)
          ..where((item) =>
              item.warehouseId.equals(warehouseId) & item.deletedAt.isNull())
          ..orderBy([(item) => OrderingTerm.desc(item.dispatchedAt)]))
        .watch();
  }

  Future<void> insertDispatchWithQueue({
    required WarehouseDispatchesCompanion dispatch,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await into(warehouseDispatches).insert(dispatch);
      await into(syncQueue).insert(queueEntry);
    });
  }

  Future<void> upsertDispatch(WarehouseDispatchesCompanion entry) {
    return into(warehouseDispatches).insertOnConflictUpdate(entry);
  }

  Future<void> markDispatchSynced(String uuid) {
    return (update(warehouseDispatches)
          ..where((item) => item.uuid.equals(uuid)))
        .write(
      WarehouseDispatchesCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markDispatchConflict(String uuid) {
    return (update(warehouseDispatches)
          ..where((item) => item.uuid.equals(uuid)))
        .write(
      WarehouseDispatchesCompanion(
        syncStatus: const Value('conflict'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<WarehouseStockCount>> watchStockCounts(String warehouseId) {
    return (select(warehouseStockCounts)
          ..where((item) =>
              item.warehouseId.equals(warehouseId) & item.deletedAt.isNull())
          ..orderBy([(item) => OrderingTerm.desc(item.countedAt)]))
        .watch();
  }

  Future<void> insertStockCountWithQueue({
    required WarehouseStockCountsCompanion stockCount,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await into(warehouseStockCounts).insert(stockCount);
      await into(syncQueue).insert(queueEntry);
    });
  }

  Future<void> upsertStockCount(WarehouseStockCountsCompanion entry) {
    return into(warehouseStockCounts).insertOnConflictUpdate(entry);
  }

  Future<void> markStockCountSynced(String uuid) {
    return (update(warehouseStockCounts)
          ..where((item) => item.uuid.equals(uuid)))
        .write(
      WarehouseStockCountsCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markStockCountConflict(String uuid) {
    return (update(warehouseStockCounts)
          ..where((item) => item.uuid.equals(uuid)))
        .write(
      WarehouseStockCountsCompanion(
        syncStatus: const Value('conflict'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<WarehouseStockAdjustment>> watchStockAdjustments(
    String warehouseId,
  ) {
    return (select(warehouseStockAdjustments)
          ..where((item) =>
              item.warehouseId.equals(warehouseId) & item.deletedAt.isNull())
          ..orderBy([(item) => OrderingTerm.desc(item.adjustedAt)]))
        .watch();
  }

  Future<void> insertStockAdjustmentWithQueue({
    required WarehouseStockAdjustmentsCompanion adjustment,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await into(warehouseStockAdjustments).insert(adjustment);
      await into(syncQueue).insert(queueEntry);
    });
  }

  Future<void> upsertStockAdjustment(
    WarehouseStockAdjustmentsCompanion entry,
  ) {
    return into(warehouseStockAdjustments).insertOnConflictUpdate(entry);
  }

  Future<void> markStockAdjustmentSynced(String uuid) {
    return (update(warehouseStockAdjustments)
          ..where((item) => item.uuid.equals(uuid)))
        .write(
      WarehouseStockAdjustmentsCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markStockAdjustmentConflict(String uuid) {
    return (update(warehouseStockAdjustments)
          ..where((item) => item.uuid.equals(uuid)))
        .write(
      WarehouseStockAdjustmentsCompanion(
        syncStatus: const Value('conflict'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
