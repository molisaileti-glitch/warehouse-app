
//         "name": "Upton, Bergstrom and Corkery",
//         "memberCategory": "FISHERMAN",
//         "registrationNumber": "472",
//         "tinNumber": "35",
//         "mcu": 1,
//         "mcuName": "mcu",
//         "region": 1,
//         "regionName": "dar",
//         "district": 1,
//         "districtName": "a",
//         "ward": 1,
//         "wardName": "a",
//         "village": 1,
//         "villageName": "a",
//         "phoneNumber": "0698700269",
//         "email": "Kade80@hotmail.com",
//         "contactPersonName": "Rogelio Robel",
//         "contactPersonPhoneNumber": "975-252-8741",
//         "contactPersonEmail": "Isai.Cartwright@gmail.com",
//         "contactPersonTitle": "Meneja",
//         "website": "www.amcoss.com",
//         "status": "ACTIVE",
//         "crops": "1",
//         "idCounter": 0

import 'package:drift/drift.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';

@DataClassName('Amcos')
class AmcosTable extends Table {
  IntColumn get id => integer()();
  // UUID generated locally at creation time; populated from server on pull.
  // Null for AMCOS that were pulled before the backend added the uuid field.
  TextColumn get uuid => text().nullable()();
  // The real server-assigned integer ID. Null until the AMCOS is successfully
  // pushed (i.e. when id is a local negative placeholder). For AMCOS that were
  // pulled from the server, id == serverId, so serverId is left null and the
  // resolution logic checks id > 0 first.
  IntColumn get serverId => integer().nullable()();
  // 'pending'  — created locally, not yet pushed
  // 'synced'   — confirmed on the server
  // 'conflict' — push was rejected by the server
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();
  TextColumn get name => text()();
  TextColumn get memberCategory => text()();
  TextColumn get registrationNumber => text()();
  TextColumn get tinNumber => text()();
  IntColumn get mcu => integer()();
  TextColumn get mcuName => text()();
  IntColumn get region => integer().references(RegionsTable,#id)();
  TextColumn get regionName => text()();
  IntColumn get district => integer().references(DistrictsTable,#id)();
  TextColumn get districtName => text()();
  IntColumn get ward => integer().references(WardsTable,#id)();
  TextColumn get wardName => text()();
  IntColumn get village => integer().references(VillagesTable,#id)();
  TextColumn get villageName => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get email => text()();
  TextColumn get contactPersonName => text()();
  TextColumn get contactPersonPhoneNumber => text()();
  TextColumn get contactPersonEmail => text()();
  TextColumn get contactPersonTitle => text()();
  TextColumn get website => text()();
  TextColumn get status => text()();
  TextColumn get crops => text()();
  IntColumn get idCounter => integer()();
  
  @override
  Set<Column> get primaryKey => {id};
}