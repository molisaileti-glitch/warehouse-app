import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/features/warehouse/data/repositories/drift_warehouse_repository.dart';
import 'package:warehouse_app/features/warehouse/domain/repositories/warehouse_repository.dart';

final warehouseRepoProvider = Provider<WarehouseRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Not authenticated');

  return DriftWarehouseRepository(
    dao: ref.watch(warehouseDaoProvider),
    auditDao: ref.watch(auditLogDaoProvider),
    dio: ref.watch(apiClientProvider).dio,
    currentUserId: userId,
    currentMcuId: () => ref.read(secureStorageProvider).getMcuId(),
  );
});

final allWarehousesProvider = StreamProvider<List<Warehouse>>((ref) {
  return ref.watch(warehouseRepoProvider).watchAll();
});

final warehousesByOwnerProvider =
    StreamProvider.family<List<Warehouse>, String>(
  (ref, ownerId) => ref.watch(warehouseRepoProvider).watchByOwner(ownerId),
);

final currentOwnerWarehousesProvider = StreamProvider<List<Warehouse>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final mcuId = ref.watch(currentUserMcuProvider).valueOrNull;
  if (userId == null || mcuId == null) {
    return Stream.value(const <Warehouse>[]);
  }

  return ref.watch(warehouseRepoProvider).watchAll().map(
        (warehouses) => warehouses
            .where(
              (warehouse) =>
                  warehouse.ownerId == mcuId.toString() ||
                  warehouse.ownerId == userId,
            )
            .toList(),
      );
});

final warehousesByAmcosProvider =
    StreamProvider.family<List<Warehouse>, int>((ref, amcosId) {
  return ref.watch(warehouseRepoProvider).watchByAmcos(amcosId);
});

final warehouseByIdProvider = StreamProvider.family<Warehouse?, String>(
  (ref, id) => ref.watch(warehouseRepoProvider).watchById(id),
);
