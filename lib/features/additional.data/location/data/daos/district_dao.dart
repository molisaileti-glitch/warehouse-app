// lib/features/additional.data/location/data/daos/district_dao.dart
//
// DistrictDao — all local DB operations for the DistrictsTable.
// Districts belong to a Region via the `region` FK column.

import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';
import 'package:warehouse_app/features/additional.data/location/domain/models/district_model.dart';

part 'district_dao.g.dart';

@DriftAccessor(tables: [DistrictsTable])
class DistrictDao extends DatabaseAccessor<AppDatabase>
    with _$DistrictDaoMixin {
  DistrictDao(super.db);

  // ── Streams ──────────────────────────────────────────────────────────────

  /// All districts ordered by name.
  Stream<List<District>> watchAllDistricts() {
    return (select(districtsTable)
          ..orderBy([(d) => OrderingTerm.asc(d.name)]))
        .watch();
  }

  /// Districts belonging to a specific region.
  Stream<List<District>> watchDistrictsByRegion(int regionId) {
    return (select(districtsTable)
          ..where((d) => d.region.equals(regionId))
          ..orderBy([(d) => OrderingTerm.asc(d.name)]))
        .watch();
  }

  /// Single district by id.
  Stream<District?> watchDistrictById(int id) {
    return (select(districtsTable)..where((d) => d.id.equals(id)))
        .watchSingleOrNull();
  }

  // ── Futures ──────────────────────────────────────────────────────────────

  Future<List<District>> getAllDistricts() {
    return (select(districtsTable)
          ..orderBy([(d) => OrderingTerm.asc(d.name)]))
        .get();
  }

  Future<List<District>> getDistrictsByRegion(int regionId) {
    return (select(districtsTable)
          ..where((d) => d.region.equals(regionId))
          ..orderBy([(d) => OrderingTerm.asc(d.name)]))
        .get();
  }

  Future<District?> getDistrictById(int id) {
    return (select(districtsTable)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  Future<int> insertDistrict(Insertable<District> entry) =>
      into(districtsTable).insert(entry);

  /// Batch-insert a list of districts — used when seeding from the server.
  Future<void> insertDistricts(List<Insertable<District>> entries) async {
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(districtsTable, entries));
  }

  /// Insert or replace on PK conflict.
  Future<int> upsertDistrict(Insertable<District> entry) =>
      into(districtsTable).insertOnConflictUpdate(entry);

  /// Batch upsert — efficient for full-sync payloads.
  Future<void> upsertDistricts(List<Insertable<District>> entries) async {
    if (entries.isEmpty) return;
    await batch(
      (b) => b.insertAll(
        districtsTable,
        entries,
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  /// Update name / regionName fields by id.
  Future<int> updateDistrictFields(
    int id, {
    String? name,
    String? regionName,
  }) {
    final companion = DistrictsTableCompanion(
      name: name == null ? const Value.absent() : Value(name),
      regionName:
          regionName == null ? const Value.absent() : Value(regionName),
    );
    return (update(districtsTable)..where((d) => d.id.equals(id)))
        .write(companion);
  }

  Future<int> deleteDistrictById(int id) =>
      (delete(districtsTable)..where((d) => d.id.equals(id))).go();

  // ── Domain-model mapping ─────────────────────────────────────────────────

  Future<List<DistrictModel>> getAllDistrictModels() async {
    final rows = await getAllDistricts();
    return rows
        .map(
          (d) => DistrictModel(
            id: d.id,
            name: d.name,
            region: d.region,
            regionName: d.regionName,
          ),
        )
        .toList();
  }

  Future<List<DistrictModel>> getDistrictModelsByRegion(int regionId) async {
    final rows = await getDistrictsByRegion(regionId);
    return rows
        .map(
          (d) => DistrictModel(
            id: d.id,
            name: d.name,
            region: d.region,
            regionName: d.regionName,
          ),
        )
        .toList();
  }
}
