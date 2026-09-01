import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';

part 'warehouse_dao.g.dart';

@DriftAccessor(
  tables: [
    Warehouses,
    Users,
    InventoryItems,
    StockMovements,
    WarehouseInventoryItems,
    WarehouseDispatches,
    WarehouseStockCounts,
    WarehouseStockAdjustments,
    AuditLogs,
    FarmerHarvests,
    SyncQueue,
    RegionsTable,
    DistrictsTable,
    WardsTable,
    VillagesTable,
    AmcosTable,
  ],
)
class WarehouseDao extends DatabaseAccessor<AppDatabase>
    with _$WarehouseDaoMixin {
  WarehouseDao(super.db);

  Stream<List<Warehouse>> watchAllWarehouses() {
    return (select(warehouses)
          ..where((w) => w.deletedAt.isNull() & w.isActive.isValue(true))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  Stream<List<Warehouse>> watchWarehousesByOwner(String ownerId) {
    return (select(warehouses)
          ..where(
            (w) =>
                w.ownerId.equals(ownerId) &
                w.deletedAt.isNull() &
                w.isActive.isValue(true),
          )
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  Stream<List<Warehouse>> watchWarehousesByAmcos(int amcosId) {
    return (select(warehouses)
          ..where(
            (w) =>
                w.amcos.equals(amcosId) &
                w.deletedAt.isNull() &
                w.isActive.isValue(true),
          )
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  Stream<Warehouse?> watchWarehouseById(String id) {
    return (select(warehouses)..where((w) => w.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Warehouse?> getWarehouseByUuid(String uuid) async {
    final matches =
        await (select(warehouses)..where((w) => w.uuid.equals(uuid))).get();
    if (matches.isEmpty) return null;
    matches.sort((a, b) =>
        _reconciliationPriority(a).compareTo(_reconciliationPriority(b)));
    return matches.first;
  }

  Future<List<Warehouse>> getAllWarehouses() {
    return (select(warehouses)
          ..where((w) => w.deletedAt.isNull())
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();
  }

  Future<List<Warehouse>> getWarehousesByAmcos(int amcosId) {
    return (select(warehouses)
          ..where(
            (w) =>
                w.amcos.equals(amcosId) &
                w.deletedAt.isNull() &
                w.isActive.isValue(true),
          )
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();
  }

  Future<Warehouse?> getWarehouseById(String id) {
    return (select(warehouses)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Warehouse>> getPendingWarehouses() {
    return (select(warehouses)..where((w) => w.syncStatus.equals('pending')))
        .get();
  }

  Future<void> insertWarehouse(WarehousesCompanion entry) =>
      into(warehouses).insert(entry);

  Future<void> insertPendingWarehouse({
    required WarehousesCompanion warehouse,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await into(warehouses).insert(warehouse);
      await into(syncQueue).insert(queueEntry);
    });
  }

  Future<void> upsertWarehouse(WarehousesCompanion entry) {
    return into(warehouses).insertOnConflictUpdate(entry);
  }

  Future<void> reconcileWarehouseId({
    required String localId,
    required WarehousesCompanion serverWarehouse,
  }) {
    final serverId = serverWarehouse.id.value;
    final collectionCenterId = int.tryParse(serverId);
    final now = DateTime.now();

    if (localId == serverId) {
      return upsertWarehouse(serverWarehouse);
    }

    return transaction(() async {
      await into(warehouses).insertOnConflictUpdate(serverWarehouse);

      await (update(users)..where((u) => u.warehouseId.equals(localId))).write(
        UsersCompanion(
          warehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(inventoryItems)
            ..where((i) => i.warehouseId.equals(localId)))
          .write(
        InventoryItemsCompanion(
          warehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(stockMovements)
            ..where((m) => m.warehouseId.equals(localId)))
          .write(
        StockMovementsCompanion(
          warehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(stockMovements)
            ..where((m) => m.relatedWarehouseId.equals(localId)))
          .write(
        StockMovementsCompanion(
          relatedWarehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(warehouseInventoryItems)
            ..where((i) => i.warehouseId.equals(localId)))
          .write(
        WarehouseInventoryItemsCompanion(
          warehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(warehouseDispatches)
            ..where((item) => item.warehouseId.equals(localId)))
          .write(
        WarehouseDispatchesCompanion(
          warehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(warehouseStockCounts)
            ..where((item) => item.warehouseId.equals(localId)))
          .write(
        WarehouseStockCountsCompanion(
          warehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(warehouseStockAdjustments)
            ..where((item) => item.warehouseId.equals(localId)))
          .write(
        WarehouseStockAdjustmentsCompanion(
          warehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(auditLogs)..where((l) => l.warehouseId.equals(localId)))
          .write(
        AuditLogsCompanion(
          warehouseId: Value(serverId),
          updatedAt: Value(now),
        ),
      );
      await (update(farmerHarvests)
            ..where((h) => h.warehouseId.equals(localId)))
          .write(
        FarmerHarvestsCompanion(
          warehouseId: Value(serverId),
          collectionCenter: Value(collectionCenterId),
          updatedAt: Value(now),
        ),
      );

      await (delete(warehouses)..where((w) => w.id.equals(localId))).go();
    });
  }

  Future<void> ensureWarehouseReferences({
    int? amcosId,
    String? amcosName,
    int? mcu,
    String? mcuName,
    int? villageId,
    String? villageName,
  }) {
    return transaction(() async {
      final locationId = villageId ?? 0;
      final locationName = _nonEmpty(villageName) ?? 'Unknown';

      await into(regionsTable).insert(
        RegionsTableCompanion(
          id: Value(locationId),
          name: Value(locationName),
          postCode: const Value(''),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await into(districtsTable).insert(
        DistrictsTableCompanion(
          id: Value(locationId),
          name: Value(locationName),
          region: Value(locationId),
          regionName: Value(locationName),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await into(wardsTable).insert(
        WardsTableCompanion(
          id: Value(locationId),
          name: Value(locationName),
          district: Value(locationId),
          districtName: Value(locationName),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await into(villagesTable).insert(
        VillagesTableCompanion(
          id: Value(locationId),
          name: Value(locationName),
          ward: Value(locationId),
          wardName: Value(locationName),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      if (amcosId == null || amcosId <= 0) return;
      await into(amcosTable).insert(
        AmcosTableCompanion(
          id: Value(amcosId),
          name: Value(_nonEmpty(amcosName) ?? 'AMCOS $amcosId'),
          memberCategory: const Value('FARMERS'),
          registrationNumber: Value(amcosId.toString()),
          tinNumber: const Value(''),
          mcu: Value(mcu ?? 0),
          mcuName: Value(_nonEmpty(mcuName) ?? ''),
          region: Value(locationId),
          regionName: Value(locationName),
          district: Value(locationId),
          districtName: Value(locationName),
          ward: Value(locationId),
          wardName: Value(locationName),
          village: Value(locationId),
          villageName: Value(locationName),
          phoneNumber: const Value(''),
          email: const Value(''),
          contactPersonName: const Value(''),
          contactPersonPhoneNumber: const Value(''),
          contactPersonEmail: const Value(''),
          contactPersonTitle: const Value(''),
          website: const Value(''),
          status: const Value('ACTIVE'),
          crops: const Value(''),
          idCounter: const Value(0),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<bool> updateWarehouse(WarehousesCompanion entry) {
    return (update(warehouses)..where((w) => w.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  Future<void> updatePendingWarehouse({
    required WarehousesCompanion warehouse,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await (update(warehouses)
            ..where((item) => item.id.equals(warehouse.id.value)))
          .write(warehouse);
      await into(syncQueue).insert(queueEntry);
    });
  }

  Future<void> softDeleteWarehouse(String id) {
    return (update(warehouses)..where((w) => w.id.equals(id))).write(
      WarehousesCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deletePendingWarehouse({
    required String id,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await (update(warehouses)..where((item) => item.id.equals(id))).write(
        WarehousesCompanion(
          deletedAt: Value(DateTime.now()),
          syncStatus: const Value('pending'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await into(syncQueue).insert(queueEntry);
    });
  }

  Future<void> markWarehouseSynced(String id) {
    return (update(warehouses)..where((w) => w.id.equals(id))).write(
      WarehousesCompanion(
        synced: const Value(true),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markWarehouseConflict(String id) {
    return (update(warehouses)..where((w) => w.id.equals(id))).write(
      WarehousesCompanion(
        synced: const Value(false),
        syncStatus: const Value('conflict'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String? _nonEmpty(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  int _reconciliationPriority(Warehouse warehouse) {
    if (int.tryParse(warehouse.id) == null) return 0;
    if (warehouse.syncStatus == 'pending' ||
        warehouse.syncStatus == 'conflict') {
      return 1;
    }
    return 2;
  }
}
