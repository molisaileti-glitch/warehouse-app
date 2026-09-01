import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/tables/sync_mixin.dart';
import 'package:warehouse_app/features/additional.data/crop/data/tables/crop_table.dart';
import 'package:warehouse_app/features/warehouse/data/tables/warehouse_table.dart';

@DataClassName('WarehouseInventory')
class WarehouseInventoryItems extends Table {
  TextColumn get uuid => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  IntColumn get collectionCenter => integer().nullable()();
  TextColumn get collectionCenterUuid => text()();
  TextColumn get collectionCenterName => text().nullable()();
  IntColumn get amcos => integer().nullable()();
  TextColumn get amcosName => text().nullable()();
  IntColumn get mcu => integer().nullable()();
  TextColumn get mcuName => text().nullable()();
  IntColumn get crop => integer().references(CropTable, #id)();
  TextColumn get cropName => text()();
  IntColumn get totalBags => integer().withDefault(const Constant(0))();
  RealColumn get totalGrossWeight => real().withDefault(const Constant(0))();
  RealColumn get totalPackagingWeight =>
      real().withDefault(const Constant(0))();
  RealColumn get totalNetWeight => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('WarehouseDispatch')
class WarehouseDispatches extends Table with SyncMixin {
  TextColumn get uuid => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  IntColumn get collectionCenter => integer().nullable()();
  TextColumn get collectionCenterUuid => text()();
  TextColumn get collectionCenterName => text().nullable()();
  IntColumn get amcos => integer().nullable()();
  TextColumn get amcosName => text().nullable()();
  IntColumn get mcu => integer().nullable()();
  TextColumn get mcuName => text().nullable()();
  IntColumn get crop => integer().references(CropTable, #id)();
  TextColumn get cropName => text()();
  TextColumn get recipientType => text()();
  TextColumn get recipientName => text()();
  TextColumn get recipientPhone => text().nullable()();
  IntColumn get totalBags => integer()();
  RealColumn get totalGrossWeight => real()();
  RealColumn get totalPackagingWeight => real()();
  RealColumn get totalNetWeight => real()();
  RealColumn get moistureContent => real().withDefault(const Constant(0))();
  IntColumn get dispatchedBy => integer().nullable()();
  TextColumn get dispatchedByName => text().nullable()();
  DateTimeColumn get dispatchedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('WarehouseStockCount')
class WarehouseStockCounts extends Table with SyncMixin {
  TextColumn get uuid => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  IntColumn get collectionCenter => integer().nullable()();
  TextColumn get collectionCenterUuid => text()();
  TextColumn get collectionCenterName => text().nullable()();
  IntColumn get amcos => integer().nullable()();
  TextColumn get amcosName => text().nullable()();
  IntColumn get mcu => integer().nullable()();
  TextColumn get mcuName => text().nullable()();
  IntColumn get crop => integer().references(CropTable, #id)();
  TextColumn get cropName => text()();
  IntColumn get expectedBags => integer().withDefault(const Constant(0))();
  RealColumn get expectedNetWeight => real().withDefault(const Constant(0))();
  IntColumn get countedBags => integer()();
  RealColumn get countedGrossWeight => real()();
  RealColumn get countedPackagingWeight => real()();
  RealColumn get countedNetWeight => real()();
  RealColumn get moistureContent => real().withDefault(const Constant(0))();
  IntColumn get countedBy => integer().nullable()();
  TextColumn get countedByName => text().nullable()();
  DateTimeColumn get countedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('WarehouseStockAdjustment')
class WarehouseStockAdjustments extends Table with SyncMixin {
  TextColumn get uuid => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  IntColumn get collectionCenter => integer().nullable()();
  TextColumn get collectionCenterUuid => text()();
  TextColumn get collectionCenterName => text().nullable()();
  IntColumn get amcos => integer().nullable()();
  TextColumn get amcosName => text().nullable()();
  IntColumn get mcu => integer().nullable()();
  TextColumn get mcuName => text().nullable()();
  IntColumn get crop => integer().references(CropTable, #id)();
  TextColumn get cropName => text()();
  TextColumn get adjustmentType => text()();
  TextColumn get reason => text()();
  IntColumn get bags => integer()();
  RealColumn get grossWeight => real()();
  RealColumn get packagingWeight => real()();
  RealColumn get netWeight => real()();
  RealColumn get moistureContent => real().withDefault(const Constant(0))();
  IntColumn get adjustedBy => integer().nullable()();
  TextColumn get adjustedByName => text().nullable()();
  DateTimeColumn get adjustedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {uuid};
}
