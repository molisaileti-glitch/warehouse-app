import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/worker/domain/models/worker_model.dart';

abstract class WorkerRepository {
  Stream<List<User>> watchAllWorkers();
  Stream<List<User>> watchWorkersByWarehouse(String warehouseId);
  Stream<User?> watchWorkerById(String id);
  Future<int> pullFromServer({required int mcuId});

  Future<WorkerCreateResult> createWorker(WorkerModel worker);
  Future<void> updateWorker({
    required String id,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String? warehouseId,
    required int? mcu,
    required int? amcos,
    required bool isActive,
  });
  Future<void> deleteWorker(String id);
}

class WorkerCreateResult {
  final bool success;
  final String? error;
  final String? message;
  final String? email;
  final String? status;

  const WorkerCreateResult._({
    required this.success,
    this.error,
    this.message,
    this.email,
    this.status,
  });

  factory WorkerCreateResult.success({
    required String message,
    required String email,
    required String status,
  }) {
    return WorkerCreateResult._(
      success: true,
      message: message,
      email: email,
      status: status,
    );
  }

  factory WorkerCreateResult.failure(String error) {
    return WorkerCreateResult._(success: false, error: error);
  }
}
