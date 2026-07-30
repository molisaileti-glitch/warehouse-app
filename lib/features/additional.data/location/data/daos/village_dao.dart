// lib/features/additional.data/location/data/daos/village_dao.dart
//
// VillageDao — all local DB operations for the VillagesTable.
// Villages belong to a Ward via the `ward` FK column.

import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';
import 'package:warehouse_app/features/additional.data/location/domain/models/village_model.dart';

part 'village_dao.g.dart';

@DriftAccessor(tables: [VillagesTable])
class VillageDao extends DatabaseAccessor<AppDatabase>
    with _$VillageDaoMixin {
  VillageDao(super.db);

  // ── Streams ──────────────────────────────────────────────────────────────

  /// All villages ordered by name.
  Stream<List<Village>> watchAllVillages() {
    return (select(villagesTable)..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .watch();
  }

  /// Villages belonging to a specific ward.
  Stream<List<Village>> watchVillagesByWard(int wardId) {
    return (select(villagesTable)
          ..where((v) => v.ward.equals(wardId))
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .watch();
  }

  /// Single village by id.
  Stream<Village?> watchVillageById(int id) {
    return (select(villagesTable)..where((v) => v.id.equals(id)))
        .watchSingleOrNull();
  }

  // ── Futures ──────────────────────────────────────────────────────────────

  Future<List<Village>> getAllVillages() {
    return (select(villagesTable)..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .get();
  }

  Future<List<Village>> getVillagesByWard(int wardId) {
    return (select(villagesTable)
          ..where((v) => v.ward.equals(wardId))
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .get();
  }

  Future<Village?> getVillageById(int id) {
    return (select(villagesTable)..where((v) => v.id.equals(id)))
        .getSingleOrNull();
  }

  /// Search villages by name (case-insensitive substring).
  Future<List<Village>> searchVillages(String query) {
    return (select(villagesTable)
          ..where((v) => v.name.like('%$query%'))
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .get();
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  Future<int> insertVillage(Insertable<Village> entry) =>
      into(villagesTable).insert(entry);

  /// Batch-insert a list of villages — used when seeding from the server.
  Future<void> insertVillages(List<Insertable<Village>> entries) async {
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(villagesTable, entries));
  }

  /// Insert or replace on PK conflict.
  Future<int> upsertVillage(Insertable<Village> entry) =>
      into(villagesTable).insertOnConflictUpdate(entry);

  /// Batch upsert — efficient for full-sync payloads.
  Future<void> upsertVillages(List<Insertable<Village>> entries) async {
    if (entries.isEmpty) return;
    await batch(
      (b) => b.insertAll(
        villagesTable,
        entries,
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  /// Update name / wardName fields by id.
  Future<int> updateVillageFields(
    int id, {
    String? name,
    String? wardName,
  }) {
    final companion = VillagesTableCompanion(
      name: name == null ? const Value.absent() : Value(name),
      wardName: wardName == null ? const Value.absent() : Value(wardName),
    );
    return (update(villagesTable)..where((v) => v.id.equals(id)))
        .write(companion);
  }

  Future<int> deleteVillageById(int id) =>
      (delete(villagesTable)..where((v) => v.id.equals(id))).go();

  // ── Domain-model mapping ─────────────────────────────────────────────────

  Future<List<VillageModel>> getAllVillageModels() async {
    final rows = await getAllVillages();
    return rows
        .map(
          (v) => VillageModel(
            id: v.id,
            name: v.name,
            ward: v.ward,
            wardName: v.wardName,
          ),
        )
        .toList();
  }

  Future<List<VillageModel>> getVillageModelsByWard(int wardId) async {
    final rows = await getVillagesByWard(wardId);
    return rows
        .map(
          (v) => VillageModel(
            id: v.id,
            name: v.name,
            ward: v.ward,
            wardName: v.wardName,
          ),
        )
        .toList();
  }
}
