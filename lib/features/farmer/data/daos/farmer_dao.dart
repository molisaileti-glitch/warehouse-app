import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';

part 'farmer_dao.g.dart';

@DriftAccessor(tables: [Farmers, FarmerDependants, SyncQueue])
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
    return (select(farmers)..where((f) => f.id.equals(id))).watchSingleOrNull();
  }

  Future<Farmer?> getFarmerById(int id) {
    return (select(farmers)..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  Future<Farmer?> getFarmerByServerId(int serverId) {
    return (select(farmers)..where((f) => f.serverId.equals(serverId)))
        .getSingleOrNull();
  }

  Future<Farmer?> getFarmerByUuid(String uuid) {
    return (select(farmers)..where((f) => f.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<void> upsertFarmer(Insertable<Farmer> entry) {
    return into(farmers).insertOnConflictUpdate(entry);
  }

  Future<void> insertPendingFarmer({
    required FarmersCompanion farmer,
    required List<FarmerDependantsCompanion> dependants,
    required List<SyncQueueCompanion> queueEntries,
  }) {
    return transaction(() async {
      await into(farmers).insert(farmer);
      if (dependants.isNotEmpty) {
        await batch((b) => b.insertAll(farmerDependants, dependants));
      }
      await batch((b) => b.insertAll(syncQueue, queueEntries));
    });
  }

  Future<void> insertPendingDependant({
    required FarmerDependantsCompanion dependant,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await into(farmerDependants).insert(dependant);
      await into(syncQueue).insert(queueEntry);
    });
  }

  Stream<List<FarmerDependant>> watchDependantsForFarmer(int farmerId) {
    return (select(farmerDependants)
          ..where(
            (d) =>
                d.farmerId.equals(farmerId) & d.relationship.equals('').not(),
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
            (d) =>
                d.farmerId.equals(farmerId) & d.relationship.equals('').not(),
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
          ..where(
              (d) => d.farmerId.equals(farmerId) & d.relationship.equals('')))
        .go();
  }

  Future<void> upsertDependants(
      List<Insertable<FarmerDependant>> entries) async {
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
