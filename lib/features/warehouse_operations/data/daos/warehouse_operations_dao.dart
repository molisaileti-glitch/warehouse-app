import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/stock_bag/data/tables/stock_bag_table.dart';
import 'package:warehouse_app/features/warehouse_reports/data/tables/warehouse_report_cache_tables.dart';

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

  Future<void> refreshInventorySummariesForCachedStockBags({
    required Iterable<String> uuids,
  }) async {
    final normalized = uuids
        .map((uuid) => uuid.trim())
        .where((uuid) => uuid.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) return;

    final placeholders = List.filled(normalized.length, '?').join(', ');
    final affected = await customSelect(
      '''
      SELECT DISTINCT warehouse_id, crop
      FROM $cachedStockBagsTableName
      WHERE uuid IN ($placeholders)
      ''',
      variables: normalized.map((uuid) => Variable<String>(uuid)).toList(),
    ).get();

    for (final row in affected) {
      await refreshInventorySummaryFromCachedStockBags(
        warehouseId: row.read<String>('warehouse_id'),
        cropId: row.read<int>('crop'),
      );
    }
  }

  Future<void> refreshInventorySummaryFromCachedStockBags({
    required String warehouseId,
    required int cropId,
  }) async {
    final bags = await getCachedStockBags(
      warehouseId: warehouseId,
      cropId: cropId,
      status: 'IN_STOCK',
    );
    final totalGross = bags.fold<double>(
      0,
      (sum, bag) => sum + bag.grossWeight,
    );
    final totalPackaging = bags.fold<double>(
      0,
      (sum, bag) => sum + bag.packagingWeight,
    );
    final totalNet = bags.fold<double>(
      0,
      (sum, bag) => sum + bag.netWeight,
    );

    await (update(warehouseInventoryItems)
          ..where(
            (item) =>
                item.warehouseId.equals(warehouseId) & item.crop.equals(cropId),
          ))
        .write(
      WarehouseInventoryItemsCompanion(
        totalBags: Value(bags.length),
        totalGrossWeight: Value(totalGross),
        totalPackagingWeight: Value(totalPackaging),
        totalNetWeight: Value(totalNet),
        updatedAt: Value(DateTime.now()),
      ),
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
      return millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis);
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
              item.warehouseId.equals(warehouseId) & item.deletedAt.isNull())
          ..orderBy([(item) => OrderingTerm.desc(item.dispatchedAt)]))
        .watch();
  }

  Future<WarehouseDispatch?> getDispatchByUuid(String uuid) {
    return (select(warehouseDispatches)
          ..where((item) => item.uuid.equals(uuid)))
        .getSingleOrNull();
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

  Future<WarehouseStockAdjustment?> getStockAdjustmentByUuid(String uuid) {
    return (select(warehouseStockAdjustments)
          ..where((item) => item.uuid.equals(uuid)))
        .getSingleOrNull();
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

  Future<void> cacheWarehouseReportActivity({
    required Map<String, Object?> activity,
    required List<Map<String, Object?>> bags,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uuid = activity['uuid']?.toString() ?? '';
    if (uuid.isEmpty) return Future.value();

    return transaction(() async {
      await customStatement(
        '''
        INSERT INTO $warehouseReportActivitiesTable (
          uuid,
          activity_type,
          warehouse_id,
          collection_center_uuid,
          collection_center_name,
          crop,
          crop_name,
          total_bags,
          total_gross_weight,
          total_net_weight,
          worker_id,
          worker_name,
          activity_at,
          farmer_name,
          farmer_phone_number,
          receipt_number,
          recipient_type,
          recipient_name,
          recipient_phone,
          adjustment_type,
          reason,
          net_weight_change,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(uuid) DO UPDATE SET
          activity_type = excluded.activity_type,
          warehouse_id = excluded.warehouse_id,
          collection_center_uuid = excluded.collection_center_uuid,
          collection_center_name = excluded.collection_center_name,
          crop = excluded.crop,
          crop_name = excluded.crop_name,
          total_bags = excluded.total_bags,
          total_gross_weight = excluded.total_gross_weight,
          total_net_weight = excluded.total_net_weight,
          worker_id = excluded.worker_id,
          worker_name = excluded.worker_name,
          activity_at = excluded.activity_at,
          farmer_name = excluded.farmer_name,
          farmer_phone_number = excluded.farmer_phone_number,
          receipt_number = excluded.receipt_number,
          recipient_type = excluded.recipient_type,
          recipient_name = excluded.recipient_name,
          recipient_phone = excluded.recipient_phone,
          adjustment_type = excluded.adjustment_type,
          reason = excluded.reason,
          net_weight_change = excluded.net_weight_change,
          updated_at = excluded.updated_at
        ''',
        [
          uuid,
          _text(activity['activityType']),
          _text(activity['warehouseId']),
          _text(activity['collectionCenterUuid']),
          _text(activity['collectionCenterName']),
          _int(activity['crop']),
          _text(activity['cropName']),
          _int(activity['totalBags']),
          _nullableDouble(activity['totalGrossWeight']),
          _nullableDouble(activity['totalNetWeight']),
          _nullableInt(activity['workerId']),
          _text(activity['workerName']),
          _millis(activity['activityAt']),
          _nullableText(activity['farmerName']),
          _nullableText(activity['farmerPhoneNumber']),
          _nullableText(activity['receiptNumber']),
          _nullableText(activity['recipientType']),
          _nullableText(activity['recipientName']),
          _nullableText(activity['recipientPhone']),
          _nullableText(activity['adjustmentType']),
          _nullableText(activity['reason']),
          _nullableDouble(activity['netWeightChange']),
          now,
        ],
      );

      await customStatement(
        'DELETE FROM $warehouseReportBagsTable WHERE activity_uuid = ?',
        [uuid],
      );

      for (var index = 0; index < bags.length; index++) {
        final bag = bags[index];
        await customStatement(
          '''
          INSERT INTO $warehouseReportBagsTable (
            id,
            activity_uuid,
            stock_bag_uuid,
            tag_number,
            gross_weight,
            packaging_weight,
            net_weight,
            previous_net_weight,
            net_weight_difference,
            moisture_content
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            '$uuid-$index',
            uuid,
            _text(bag['stockBagUuid']),
            _text(bag['tagNumber']),
            _double(bag['grossWeight']),
            _double(bag['packagingWeight']),
            _double(bag['netWeight']),
            _nullableDouble(bag['previousNetWeight']),
            _nullableDouble(bag['netWeightDifference']),
            _double(bag['moistureContent']),
          ],
        );
      }
    });
  }

  int _millis(Object? value) {
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    return DateTime.tryParse(value?.toString() ?? '')?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
  }

  String _text(Object? value) => _nullableText(value) ?? '';

  String? _nullableText(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      for (final key in const [
        'name',
        'fullName',
        'label',
        'title',
        'uuid',
        'id',
        'value',
      ]) {
        if (value.containsKey(key)) {
          final text = _nullableText(value[key]);
          if (text != null) return text;
        }
      }
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int _int(Object? value) => _nullableInt(value) ?? 0;

  int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is Map) {
      for (final key in const ['id', 'serverId', 'pk', 'value']) {
        if (value.containsKey(key)) {
          final parsed = _nullableInt(value[key]);
          if (parsed != null) return parsed;
        }
      }
    }
    return int.tryParse(value.toString().trim());
  }

  double _double(Object? value) => _nullableDouble(value) ?? 0;

  double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is bool) return value ? 1 : 0;
    if (value is Map) {
      for (final key in const ['amount', 'weight', 'value']) {
        if (value.containsKey(key)) {
          final parsed = _nullableDouble(value[key]);
          if (parsed != null) return parsed;
        }
      }
    }
    return double.tryParse(value.toString().trim());
  }
}
