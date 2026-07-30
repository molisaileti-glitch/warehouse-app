import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/tables/sync_mixin.dart';

class Users extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get fullName => text().withLength(min: 1, max: 120)();
  TextColumn get email => text().withLength(min: 3, max: 200)();
  TextColumn get phoneNumber =>
      text().withLength(min: 0, max: 30).withDefault(const Constant(''))();
  TextColumn get password => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('AMCOS_USER'))();
  IntColumn get mcu => integer().nullable()();
  IntColumn get amcos => integer().nullable()();
  TextColumn get warehouseId => text().nullable()();
  TextColumn get pushToken => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
