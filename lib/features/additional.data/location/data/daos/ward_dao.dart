// lib/features/additional.data/location/data/daos/ward_dao.dart
//
// WardDao — all local DB operations for the WardsTable.
// Wards belong to a District via the `district` FK column.

import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';
import 'package:warehouse_app/features/additional.data/location/domain/models/ward_model.dart';

part 'ward_dao.g.dart';

@DriftAccessor(tables: [WardsTable])
class WardDao extends DatabaseAccessor<AppDatabase> with _$WardDaoMixin {
  WardDao(super.db);

  // ── Streams ──────────────────────────────────────────────────────────────

  /// All wards ordered by name.
  Stream<List<Ward>> watchAllWards() {
    return (select(wardsTable)..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  /// Wards belonging to a specific district.
  Stream<List<Ward>> watchWardsByDistrict(int districtId) {
    return (select(wardsTable)
          ..where((w) => w.district.equals(districtId))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  /// Single ward by id.
  Stream<Ward?> watchWardById(int id) {
    return (select(wardsTable)..where((w) => w.id.equals(id)))
        .watchSingleOrNull();
  }

  // ── Futures ──────────────────────────────────────────────────────────────

  Future<List<Ward>> getAllWards() {
    return (select(wardsTable)..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();
  }

  Future<List<Ward>> getWardsByDistrict(int districtId) {
    return (select(wardsTable)
          ..where((w) => w.district.equals(districtId))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();
  }

  Future<Ward?> getWardById(int id) {
    return (select(wardsTable)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  Future<int> insertWard(Insertable<Ward> entry) =>
      into(wardsTable).insert(entry);

  /// Batch-insert a list of wards — used when seeding from the server.
  Future<void> insertWards(List<Insertable<Ward>> entries) async {
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(wardsTable, entries));
  }

  /// Insert or replace on PK conflict.
  Future<int> upsertWard(Insertable<Ward> entry) =>
      into(wardsTable).insertOnConflictUpdate(entry);

  /// Batch upsert — efficient for full-sync payloads.
  Future<void> upsertWards(List<Insertable<Ward>> entries) async {
    if (entries.isEmpty) return;
    await batch(
      (b) => b.insertAll(
        wardsTable,
        entries,
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  /// Update name / districtName fields by id.
  Future<int> updateWardFields(
    int id, {
    String? name,
    String? districtName,
  }) {
    final companion = WardsTableCompanion(
      name: name == null ? const Value.absent() : Value(name),
      districtName:
          districtName == null ? const Value.absent() : Value(districtName),
    );
    return (update(wardsTable)..where((w) => w.id.equals(id))).write(companion);
  }

  Future<int> deleteWardById(int id) =>
      (delete(wardsTable)..where((w) => w.id.equals(id))).go();

  // ── Domain-model mapping ─────────────────────────────────────────────────

  Future<List<WardModel>> getAllWardModels() async {
    final rows = await getAllWards();
    return rows
        .map(
          (w) => WardModel(
            id: w.id,
            name: w.name,
            district: w.district,
            districtName: w.districtName,
          ),
        )
        .toList();
  }

  Future<List<WardModel>> getWardModelsByDistrict(int districtId) async {
    final rows = await getWardsByDistrict(districtId);
    return rows
        .map(
          (w) => WardModel(
            id: w.id,
            name: w.name,
            district: w.district,
            districtName: w.districtName,
          ),
        )
        .toList();
  }
}
