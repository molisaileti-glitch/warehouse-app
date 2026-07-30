import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';
import 'package:warehouse_app/features/additional.data/location/domain/models/region_model.dart';

part 'region_dao.g.dart';

@DriftAccessor(tables: [RegionsTable])
class RegionDao extends DatabaseAccessor<AppDatabase> with _$RegionDaoMixin {
   RegionDao(super.db);

   // Streams
   Stream<List<Region>> watchAllRegions() {
      return (select(regionsTable)..orderBy([(r) => OrderingTerm.asc(r.name)])).watch();
   }

   Stream<Region?> watchRegionById(int id) {
      return (select(regionsTable)..where((r) => r.id.equals(id))).watchSingleOrNull();
   }

   // Futures
   Future<List<Region>> getAllRegions() {
      return (select(regionsTable)..orderBy([(r) => OrderingTerm.asc(r.name)])).get();
   }

   Future<Region?> getRegionById(int id) {
      return (select(regionsTable)..where((r) => r.id.equals(id))).getSingleOrNull();
   }

   // Writes
   Future<int> insertRegion(Insertable<Region> entry) => into(regionsTable).insert(entry);

   Future<void> insertRegions(List<Insertable<Region>> entries) async {
      if (entries.isEmpty) return;
      await batch((b) => b.insertAll(regionsTable, entries));
   }

   Future<int> upsertRegion(Insertable<Region> entry) => into(regionsTable).insertOnConflictUpdate(entry);

   Future<void> upsertRegions(List<Insertable<Region>> entries) async {
      if (entries.isEmpty) return;
      await batch(
        (b) => b.insertAll(
          regionsTable,
          entries,
          mode: InsertMode.insertOrReplace,
        ),
      );
   }

   /// Simple update helper to change the name/postCode of a region by id.
   Future<int> updateRegionFields(int id, {String? name, String? postCode}) {
      final companion = RegionsTableCompanion(
         name: name == null ? const Value.absent() : Value(name),
         postCode: postCode == null ? const Value.absent() : Value(postCode),
      );
      return (update(regionsTable)..where((r) => r.id.equals(id))).write(companion);
   }

   Future<int> deleteRegionById(int id) => (delete(regionsTable)..where((r) => r.id.equals(id))).go();

   // Mapping to domain model
   Future<List<RegionModel>> getAllRegionModels() async {
      final rows = await getAllRegions();
      return rows.map((r) => RegionModel(id: r.id, name: r.name, postCode: r.postCode)).toList();
   }
}
