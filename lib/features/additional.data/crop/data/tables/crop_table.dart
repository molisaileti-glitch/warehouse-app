import 'package:drift/drift.dart';

@DataClassName('Crop')
class CropTable extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get type => text().nullable()();
  TextColumn get uom => text().nullable()();
  TextColumn get packaging => text().nullable()();
  TextColumn get grading => text().nullable()();
  BoolColumn get moistureContentComputation =>
      boolean().withDefault(const Constant(false))();
  RealColumn get maxMoisureContent => real().nullable()();
  RealColumn get packagingWeight => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
