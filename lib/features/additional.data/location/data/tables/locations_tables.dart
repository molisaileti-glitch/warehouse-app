import 'package:drift/drift.dart';

@DataClassName('Region')
class RegionsTable extends Table{
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get postCode => text()();
  @override
  Set<Column> get primaryKey => {id};
}


@DataClassName('District')
class DistrictsTable extends Table{
  IntColumn get id => integer()();
  TextColumn get name => text()();
  IntColumn get region => integer().references(RegionsTable, #id)();
  TextColumn get regionName => text()();
  @override
  Set<Column> get primaryKey => {id};
  
}

@DataClassName('Ward')
class WardsTable extends Table{
  IntColumn get id => integer()();
  TextColumn get name => text()();
  IntColumn get district => integer().references(DistrictsTable, #id)();
  TextColumn get districtName => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Village')
class VillagesTable extends Table{
  IntColumn get id => integer()();
  TextColumn get name => text()();
  IntColumn get ward => integer().references(WardsTable, #id)();
  TextColumn get wardName => text()();
  @override
  Set<Column> get primaryKey => {id};
}