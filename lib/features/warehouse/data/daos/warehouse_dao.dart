import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';

part 'warehouse_dao.g.dart';

@DriftAccessor(tables: [Warehouses])
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

  Stream<Warehouse?> watchWarehouseById(String id) {
    return (select(warehouses)..where((w) => w.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Warehouse?> getWarehouseByUuid(String uuid) {
    return (select(warehouses)..where((w) => w.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<List<Warehouse>> getAllWarehouses() {
    return (select(warehouses)
          ..where((w) => w.deletedAt.isNull())
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

  Future<void> upsertWarehouse(WarehousesCompanion entry) {
    return into(warehouses).insertOnConflictUpdate(entry);
  }

  Future<bool> updateWarehouse(WarehousesCompanion entry) {
    return (update(warehouses)..where((w) => w.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
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
}
