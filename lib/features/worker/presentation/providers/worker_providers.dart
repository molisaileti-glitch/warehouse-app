import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/features/worker/data/repositories/drift_worker_repository.dart';
import 'package:warehouse_app/features/worker/domain/repositories/worker_repository.dart';

final workerRepoProvider = Provider<WorkerRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Not authenticated');

  return DriftWorkerRepository(
    dao: ref.watch(workerDaoProvider),
    auditDao: ref.watch(auditLogDaoProvider),
    dio: ref.watch(apiClientProvider).dio,
    currentUserId: userId,
  );
});

final allWorkersProvider = StreamProvider<List<User>>((ref) {
  final mcuId = ref.watch(currentUserMcuProvider).valueOrNull;
  if (mcuId == null) return const Stream.empty();
  return ref.watch(workerDaoProvider).watchUsersByMcu(mcuId).map(
        (users) => users.where((u) => _isWorkerRole(u.role)).toList(),
      );
});

final workersByWarehouseProvider =
    StreamProvider.family<List<User>, String>((ref, warehouseId) {
  return ref.watch(workerRepoProvider).watchWorkersByWarehouse(warehouseId);
});

final workerByIdProvider = StreamProvider.family<User?, String>((ref, id) {
  return ref.watch(workerRepoProvider).watchWorkerById(id);
});

bool _isWorkerRole(String role) {
  final normalized = role.trim().toLowerCase().replaceAll(' ', '_');
  return normalized == 'worker' ||
      normalized == 'amcos_user' ||
      normalized == 'user';
}
