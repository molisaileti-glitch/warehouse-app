import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/tables/sync_mixin.dart';
import 'package:warehouse_app/features/additional.data/crop/data/tables/crop_table.dart';
import 'package:warehouse_app/features/farmer/data/tables/farmer_tables.dart';
import 'package:warehouse_app/features/warehouse/data/tables/warehouse_table.dart';

@DataClassName('MeasurementUnit')
class MeasurementUnits extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get type => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CropGrade')
class CropGrades extends Table {
  IntColumn get id => integer()();
  IntColumn get crop => integer().references(CropTable, #id)();
  TextColumn get gradeName => text()();
  RealColumn get unitPrice => real().nullable()();
  TextColumn get status => text().nullable()();
  IntColumn get amcos => integer().nullable()();
  TextColumn get amcosName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FarmerHarvest')
class FarmerHarvests extends Table with SyncMixin {
  TextColumn get uuid => text()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get farmer => integer().references(Farmers, #id)();
  TextColumn get farmerUuid => text().nullable()();
  TextColumn get farmerName => text()();
  TextColumn get farmerPhoneNumber => text()();
  @ReferenceName('guarantorHarvests')
  IntColumn get guarantor => integer().nullable().references(Farmers, #id)();
  TextColumn get guarantorName => text().nullable()();
  RealColumn get grossWeight => real()();
  RealColumn get netWeight => real()();
  RealColumn get packagingWeight => real()();
  RealColumn get moistureContent => real()();
  IntColumn get uom => integer().nullable().references(MeasurementUnits, #id)();
  TextColumn get uomName => text().nullable()();
  TextColumn get packaging => text().withDefault(const Constant('BAGS'))();
  TextColumn get receiptNumber => text()();
  IntColumn get amcos => integer().nullable()();
  TextColumn get amcosName => text().nullable()();
  IntColumn get mcu => integer().nullable()();
  TextColumn get mcuName => text().nullable()();
  IntColumn get receivedBy => integer().nullable()();
  TextColumn get receivedByName => text().nullable()();
  IntColumn get crop => integer().references(CropTable, #id)();
  TextColumn get cropName => text()();
  IntColumn get cropGrade => integer().nullable().references(CropGrades, #id)();
  TextColumn get cropGradeName => text().nullable()();
  TextColumn get warehouseId => text().references(Warehouses, #id)();
  IntColumn get collectionCenter => integer().nullable()();
  TextColumn get collectionCenterName => text()();
  DateTimeColumn get receivedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('FarmerHarvestBag')
class FarmerHarvestBags extends Table {
  TextColumn get id => text()();
  TextColumn get harvestUuid => text().references(FarmerHarvests, #uuid)();
  RealColumn get netWeight => real()();
  TextColumn get tag => text()();
  RealColumn get loadWeight => real()();
  RealColumn get grossWeight => real()();
  RealColumn get moistureWeight => real()();
  RealColumn get moistureContent => real()();
  RealColumn get packagingWeight => real()();

  @override
  Set<Column> get primaryKey => {id};
}
