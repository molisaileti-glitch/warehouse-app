import 'package:warehouse_app/core/database/app_database.dart';

abstract class WarehouseOperationsRepository {
  Stream<List<WarehouseInventory>> watchInventory(String warehouseId);
  Stream<List<WarehouseDispatch>> watchDispatches(String warehouseId);
  Stream<List<WarehouseStockCount>> watchStockCounts(String warehouseId);
  Stream<List<WarehouseStockAdjustment>> watchStockAdjustments(
    String warehouseId,
  );

  Future<void> recordDispatch({
    required Warehouse warehouse,
    required Crop crop,
    required String recipientType,
    required String recipientName,
    String? recipientPhone,
    required int totalBags,
    required double totalGrossWeight,
    required double totalPackagingWeight,
    required double totalNetWeight,
    double moistureContent,
    DateTime? dispatchedAt,
  });

  Future<void> recordStockCount({
    required Warehouse warehouse,
    required Crop crop,
    required int countedBags,
    required double countedGrossWeight,
    required double countedPackagingWeight,
    required double countedNetWeight,
    double moistureContent,
    DateTime? countedAt,
  });

  Future<void> recordStockAdjustment({
    required Warehouse warehouse,
    required Crop crop,
    required String adjustmentType,
    required String reason,
    required int bags,
    required double grossWeight,
    required double packagingWeight,
    required double netWeight,
    double moistureContent,
    DateTime? adjustedAt,
  });

  Future<int> pullForMcu(int mcuId);

  Future<int> pullForCollectionCenter({
    required Warehouse warehouse,
  });

  Future<void> markDispatchSynced(String uuid);
  Future<void> markDispatchConflict(String uuid);
  Future<void> markStockCountSynced(String uuid);
  Future<void> markStockCountConflict(String uuid);
  Future<void> markStockAdjustmentSynced(String uuid);
  Future<void> markStockAdjustmentConflict(String uuid);
}
