import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/stock_bag/data/tables/stock_bag_table.dart';

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
          ..where((item) =>
              item.warehouseId.equals(warehouseId) &
              item.totalBags.isBiggerThanValue(0))
          ..orderBy([(item) => OrderingTerm.asc(item.cropName)]))
        .watch();
  }

  Future<List<WarehouseInventory>> getInventory(String warehouseId) {
    return (select(warehouseInventoryItems)
          ..where((item) =>
              item.warehouseId.equals(warehouseId) &
              item.totalBags.isBiggerThanValue(0))
          ..orderBy([(item) => OrderingTerm.asc(item.cropName)]))
        .get();
  }

  Future<WarehouseInventory?> getInventoryByCrop({
    required String warehouseId,
    required int cropId,
  }) {
    return (select(warehouseInventoryItems)
          ..where((item) =>
              item.warehouseId.equals(warehouseId) &
              item.crop.equals(cropId) &
              item.totalBags.isBiggerThanValue(0))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertInventory(WarehouseInventoryItemsCompanion entry) {
    final uuid = entry.uuid.value;
    final warehouseId = entry.warehouseId.value;
    final cropId = entry.crop.value;

    return transaction(() async {
      await (delete(warehouseInventoryItems)
            ..where(
              (item) =>
                  item.warehouseId.equals(warehouseId) &
                  item.crop.equals(cropId) &
                  item.uuid.equals(uuid).not(),
            ))
          .go();
      await into(warehouseInventoryItems).insertOnConflictUpdate(entry);
    });
  }

  Future<void> deleteInventory(String uuid) {
    return (delete(warehouseInventoryItems)
          ..where((item) => item.uuid.equals(uuid)))
        .go();
  }

  Future<List<CachedStockBagEntry>> getCachedStockBags({
    required String warehouseId,
    required int cropId,
    String status = 'IN_STOCK',
  }) {
    return customSelect(
      '''
      SELECT *
      FROM $cachedStockBagsTableName
      WHERE warehouse_id = ?
        AND crop = ?
        AND status = ?
      ORDER BY tag_number ASC
      ''',
      variables: [
        Variable<String>(warehouseId),
        Variable<int>(cropId),
        Variable<String>(status),
      ],
    ).get().then((rows) => rows.map(_cachedStockBagFromRow).toList());
  }

  Future<void> replaceCachedStockBagsForStatus({
    required String warehouseId,
    required int cropId,
    required String status,
    required List<CachedStockBagEntry> entries,
  }) {
    final activeUuids = entries.map((entry) => entry.uuid).toSet();
    final now = DateTime.now();

    return transaction(() async {
      if (activeUuids.isEmpty) {
        await customStatement(
          '''
          UPDATE $cachedStockBagsTableName
          SET status = ?, updated_at = ?
          WHERE warehouse_id = ?
            AND crop = ?
            AND status = ?
          ''',
          [
            'NOT_IN_STOCK',
            now.millisecondsSinceEpoch,
            warehouseId,
            cropId,
            status,
          ],
        );
      } else {
        final placeholders = List.filled(activeUuids.length, '?').join(', ');
        await customStatement(
          '''
          UPDATE $cachedStockBagsTableName
          SET status = ?, updated_at = ?
          WHERE warehouse_id = ?
            AND crop = ?
            AND status = ?
            AND uuid NOT IN ($placeholders)
          ''',
          [
            'NOT_IN_STOCK',
            now.millisecondsSinceEpoch,
            warehouseId,
            cropId,
            status,
            ...activeUuids,
          ],
        );
      }

      for (final entry in entries) {
        await _upsertCachedStockBag(entry);
      }
    });
  }

  Future<void> markCachedStockBags({
    required Iterable<String> uuids,
    required String status,
  }) async {
    final normalized = uuids
        .map((uuid) => uuid.trim())
        .where((uuid) => uuid.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) return;

    final placeholders = List.filled(normalized.length, '?').join(', ');
    await customStatement(
      '''
      UPDATE $cachedStockBagsTableName
      SET status = ?, updated_at = ?
      WHERE uuid IN ($placeholders)
      ''',
      [
        status,
        DateTime.now().millisecondsSinceEpoch,
        ...normalized,
      ],
    );
  }

  Future<void> _upsertCachedStockBag(CachedStockBagEntry entry) {
    return customStatement(
      '''
      INSERT INTO $cachedStockBagsTableName (
        uuid,
        server_id,
        warehouse_id,
        collection_center_uuid,
        crop,
        crop_name,
        tag_number,
        gross_weight,
        packaging_weight,
        load_weight,
        net_weight,
        moisture_content,
        status,
        last_seen_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(uuid) DO UPDATE SET
        server_id = excluded.server_id,
        warehouse_id = excluded.warehouse_id,
        collection_center_uuid = excluded.collection_center_uuid,
        crop = excluded.crop,
        crop_name = excluded.crop_name,
        tag_number = excluded.tag_number,
        gross_weight = excluded.gross_weight,
        packaging_weight = excluded.packaging_weight,
        load_weight = excluded.load_weight,
        net_weight = excluded.net_weight,
        moisture_content = excluded.moisture_content,
        status = excluded.status,
        last_seen_at = excluded.last_seen_at,
        updated_at = excluded.updated_at
      ''',
      [
        entry.uuid,
        entry.serverId,
        entry.warehouseId,
        entry.collectionCenterUuid,
        entry.crop,
        entry.cropName,
        entry.tagNumber,
        entry.grossWeight,
        entry.packagingWeight,
        entry.loadWeight,
        entry.netWeight,
        entry.moistureContent,
        entry.status,
        entry.lastSeenAt?.millisecondsSinceEpoch,
        entry.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  CachedStockBagEntry _cachedStockBagFromRow(QueryRow row) {
    DateTime? nullableDate(String column) {
      final millis = row.readNullable<int>(column);
      return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    }

    return CachedStockBagEntry(
      uuid: row.read<String>('uuid'),
      serverId: row.readNullable<int>('server_id'),
      warehouseId: row.read<String>('warehouse_id'),
      collectionCenterUuid: row.read<String>('collection_center_uuid'),
      crop: row.read<int>('crop'),
      cropName: row.read<String>('crop_name'),
      tagNumber: row.read<String>('tag_number'),
      grossWeight: row.read<double>('gross_weight'),
      packagingWeight: row.read<double>('packaging_weight'),
      loadWeight: row.read<double>('load_weight'),
      netWeight: row.read<double>('net_weight'),
      moistureContent: row.read<double>('moisture_content'),
      status: row.read<String>('status'),
      lastSeenAt: nullableDate('last_seen_at'),
      updatedAt: nullableDate('updated_at') ?? DateTime.now(),
    );
  }

  Future<List<SyncQueueData>> pendingStockBagMutationEntries() {
    return (select(syncQueue)
          ..where(
            (item) =>
                item.entityType.equals('dispatches') &
                item.syncStatus.isIn(['pending', 'conflict']),
          ))
        .get();
  }

  Future<List<SyncQueueData>> pendingStockBagAdjustmentEntries() {
    return (select(syncQueue)
          ..where(
            (item) =>
                item.entityType.equals('stockAdjustments') &
                item.syncStatus.isIn(['pending', 'conflict']),
          ))
        .get();
  }

  Stream<List<WarehouseDispatch>> watchDispatches(String warehouseId) {
    return (select(warehouseDispatches)
          ..where((item) =>
              item.warehouseId.equals(warehouseId) &
              item.deletedAt.isNull())
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
              item.warehouseId.equals(warehouseId) &
              item.deletedAt.isNull())
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
              item.warehouseId.equals(warehouseId) &
              item.deletedAt.isNull())
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
