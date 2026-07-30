import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/amcos/domain/model/amcos_model.dart';

part 'amcos_dao.g.dart';

@DriftAccessor(tables: [AmcosTable])
class AmcosDao extends DatabaseAccessor<AppDatabase> with _$AmcosDaoMixin {
  AmcosDao(super.db);

  Stream<List<Amcos>> watchAllAmcos() {
    return (select(amcosTable)
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
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

  Future<List<Amcos>> getAllAmcos() {
    return (select(amcosTable)
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
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

  Future<int> insertAmcos(Insertable<Amcos> entry) =>
      into(amcosTable).insert(entry);

  Future<void> insertAmcosList(List<Insertable<Amcos>> entries) async {
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(amcosTable, entries));
  }

  Future<int> upsertAmcos(Insertable<Amcos> entry) =>
      into(amcosTable).insertOnConflictUpdate(entry);

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
      phoneNumber: phoneNumber == null ? const Value.absent() : Value(phoneNumber),
      email: email == null ? const Value.absent() : Value(email),
    );
    return (update(amcosTable)..where((a) => a.id.equals(id))).write(companion);
  }

  Future<int> deleteAmcosById(int id) =>
      (delete(amcosTable)..where((a) => a.id.equals(id))).go();

  Future<List<AmcosModel>> getAllAmcosModels() async {
    final rows = await getAllAmcos();
    return rows.map((amcos) => AmcosModel(
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
    )).toList();
  }
}
