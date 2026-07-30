import 'package:drift/drift.dart';
import 'package:warehouse_app/features/additional.data/amcos/data/tables/amcos_table.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';

class Warehouses extends Table {
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get ownerId => text().nullable()();
  TextColumn get gpsLocation => text().nullable()();
  IntColumn get amcos => integer().nullable().references(AmcosTable, #id)();
  TextColumn get amcosName => text().nullable()();
  IntColumn get village =>
      integer().nullable().references(VillagesTable, #id)();
  TextColumn get villageName => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(true))();
  TextColumn get syncAction => text().withDefault(const Constant('created'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
