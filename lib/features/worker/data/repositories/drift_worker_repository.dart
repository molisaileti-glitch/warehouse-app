import 'dart:convert';

import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/utils/uuid_helper.dart';
import 'package:warehouse_app/features/worker/domain/models/worker_model.dart';
import 'package:warehouse_app/features/worker/domain/repositories/worker_repository.dart';

class DriftWorkerRepository implements WorkerRepository {
  final WorkerDao _dao;
  final SyncQueueDao _syncDao;
  final AuditLogDao _auditDao;
  final String _currentUserId;

  const DriftWorkerRepository({
    required WorkerDao dao,
    required SyncQueueDao syncDao,
    required AuditLogDao auditDao,
    required String currentUserId,
  })  : _dao = dao,
        _syncDao = syncDao,
        _auditDao = auditDao,
        _currentUserId = currentUserId;

  @override
  Stream<List<User>> watchAllWorkers() {
    return _dao.watchAllUsers().map(
          (users) => users.where((u) => _isWorkerRole(u.role)).toList(),
        );
  }

  @override
  Stream<List<User>> watchWorkersByWarehouse(String warehouseId) {
    return _dao.watchUsersByWarehouse(warehouseId).map(
          (users) => users.where((u) => _isWorkerRole(u.role)).toList(),
        );
  }

  @override
  Stream<User?> watchWorkerById(String id) => _dao.watchUserById(id);

  @override
  Future<WorkerCreateResult> createWorker(WorkerModel worker) async {
    final id = newUuid();

    await _dao.upsertUser(
      UsersCompanion.insert(
        id: id,
        fullName: worker.fullName,
        email: worker.email,
        phoneNumber: Value(worker.phoneNumber),
        password: Value(worker.password),
        role: Value(worker.role),
        mcu: Value(worker.mcu),
        amcos: Value(worker.amcos),
        warehouseId: Value(worker.warehouseId),
        isActive: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _syncDao.enqueue(
      SyncQueueCompanion.insert(
        entityType: 'users',
        entityId: id,
        operation: 'create',
        payload: jsonEncode(worker.toJson()),
      ),
    );

    await _auditDao.insertLog(
      AuditLogsCompanion.insert(
        id: newUuid(),
        userId: _currentUserId,
        action: 'worker.create',
        warehouseId: Value(worker.warehouseId),
        metadata: Value(jsonEncode({'name': worker.fullName})),
        origin: const Value('offline'),
      ),
    );

    return WorkerCreateResult.success(
      message: 'Worker created locally. Sync to upload.',
      email: worker.email,
      status: 'PENDING SYNC',
    );
  }

  @override
  Future<void> updateWorker({
    required String id,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String? warehouseId,
    required int? mcu,
    required int? amcos,
    required bool isActive,
  }) async {
    final payload = {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'warehouseId': warehouseId,
      'mcu': mcu,
      'amcos': amcos,
      'isActive': isActive,
    };

    await _dao.updateUser(
      UsersCompanion(
        id: Value(id),
        fullName: Value(fullName),
        email: Value(email),
        phoneNumber: Value(phoneNumber),
        warehouseId: Value(warehouseId),
        mcu: Value(mcu),
        amcos: Value(amcos),
        isActive: Value(isActive),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _syncDao.enqueue(
      SyncQueueCompanion.insert(
        entityType: 'users',
        entityId: id,
        operation: 'update',
        payload: jsonEncode(payload),
      ),
    );

    await _auditDao.insertLog(
      AuditLogsCompanion.insert(
        id: newUuid(),
        userId: _currentUserId,
        action: 'worker.update',
        warehouseId: Value(warehouseId),
        metadata: Value(jsonEncode({'name': fullName})),
        origin: const Value('offline'),
      ),
    );
  }

  @override
  Future<void> deleteWorker(String id) async {
    final worker = await _dao.getUserById(id);

    await _dao.softDeleteUser(id);
    await _syncDao.enqueue(
      SyncQueueCompanion.insert(
        entityType: 'users',
        entityId: id,
        operation: 'delete',
        payload: jsonEncode({'id': id}),
      ),
    );

    await _auditDao.insertLog(
      AuditLogsCompanion.insert(
        id: newUuid(),
        userId: _currentUserId,
        action: 'worker.delete',
        warehouseId: Value(worker?.warehouseId),
        metadata: Value(
          worker == null ? null : jsonEncode({'name': worker.fullName}),
        ),
        origin: const Value('offline'),
      ),
    );
  }

  bool _isWorkerRole(String role) {
    final normalized = role.trim().toLowerCase().replaceAll(' ', '_');
    return normalized == 'worker' ||
        normalized == 'amcos_user' ||
        normalized == 'user';
  }
}
