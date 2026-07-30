import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/tables/sync_mixin.dart';
import 'package:warehouse_app/features/warehouse/data/tables/warehouse_table.dart';
import 'package:warehouse_app/features/worker/data/tables/worker_table.dart';

class InventoryItems extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get sku => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get quantityOnHand => real().withDefault(const Constant(0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0))();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class StockMovements extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get inventoryItemId => text().references(InventoryItems, #id)();

  @ReferenceName('movementsAtWarehouse')
  TextColumn get warehouseId => text().references(Warehouses, #id)();

  TextColumn get movementType => text()();
  RealColumn get quantity => real()();
  RealColumn get quantityBefore => real()();
  TextColumn get recordedById => text().references(Users, #id)();
  TextColumn get notes => text().nullable()();

  @ReferenceName('relatedMovements')
  TextColumn get relatedWarehouseId =>
      text().nullable().references(Warehouses, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

class AuditLogs extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get warehouseId => text().nullable().references(Warehouses, #id)();
  TextColumn get action => text()();
  TextColumn get metadata => text().nullable()();
  TextColumn get origin => text().withDefault(const Constant('online'))();

  @override
  Set<Column> get primaryKey => {id};
}
