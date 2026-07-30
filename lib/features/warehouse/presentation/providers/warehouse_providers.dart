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
    syncDao: ref.watch(syncQueueDaoProvider),
    auditDao: ref.watch(auditLogDaoProvider),
    dio: ref.watch(apiClientProvider).dio,
    currentUserId: userId,
  );
});

final allWarehousesProvider = StreamProvider<List<Warehouse>>((ref) {
  return ref.watch(warehouseRepoProvider).watchAll();
});

final warehousesByOwnerProvider =
    StreamProvider.family<List<Warehouse>, String>(
  (ref, ownerId) => ref.watch(warehouseRepoProvider).watchByOwner(ownerId),
);

final warehouseByIdProvider = StreamProvider.family<Warehouse?, String>(
  (ref, id) => ref.watch(warehouseRepoProvider).watchById(id),
);
