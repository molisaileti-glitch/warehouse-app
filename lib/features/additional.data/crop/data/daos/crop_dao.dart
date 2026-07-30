import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';

part 'crop_dao.g.dart';

@DriftAccessor(tables: [CropTable])
class CropDao extends DatabaseAccessor<AppDatabase> with _$CropDaoMixin {
  CropDao(super.db);

  Stream<List<Crop>> watchAllCrops() {
    return (select(cropTable)..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<List<Crop>> getAllCrops() {
    return (select(cropTable)..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Stream<List<CropWithGradeCount>> watchAllCropsWithGradeCounts() {
    return customSelect(
      '''
      SELECT
        c.id,
        c.name,
        c.type,
        c.uom,
        c.packaging,
        c.grading,
        c.moisture_content_computation,
        c.max_moisure_content,
        c.packaging_weight,
        COUNT(g.id) AS grade_count
      FROM crop_table c
      LEFT JOIN crop_grades g ON g.crop = c.id
      GROUP BY
        c.id,
        c.name,
        c.type,
        c.uom,
        c.packaging,
        c.grading,
        c.moisture_content_computation,
        c.max_moisure_content,
        c.packaging_weight
      ORDER BY c.name ASC
      ''',
      readsFrom: {cropTable, attachedDatabase.cropGrades},
    ).watch().map((rows) {
      return rows.map((row) {
        final data = row.data;
        final moistureContentComputation =
            data['moisture_content_computation'];
        return CropWithGradeCount(
          crop: Crop(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            type: row.readNullable<String>('type'),
            uom: row.readNullable<String>('uom'),
            packaging: row.readNullable<String>('packaging'),
            grading: row.readNullable<String>('grading'),
            moistureContentComputation:
                moistureContentComputation == true ||
                    moistureContentComputation == 1,
            maxMoisureContent: row.readNullable<double>(
              'max_moisure_content',
            ),
            packagingWeight: row.readNullable<double>('packaging_weight'),
          ),
          gradeCount: row.read<int>('grade_count'),
        );
      }).toList();
    });
  }

  Future<Crop?> getCropById(int id) {
    return (select(cropTable)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertCrops(List<Insertable<Crop>> entries) async {
    if (entries.isEmpty) return;
    for (final entry in entries) {
      await into(cropTable).insertOnConflictUpdate(entry);
    }
  }
}

class CropWithGradeCount {
  final Crop crop;
  final int gradeCount;

  const CropWithGradeCount({
    required this.crop,
    required this.gradeCount,
  });
}
