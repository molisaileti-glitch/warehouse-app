import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../network/api_client.dart';
import '../providers/auth_provider.dart';
import '../repositories/inventory_repository.dart';

export 'package:warehouse_app/features/warehouse/presentation/providers/warehouse_providers.dart';
export 'package:warehouse_app/features/worker/presentation/providers/worker_providers.dart';
export 'package:warehouse_app/features/farmer/presentation/providers/farmer_providers.dart';
export 'package:warehouse_app/features/additional.data/crop/presentation/providers/crop_providers.dart';
export 'package:warehouse_app/features/harvest/presentation/providers/harvest_providers.dart';

final inventoryRepoProvider = Provider<InventoryRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Not authenticated');
  return InventoryRepository(
    dao: ref.watch(inventoryDaoProvider),
    syncDao: ref.watch(syncQueueDaoProvider),
    auditDao: ref.watch(auditLogDaoProvider),
    dio: ref.watch(apiClientProvider).dio,
    currentUserId: userId,
  );
});

final inventoryItemsProvider =
    StreamProvider.family<List<InventoryItem>, String>(
  (ref, warehouseId) => ref.watch(inventoryRepoProvider).watchItems(warehouseId),
);

final lowStockProvider = StreamProvider.family<List<InventoryItem>, String>(
  (ref, warehouseId) => ref.watch(inventoryRepoProvider).watchLowStock(warehouseId),
);

final stockMovementsProvider =
    StreamProvider.family<List<StockMovement>, String>(
  (ref, itemId) => ref.watch(inventoryRepoProvider).watchMovements(itemId),
);

final syncPendingCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncQueueDaoProvider).watchPendingCount();
});
