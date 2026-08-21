import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/utils/uuid_helper.dart';
import 'package:warehouse_app/features/warehouse/domain/models/warehouse_model.dart';
import 'package:warehouse_app/features/warehouse/domain/repositories/warehouse_repository.dart';

class DriftWarehouseRepository implements WarehouseRepository {
  final WarehouseDao _dao;
  final AuditLogDao _auditDao;
  final Dio _dio;
  final String _currentUserId;
  final Future<int?> Function() _currentMcuId;

  DriftWarehouseRepository({
    required WarehouseDao dao,
    required AuditLogDao auditDao,
    required Dio dio,
    required String currentUserId,
    required Future<int?> Function() currentMcuId,
  })  : _dao = dao,
        _auditDao = auditDao,
        _dio = dio,
        _currentUserId = currentUserId,
        _currentMcuId = currentMcuId;

  @override
  Stream<List<Warehouse>> watchAll() => _dao.watchAllWarehouses();

  @override
  Stream<List<Warehouse>> watchByOwner(String ownerId) =>
      _dao.watchWarehousesByOwner(ownerId);

  @override
  Stream<List<Warehouse>> watchByAmcos(int amcosId) =>
      _dao.watchWarehousesByAmcos(amcosId);

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
    final mcuId = await _requireMcuId();
    final id = newUuid();
    final model = WarehouseModel(
      uuid: id,
      id: id,
      name: name,
      ownerId: mcuId.toString(),
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

    await _dao.insertPendingWarehouse(
      warehouse: companion,
      queueEntry: _queueEntry(
        id: id,
        operation: 'create',
        payload: model.toSyncPayload()..['mcu'] = mcuId,
      ),
    );
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
    final mcuId = await _requireMcuId();

    await _dao.updatePendingWarehouse(
      warehouse: companion,
      queueEntry: _queueEntry(
        id: id,
        operation: 'update',
        payload: _buildSyncPayload(current, companion, mcuId),
      ),
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

    await _dao.deletePendingWarehouse(
      id: id,
      queueEntry: _queueEntry(
        id: id,
        operation: 'delete',
        payload: {'uuid': current?.uuid ?? id},
      ),
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

  @override
  Future<int> pullFromAmcos({required int amcosId}) async {
    try {
      final res = await _dio.get('/collection-centers/amcos/$amcosId');
      final rows = _asList(res.data);
      developer.log(
        '[WarehouseSync] pull requestedAmcos=$amcosId rows=${rows.length}',
        name: 'sync.warehouse',
      );
      for (final json in rows) {
        await upsertDownstream(json);
      }
      return rows.length;
    } on DioException catch (e) {
      developer.log(
        '[WarehouseSync] pull by amcos failed amcos=$amcosId '
        'status=${e.response?.statusCode} response=${e.response?.data}',
        name: 'sync.warehouse',
      );
      return 0;
    }
  }

  List<Map<String, dynamic>> _asList(Object? data) {
    final raw = data is Map<String, dynamic>
        ? data['content'] ?? data['records'] ?? data['results'] ?? data['data']
        : data;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<void> upsertDownstream(Map<String, dynamic> json) async {
    final model = WarehouseModel.fromJson(json);
    try {
      developer.log(
        '[WarehouseSync] ensure refs id=${model.id} uuid=${model.uuid} '
        'amcos=${model.amcos} village=${model.village}',
        name: 'sync.warehouse',
      );
      await _dao.ensureWarehouseReferences(
        amcosId: model.amcos,
        amcosName: model.amcosName,
        mcu: _int(json['mcu'] ?? model.ownerId),
        mcuName: _string(json['mcuName'] ?? json['mcu_name']),
        villageId: model.village,
        villageName: model.villageName,
      );
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
    } catch (e, stackTrace) {
      developer.log(
        '[WarehouseSync] upsert failed id=${model.id} uuid=${model.uuid} '
        'amcos=${model.amcos} village=${model.village} json=$json',
        name: 'sync.warehouse',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  SyncQueueCompanion _queueEntry({
    required String id,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return SyncQueueCompanion.insert(
      entityType: 'warehouses',
      entityId: id,
      operation: operation,
      payload: jsonEncode(payload),
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
    int mcuId,
  ) {
    final payload = <String, dynamic>{};
    if (current?.uuid != null && current!.uuid.isNotEmpty) {
      payload['uuid'] = current.uuid;
    }
    payload['mcu'] = mcuId;
    if (c.name.present) payload['name'] = c.name.value;
    if (c.gpsLocation.present) payload['gpsLocation'] = c.gpsLocation.value;
    if (c.amcos.present) payload['amcos'] = c.amcos.value;
    if (c.amcosName.present) payload['amcosName'] = c.amcosName.value;
    if (c.village.present) payload['village'] = c.village.value;
    if (c.villageName.present) payload['villageName'] = c.villageName.value;
    return payload;
  }

  Future<int> _requireMcuId() async {
    final mcuId = await _currentMcuId();
    if (mcuId == null) {
      throw StateError('The signed-in user has no MCU assignment');
    }
    return mcuId;
  }

  int? _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
