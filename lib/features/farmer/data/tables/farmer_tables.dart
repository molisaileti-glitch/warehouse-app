import 'package:drift/drift.dart';
import 'package:warehouse_app/features/additional.data/amcos/data/tables/amcos_table.dart';
import 'package:warehouse_app/features/additional.data/crop/data/tables/crop_table.dart';

@DataClassName('Farmer')
class Farmers extends Table {
  IntColumn get id => integer()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get firstName => text()();
  TextColumn get middleName => text().nullable()();
  TextColumn get lastName => text()();
  TextColumn get sex => text()();
  TextColumn get idType => text()();
  TextColumn get idNumber => text()();
  TextColumn get dob => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get tumeNumber => text().nullable()();
  TextColumn get amcosMemberID => text().nullable()();
  @ReferenceName('mainCropFarmers')
  IntColumn get mainCrop => integer().references(CropTable, #id)();

  @ReferenceName('secondaryCropFarmers')
  IntColumn get secondaryCrop => integer().references(CropTable, #id)();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  IntColumn get amcos => integer().references(AmcosTable, #id)();
  TextColumn get amcosName => text().nullable()();
  IntColumn get mcu => integer()();
  TextColumn get mcuName => text().nullable()();
  TextColumn get educationLevel =>
      text().withDefault(const Constant('PRIMARY'))();
  TextColumn get memberType => text()();
  TextColumn get ttbNumber => text().nullable()();
  TextColumn get tinNumber => text().nullable()();
  TextColumn get voterId => text().nullable()();
  TextColumn get driversLicense => text().nullable()();
  BoolColumn get fingerprintCaptured =>
      boolean().withDefault(const Constant(false))();
  TextColumn get uuid => text().nullable()();
  TextColumn get maritalStatus => text()();
  RealColumn get noOfShares => real().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FarmerDependant')
class FarmerDependants extends Table {
  IntColumn get id => integer()();
  IntColumn get farmerId => integer().references(Farmers, #id)();
  TextColumn get firstName => text()();
  TextColumn get middleName => text().nullable()();
  TextColumn get lastName => text()();
  TextColumn get relationship => text()();
  TextColumn get dob => text()();
  TextColumn get gender => text()();
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
