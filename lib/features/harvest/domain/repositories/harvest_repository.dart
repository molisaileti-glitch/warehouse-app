import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/harvest/domain/models/harvest_model.dart';

abstract class HarvestRepository {
  Stream<List<FarmerHarvest>> watchRecentHarvests(String warehouseId);
  Stream<List<MeasurementUnit>> watchMeasurementUnits();
  Stream<List<CropGrade>> watchCropGradesForCrop(int cropId);

  Future<HarvestCreateResult> recordHarvest(HarvestCreateInput input);
  Future<int> pullReferenceData();
}
