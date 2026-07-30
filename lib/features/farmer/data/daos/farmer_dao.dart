import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';

part 'farmer_dao.g.dart';

@DriftAccessor(tables: [Farmers, FarmerDependants])
class FarmerDao extends DatabaseAccessor<AppDatabase> with _$FarmerDaoMixin {
  FarmerDao(super.db);

  Stream<List<Farmer>> watchAllFarmers() {
    return (select(farmers)
          ..orderBy([
            (f) => OrderingTerm.asc(f.lastName),
            (f) => OrderingTerm.asc(f.firstName),
          ]))
        .watch();
  }

  Stream<Farmer?> watchFarmerById(int id) {
    return (select(farmers)..where((f) => f.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Farmer?> getFarmerById(int id) {
    return (select(farmers)..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertFarmer(Insertable<Farmer> entry) {
    return into(farmers).insertOnConflictUpdate(entry);
  }

  Stream<List<FarmerDependant>> watchDependantsForFarmer(int farmerId) {
    return (select(farmerDependants)
          ..where(
            (d) => d.farmerId.equals(farmerId) & d.relationship.equals('').not(),
          )
          ..orderBy([
            (d) => OrderingTerm.asc(d.lastName),
            (d) => OrderingTerm.asc(d.firstName),
          ]))
        .watch();
  }

  Future<List<FarmerDependant>> getDependantsForFarmer(int farmerId) {
    return (select(farmerDependants)
          ..where(
            (d) => d.farmerId.equals(farmerId) & d.relationship.equals('').not(),
          )
          ..orderBy([
            (d) => OrderingTerm.asc(d.lastName),
            (d) => OrderingTerm.asc(d.firstName),
          ]))
        .get();
  }

  Future<void> upsertDependant(Insertable<FarmerDependant> entry) {
    return into(farmerDependants).insertOnConflictUpdate(entry);
  }

  Future<void> deleteInvalidDependantsForFarmer(int farmerId) {
    return (delete(farmerDependants)
          ..where((d) => d.farmerId.equals(farmerId) & d.relationship.equals('')))
        .go();
  }

  Future<void> upsertDependants(List<Insertable<FarmerDependant>> entries) async {
    if (entries.isEmpty) return;
    await batch(
      (b) => b.insertAll(
        farmerDependants,
        entries,
        mode: InsertMode.insertOrReplace,
      ),
    );
  }
}
