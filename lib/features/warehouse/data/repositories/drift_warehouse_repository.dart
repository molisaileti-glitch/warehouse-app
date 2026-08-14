import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/utils/uuid_helper.dart';
import 'package:warehouse_app/features/warehouse/domain/models/warehouse_model.dart';
import 'package:warehouse_app/features/warehouse/domain/repositories/warehouse_repository.dart';

class DriftWarehouseRepository implements WarehouseRepository {
  final WarehouseDao _dao;
  final SyncQueueDao _syncDao;
  final AuditLogDao _auditDao;
  final Dio _dio;
  final String _currentUserId;

  DriftWarehouseRepository({
    required WarehouseDao dao,
    required SyncQueueDao syncDao,
    required AuditLogDao auditDao,
    required Dio dio,
    required String currentUserId,
  })  : _dao = dao,
        _syncDao = syncDao,
        _auditDao = auditDao,
        _dio = dio,
        _currentUserId = currentUserId;

  @override
  Stream<List<Warehouse>> watchAll() => _dao.watchAllWarehouses();

  @override
  Stream<List<Warehouse>> watchByOwner(String ownerId) =>
      _dao.watchWarehousesByOwner(ownerId);

  @override
  Stream<Warehouse?> watchById(String id) => _dao.watchWarehouseById(id);

  @override
  Future<Warehouse> createWarehouse({
    required String name,
    String? gpsLocation,
    int? amcos,
    String? amcosName,
    int? village,
    String? villageName,
  }) async {
    final id = newUuid();
    final model = WarehouseModel(
      uuid: id,
      id: id,
      name: name,
      ownerId: _currentUserId,
      gpsLocation: gpsLocation,
      amcos: amcos,
      amcosName: amcosName,
      village: village,
      villageName: villageName,
      synced: false,
      syncAction: 'created',
      createdAt: DateTime.now(),
    );
    final companion = model.toCompanion();

    await _dao.insertWarehouse(companion);
    await _enqueue(id: id, operation: 'create', payload: model.toSyncPayload());
    await _logAction(
      action: 'warehouse.create',
      warehouseId: id,
      metadata: {'name': name},
    );
    return (await _dao.getWarehouseById(id))!;
  }

  @override
  Future<void> updateWarehouse({
    required String id,
    String? name,
    String? gpsLocation,
    int? amcos,
    String? amcosName,
    int? village,
    String? villageName,
  }) async {
    final companion = WarehousesCompanion(
      id: Value(id),
      name: name != null ? Value(name) : const Value.absent(),
      gpsLocation:
          gpsLocation != null ? Value(gpsLocation) : const Value.absent(),
      amcos: amcos != null ? Value(amcos) : const Value.absent(),
      amcosName: amcosName != null ? Value(amcosName) : const Value.absent(),
      village: village != null ? Value(village) : const Value.absent(),
      villageName:
          villageName != null ? Value(villageName) : const Value.absent(),
      synced: const Value(false),
      syncAction: const Value('updated'),
      syncStatus: const Value('pending'),
      updatedAt: Value(DateTime.now()),
    );

    final current = await _dao.getWarehouseById(id);

    await _dao.updateWarehouse(companion);
    await _enqueue(
      id: id,
      operation: 'update',
      payload: _buildSyncPayload(current, companion),
    );
    await _logAction(
      action: 'warehouse.update',
      warehouseId: id,
      metadata: name == null ? null : {'name': name},
    );
  }

  @override
  Future<void> deleteWarehouse(String id) async {
    final current = await _dao.getWarehouseById(id);

    await _dao.softDeleteWarehouse(id);
    await _enqueue(
      id: id,
      operation: 'delete',
      payload: {'uuid': current?.uuid ?? id},
    );
    await _logAction(action: 'warehouse.delete', warehouseId: id);
  }

  @override
  Future<int> pullFromServer({required int mcuId}) async {
    try {
      final res = await _dio.get('/collection-centers/mcu/$mcuId');
      final rows = _asList(res.data);
      developer.log(
        '[WarehouseSync] pull requestedMcu=$mcuId rows=${rows.length} '
        'returnedMcus=${rows.map((row) => row['mcu']).toSet()}',
        name: 'sync.warehouse',
      );
      for (final json in rows) {
        await upsertDownstream(json);
      }
      return rows.length;
    } on DioException {
      return 0;
    }
  }

  List<Map<String, dynamic>> _asList(Object? data) {
    final raw = data is Map<String, dynamic>
        ? data['records'] ?? data['results'] ?? data['data']
        : data;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<void> upsertDownstream(Map<String, dynamic> json) async {
    final model = WarehouseModel.fromJson(json);
    final existing = await _dao.getWarehouseByUuid(model.uuid);
    if (_shouldKeepLocal(existing, model)) {
      return;
    }
    await _dao.upsertWarehouse(
      model.toCompanion(
        syncStatus: 'synced',
        updatedAt: model.updatedAt ?? DateTime.now(),
        syncedValue: true,
      ),
    );
  }

  Future<void> _enqueue({
    required String id,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return _syncDao.enqueue(
      SyncQueueCompanion.insert(
        entityType: 'warehouses',
        entityId: id,
        operation: operation,
        payload: jsonEncode(payload),
      ),
    );
  }

  Future<void> _logAction({
    required String action,
    String? warehouseId,
    Map<String, dynamic>? metadata,
  }) {
    return _auditDao.insertLog(
      AuditLogsCompanion.insert(
        id: newUuid(),
        userId: _currentUserId,
        action: action,
        warehouseId: Value(warehouseId),
        metadata: Value(metadata == null ? null : jsonEncode(metadata)),
        origin: const Value('offline'),
      ),
    );
  }

  bool _shouldKeepLocal(Warehouse? existing, WarehouseModel remote) {
    if (existing == null) return false;
    if (existing.syncStatus == 'pending' || existing.syncStatus == 'conflict') {
      final localUpdatedAt = existing.updatedAt;
      final remoteUpdatedAt = remote.updatedAt ?? DateTime.now();
      return localUpdatedAt.isAfter(remoteUpdatedAt);
    }
    return false;
  }

  Map<String, dynamic> _buildSyncPayload(
    Warehouse? current,
    WarehousesCompanion c,
  ) {
    final payload = <String, dynamic>{};
    if (current?.uuid != null && current!.uuid.isNotEmpty) {
      payload['uuid'] = current.uuid;
    }
    payload['mcu'] = int.tryParse(_currentUserId) ?? _currentUserId;
    if (c.name.present) payload['name'] = c.name.value;
    if (c.gpsLocation.present) payload['gpsLocation'] = c.gpsLocation.value;
    if (c.amcos.present) payload['amcos'] = c.amcos.value;
    if (c.amcosName.present) payload['amcosName'] = c.amcosName.value;
    if (c.village.present) payload['village'] = c.village.value;
    if (c.villageName.present) payload['villageName'] = c.villageName.value;
    return payload;
  }
}
