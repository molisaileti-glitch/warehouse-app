import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/utils/uuid_helper.dart';
import 'package:warehouse_app/features/worker/domain/models/worker_model.dart';
import 'package:warehouse_app/features/worker/domain/repositories/worker_repository.dart';

class DriftWorkerRepository implements WorkerRepository {
  final WorkerDao _dao;
  final AuditLogDao _auditDao;
  final Dio _dio;
  final String _currentUserId;

  const DriftWorkerRepository({
    required WorkerDao dao,
    required AuditLogDao auditDao,
    required Dio dio,
    required String currentUserId,
  })  : _dao = dao,
        _auditDao = auditDao,
        _dio = dio,
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
  Future<void> setActiveWarehouse({
    required String userId,
    required String warehouseId,
  }) {
    return _dao.setUserWarehouse(id: userId, warehouseId: warehouseId);
  }

  @override
  Future<int> pullFromServer({required int mcuId}) async {
    final response = await _dio.get('/users/mcu/$mcuId');
    final rows = _asList(response.data)
        .where((row) => _isWorkerRole(_string(row['role'])))
        .toList();

    var assignedCount = 0;

    for (final row in rows) {
      final serverId = _string(row['id']);
      final email = _string(row['email']);
      if (serverId.isEmpty || email.isEmpty) continue;

      final existing = await _dao.getUserByEmail(email);
      final amcosId = _nullableInt(row['amcos']) ??
          _nullableInt(_assignmentId(row['amcos']));
      final serverWarehouseId = _assignmentId(
        row['warehouseId'] ??
            row['warehouse_id'] ??
            row['collectionCenterId'] ??
            row['collection_center_id'] ??
            row['collectionCenter'] ??
            row['warehouse'],
      );
      final localActiveWarehouseId =
          existing?.id == _currentUserId ? existing?.warehouseId : null;
      final resolvedWarehouseId = localActiveWarehouseId ??
          serverWarehouseId ??
          existing?.warehouseId;
      if (serverWarehouseId != null && serverWarehouseId.isNotEmpty) {
        assignedCount++;
      }
      if (existing != null && existing.id != serverId) {
        await _dao.deleteUserById(existing.id);
      }

      await _dao.upsertUser(
        UsersCompanion.insert(
          id: serverId,
          fullName: _string(row['fullName']),
          email: email,
          phoneNumber: Value(_string(row['phoneNumber'])),
          role: Value(_string(row['role'], fallback: 'USER')),
          mcu: Value(_nullableInt(row['mcu']) ?? mcuId),
          amcos: Value(amcosId),
          warehouseId: Value(resolvedWarehouseId),
          isActive: Value(
            _string(row['status'], fallback: 'ACTIVE').toUpperCase() ==
                'ACTIVE',
          ),
          syncStatus: const Value('synced'),
          updatedAt: Value(_date(row['updatedAt']) ?? DateTime.now()),
        ),
      );
    }

    developer.log(
      '[WorkerSync] pull requestedMcu=$mcuId workers=${rows.length} '
      'assigned=$assignedCount',
      name: 'sync.worker',
    );
    return rows.length;
  }

  @override
  Future<WorkerCreateResult> createWorker(WorkerModel worker) async {
    final id = newUuid();
    final payload = worker.toJson()..['uuid'] = id;

    final user = UsersCompanion.insert(
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
    );
    await _dao.insertPendingUser(
      user: user,
      queueEntry: SyncQueueCompanion.insert(
        entityType: 'users',
        entityId: id,
        operation: 'create',
        payload: jsonEncode(payload),
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

    final user = UsersCompanion(
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
    );
    await _dao.updatePendingUser(
      user: user,
      queueEntry: SyncQueueCompanion.insert(
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

    await _dao.deletePendingUser(
      id: id,
      queueEntry: SyncQueueCompanion.insert(
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

  String? _assignmentId(Object? value) {
    if (value is Map) {
      return _nullableString(
        value['id'] ?? value['warehouseId'] ?? value['collectionCenterId'],
      );
    }
    return _nullableString(value);
  }

  List<Map<String, dynamic>> _asList(Object? data) {
    final raw = data is Map<String, dynamic>
        ? data['content'] ?? data['records'] ?? data['results'] ?? data['data']
        : data;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  int? _nullableInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  DateTime? _date(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '');
  }

  String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
