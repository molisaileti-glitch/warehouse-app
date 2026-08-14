import 'package:warehouse_app/core/database/app_database.dart';

abstract class WarehouseRepository {
  Stream<List<Warehouse>> watchAll();
  Stream<List<Warehouse>> watchByOwner(String ownerId);
  Stream<Warehouse?> watchById(String id);

  Future<Warehouse> createWarehouse({
    required String name,
    String? gpsLocation,
    int? amcos,
    String? amcosName,
    int? village,
    String? villageName,
  });

  Future<void> updateWarehouse({
    required String id,
    String? name,
    String? gpsLocation,
    int? amcos,
    String? amcosName,
    int? village,
    String? villageName,
  });

  Future<void> deleteWarehouse(String id);
  Future<int> pullFromServer({required int mcuId});
  Future<void> upsertDownstream(Map<String, dynamic> json);
}
