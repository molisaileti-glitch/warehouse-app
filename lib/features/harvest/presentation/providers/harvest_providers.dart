import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/features/harvest/data/repositories/drift_harvest_repository.dart';
import 'package:warehouse_app/features/harvest/domain/repositories/harvest_repository.dart';

final harvestRepositoryProvider = Provider<HarvestRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Not authenticated');

  return DriftHarvestRepository(
    dao: ref.watch(harvestDaoProvider),
    farmerDao: ref.watch(farmerDaoProvider),
    warehouseDao: ref.watch(warehouseDaoProvider),
    cropDao: ref.watch(cropDaoProvider),
    auditDao: ref.watch(auditLogDaoProvider),
    dio: ref.watch(apiClientProvider).dio,
    currentUserId: userId,
  );
});

final harvestsByWarehouseProvider =
    StreamProvider.family<List<FarmerHarvest>, String>((ref, warehouseId) {
  return ref.watch(harvestRepositoryProvider).watchRecentHarvests(warehouseId);
});

final measurementUnitsProvider = StreamProvider<List<MeasurementUnit>>((ref) {
  return ref.watch(harvestRepositoryProvider).watchMeasurementUnits();
});

final cropGradesForCropProvider =
    StreamProvider.family<List<CropGrade>, int>((ref, cropId) {
  return ref.watch(harvestRepositoryProvider).watchCropGradesForCrop(cropId);
});
