// [
//     {
//         "id": 2,
//         "name": "Stroman - Kuhlman",
//         "type": "AGRICULTURAL",
//         "region": 1,
//         "regionName": "Lake Elvaburgh",
//         "address": "438 Paolo Dale",
//         "registrationNumber": "5",
//         "phoneNumber": "279-896-1202",
//         "email": "Dahlia_Moore78@hotmail.com",
//         "tinNumber": "j",
//         "website": "https://blake.com",
//         "contactPersonName": "Kelley Mueller Sr.",
//         "contactPersonPhoneNumber": "709-426-0435",
//         "contactPersonEmail": "Royal.Murray64@hotmail.com",
//         "contactPersonTitle": "National Integration Associate",
//         "status": "ACTIVE"
//     },
//     {
//         "id": 3,
//         "name": "Schmitt - Powlowski",
//         "type": "AGRICULTURAL",
//         "region": 1,
//         "regionName": "Nadiaborough",
//         "address": "64724 Goyette Springs",
//         "registrationNumber": "o",
//         "phoneNumber": "223-512-3100",
//         "email": "Mckayla.Ernser@hotmail.com",
//         "tinNumber": "m",
//         "website": "http://reymundo.net",
//         "contactPersonName": "Krystal Sauer",
//         "contactPersonPhoneNumber": "344-415-5472",
//         "contactPersonEmail": "Jalon_Grimes25@hotmail.com",
//         "contactPersonTitle": "Future Program Technician",
//         "status": "ACTIVE"
//     }
// ]



import 'package:drift/drift.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';

@DataClassName('Mcu')
class McuTable extends Table {

  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  IntColumn get region => integer().references(RegionsTable,#id)();
  TextColumn get regionName => text()();
  TextColumn get address => text()();
  TextColumn get registrationNumber => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get email => text()();
  TextColumn get tinNumber => text()();
  TextColumn get website => text()();
  TextColumn get contactPersonName => text()();
  TextColumn get contactPersonPhoneNumber => text()();
  TextColumn get contactPersonEmail => text()();
  TextColumn get contactPersonTitle => text()();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};
}