import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/features/warehouse_operations/data/repositories/drift_warehouse_operations_repository.dart';
import 'package:warehouse_app/features/warehouse_operations/domain/repositories/warehouse_operations_repository.dart';

final warehouseOperationsRepoProvider =
    Provider<WarehouseOperationsRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Not authenticated');

  return DriftWarehouseOperationsRepository(
    dao: ref.watch(warehouseOperationsDaoProvider),
    warehouseDao: ref.watch(warehouseDaoProvider),
    auditDao: ref.watch(auditLogDaoProvider),
    dio: ref.watch(apiClientProvider).dio,
    currentUserId: userId,
  );
});

final warehouseInventoryProvider =
    StreamProvider.family<List<WarehouseInventory>, String>(
  (ref, warehouseId) =>
      ref.watch(warehouseOperationsRepoProvider).watchInventory(warehouseId),
);

final warehouseDispatchesProvider =
    StreamProvider.family<List<WarehouseDispatch>, String>(
  (ref, warehouseId) =>
      ref.watch(warehouseOperationsRepoProvider).watchDispatches(warehouseId),
);

final warehouseStockCountsProvider =
    StreamProvider.family<List<WarehouseStockCount>, String>(
  (ref, warehouseId) =>
      ref.watch(warehouseOperationsRepoProvider).watchStockCounts(warehouseId),
);

final warehouseStockAdjustmentsProvider =
    StreamProvider.family<List<WarehouseStockAdjustment>, String>(
  (ref, warehouseId) => ref
      .watch(warehouseOperationsRepoProvider)
      .watchStockAdjustments(warehouseId),
);
