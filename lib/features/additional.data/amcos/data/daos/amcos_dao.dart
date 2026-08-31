import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/amcos/domain/model/amcos_model.dart';
import 'package:warehouse_app/features/additional.data/location/data/tables/locations_tables.dart';

part 'amcos_dao.g.dart';

@DriftAccessor(
  tables: [
    AmcosTable,
    RegionsTable,
    DistrictsTable,
    WardsTable,
    VillagesTable,
    SyncQueue,
  ],
)
class AmcosDao extends DatabaseAccessor<AppDatabase> with _$AmcosDaoMixin {
  AmcosDao(super.db);

  Stream<List<Amcos>> watchAllAmcos() {
    return (select(amcosTable)..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  Stream<Amcos?> watchAmcosById(int id) {
    return (select(amcosTable)..where((a) => a.id.equals(id)))
        .watchSingleOrNull();
  }

  Stream<List<Amcos>> watchAmcosByStatus(String status) {
    return (select(amcosTable)
          ..where((a) => a.status.equals(status))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  Stream<List<Amcos>> watchAmcosByMcu(int mcuId) {
    return (select(amcosTable)
          ..where((a) => a.mcu.equals(mcuId))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  Future<List<Amcos>> getAllAmcos() {
    return (select(amcosTable)..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .get();
  }

  Future<Amcos?> getAmcosById(int id) {
    return (select(amcosTable)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Amcos>> getAmcosByStatus(String status) {
    return (select(amcosTable)
          ..where((a) => a.status.equals(status))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .get();
  }

  Future<List<Amcos>> getAmcosByMcu(int mcuId) {
    return (select(amcosTable)
          ..where((a) => a.mcu.equals(mcuId))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .get();
  }

  Future<int> insertAmcos(Insertable<Amcos> entry) =>
      into(amcosTable).insert(entry);

  Future<void> insertAmcosList(List<Insertable<Amcos>> entries) async {
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(amcosTable, entries));
  }

  Future<int> upsertAmcos(Insertable<Amcos> entry) =>
      into(amcosTable).insertOnConflictUpdate(entry);

  // ── UUID-based lookups ───────────────────────────────────────────────────

  /// Find a locally-created (pending) AMCOS by its UUID.
  /// Used by the sync engine to resolve the server ID after a successful push.
  Future<Amcos?> getAmcosByUuid(String uuid) {
    return (select(amcosTable)..where((a) => a.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  /// Find a locally-stored AMCOS by the server ID that was written after push.
  Future<Amcos?> getAmcosByServerId(int serverId) {
    return (select(amcosTable)..where((a) => a.serverId.equals(serverId)))
        .getSingleOrNull();
  }

  // ── Offline-first write helpers ──────────────────────────────────────────

  /// Atomically insert a pending AMCOS row and its sync-queue entry.
  Future<void> insertPendingAmcos({
    required AmcosTableCompanion amcos,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await into(amcosTable).insert(amcos);
      await into(syncQueue).insert(queueEntry);
    });
  }

  /// Record the server-assigned integer ID on an AMCOS that was created offline
  /// and has just been pushed successfully. Flips syncStatus to 'synced'.
  Future<void> markAmcosSynced(String uuid, {required int serverId}) {
    return (update(amcosTable)..where((a) => a.uuid.equals(uuid))).write(
      AmcosTableCompanion(
        serverId: Value(serverId),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<void> ensureAmcosReferences({
    required int regionId,
    required String regionName,
    required int districtId,
    required String districtName,
    required int wardId,
    required String wardName,
    required int villageId,
    required String villageName,
  }) {
    return transaction(() async {
      final safeRegionName = _nonEmpty(regionName) ?? 'Unknown';
      final safeDistrictName = _nonEmpty(districtName) ?? safeRegionName;
      final safeWardName = _nonEmpty(wardName) ?? safeDistrictName;
      final safeVillageName = _nonEmpty(villageName) ?? safeWardName;

      await into(regionsTable).insert(
        RegionsTableCompanion(
          id: Value(regionId),
          name: Value(safeRegionName),
          postCode: const Value(''),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await into(districtsTable).insert(
        DistrictsTableCompanion(
          id: Value(districtId),
          name: Value(safeDistrictName),
          region: Value(regionId),
          regionName: Value(safeRegionName),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await into(wardsTable).insert(
        WardsTableCompanion(
          id: Value(wardId),
          name: Value(safeWardName),
          district: Value(districtId),
          districtName: Value(safeDistrictName),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await into(villagesTable).insert(
        VillagesTableCompanion(
          id: Value(villageId),
          name: Value(safeVillageName),
          ward: Value(wardId),
          wardName: Value(safeWardName),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> upsertAmcosList(List<Insertable<Amcos>> entries) async {
    if (entries.isEmpty) return;
    await batch(
      (b) => b.insertAll(
        amcosTable,
        entries,
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  Future<int> updateAmcosFields(
    int id, {
    String? name,
    String? status,
    String? phoneNumber,
    String? email,
  }) {
    final companion = AmcosTableCompanion(
      name: name == null ? const Value.absent() : Value(name),
      status: status == null ? const Value.absent() : Value(status),
      phoneNumber:
          phoneNumber == null ? const Value.absent() : Value(phoneNumber),
      email: email == null ? const Value.absent() : Value(email),
    );
    return (update(amcosTable)..where((a) => a.id.equals(id))).write(companion);
  }

  Future<int> deleteAmcosById(int id) =>
      (delete(amcosTable)..where((a) => a.id.equals(id))).go();

  Future<List<AmcosModel>> getAllAmcosModels() async {
    final rows = await getAllAmcos();
    return rows
        .map((amcos) => AmcosModel(
              id: amcos.id,
              name: amcos.name,
              memberCategory: amcos.memberCategory,
              registrationNumber: amcos.registrationNumber,
              tinNumber: amcos.tinNumber,
              mcu: amcos.mcu,
              mcuName: amcos.mcuName,
              region: amcos.region,
              regionName: amcos.regionName,
              district: amcos.district,
              districtName: amcos.districtName,
              ward: amcos.ward,
              wardName: amcos.wardName,
              village: amcos.village,
              villageName: amcos.villageName,
              phoneNumber: amcos.phoneNumber,
              email: amcos.email,
              contactPersonName: amcos.contactPersonName,
              contactPersonPhoneNumber: amcos.contactPersonPhoneNumber,
              contactPersonEmail: amcos.contactPersonEmail,
              contactPersonTitle: amcos.contactPersonTitle,
              website: amcos.website,
              status: amcos.status,
              crops: amcos.crops,
              idCounter: amcos.idCounter,
            ))
        .toList();
  }

  String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
