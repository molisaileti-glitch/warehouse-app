import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';

part 'harvest_dao.g.dart';

@DriftAccessor(
  tables: [
    FarmerHarvests,
    FarmerHarvestBags,
    MeasurementUnits,
    CropGrades,
    SyncQueue,
  ],
)
class HarvestDao extends DatabaseAccessor<AppDatabase> with _$HarvestDaoMixin {
  HarvestDao(super.db);

  Stream<List<FarmerHarvest>> watchRecentHarvests(String warehouseId) {
    return (select(farmerHarvests)
          ..where((h) => h.warehouseId.equals(warehouseId))
          ..orderBy([(h) => OrderingTerm.desc(h.receivedAt)]))
        .watch();
  }

  Stream<List<FarmerHarvest>> watchAllHarvests() {
    return (select(farmerHarvests)
          ..orderBy([(h) => OrderingTerm.desc(h.receivedAt)]))
        .watch();
  }

  Stream<List<MeasurementUnit>> watchMeasurementUnits(){
    return (select(measurementUnits)
          ..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .watch();
  }

  Stream<List<CropGrade>> watchCropGradesForCrop(int cropId) {
    return (select(cropGrades)
          ..where((g) => g.crop.equals(cropId))
          ..orderBy([(g) => OrderingTerm.asc(g.gradeName)]))
        .watch();
  }

  Future<FarmerHarvest?> getHarvestByUuid(String uuid) {
    return (select(farmerHarvests)..where((h) => h.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<List<FarmerHarvestBag>> getBagsForHarvest(String harvestUuid) {
    return (select(farmerHarvestBags)
          ..where((b) => b.harvestUuid.equals(harvestUuid)))
        .get();
  }

  Future<void> insertHarvestWithBags({
    required FarmerHarvestsCompanion harvest,
    required List<FarmerHarvestBagsCompanion> bags,
  }) {
    return transaction(() async {
      await into(farmerHarvests).insertOnConflictUpdate(harvest);
      if (bags.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            farmerHarvestBags,
            bags,
            mode: InsertMode.insertOrReplace,
          );
        });
      }
    });
  }

  Future<void> insertPendingHarvestWithBags({
    required FarmerHarvestsCompanion harvest,
    required List<FarmerHarvestBagsCompanion> bags,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await into(farmerHarvests).insert(harvest);
      if (bags.isNotEmpty) {
        await batch((batch) => batch.insertAll(farmerHarvestBags, bags));
      }
      await into(syncQueue).insert(queueEntry);
    });
  }

  Future<void> markHarvestSynced(String uuid, {int? serverId}) {
    return (update(farmerHarvests)..where((h) => h.uuid.equals(uuid))).write(
      FarmerHarvestsCompanion(
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markHarvestConflict(String uuid) {
    return (update(farmerHarvests)..where((h) => h.uuid.equals(uuid))).write(
      FarmerHarvestsCompanion(
        syncStatus: const Value('conflict'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertMeasurementUnits(
    List<MeasurementUnitsCompanion> entries,
  ) async {
    for (final entry in entries) {
      await into(measurementUnits).insertOnConflictUpdate(entry);
    }
  }

  Future<void> upsertCropGrades(List<CropGradesCompanion> entries) async {
    for (final entry in entries) {
      await into(cropGrades).insertOnConflictUpdate(entry);

    }
    
  }
}
