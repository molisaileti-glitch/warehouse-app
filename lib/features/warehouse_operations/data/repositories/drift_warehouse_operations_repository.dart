import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/utils/uuid_helper.dart';
import 'package:warehouse_app/features/warehouse_operations/domain/models/warehouse_operation_models.dart';
import 'package:warehouse_app/features/warehouse_operations/domain/repositories/warehouse_operations_repository.dart';

class DriftWarehouseOperationsRepository
    implements WarehouseOperationsRepository {
  final WarehouseOperationsDao _dao;
  final WarehouseDao _warehouseDao;
  final AuditLogDao _auditDao;
  final Dio _dio;
  final String _currentUserId;

  DriftWarehouseOperationsRepository({
    required WarehouseOperationsDao dao,
    required WarehouseDao warehouseDao,
    required AuditLogDao auditDao,
    required Dio dio,
    required String currentUserId,
  })  : _dao = dao,
        _warehouseDao = warehouseDao,
        _auditDao = auditDao,
        _dio = dio,
        _currentUserId = currentUserId;

  @override
  Stream<List<WarehouseInventory>> watchInventory(String warehouseId) =>
      _dao.watchInventory(warehouseId);

  @override
  Stream<List<WarehouseDispatch>> watchDispatches(String warehouseId) =>
      _dao.watchDispatches(warehouseId);

  @override
  Stream<List<WarehouseStockCount>> watchStockCounts(String warehouseId) =>
      _dao.watchStockCounts(warehouseId);

  @override
  Stream<List<WarehouseStockAdjustment>> watchStockAdjustments(
    String warehouseId,
  ) =>
      _dao.watchStockAdjustments(warehouseId);

  @override
  Future<void> recordDispatch({
    required Warehouse warehouse,
    required Crop crop,
    required String recipientType,
    required String recipientName,
    String? recipientPhone,
    required int totalBags,
    required double totalGrossWeight,
    required double totalPackagingWeight,
    required double totalNetWeight,
    double moistureContent = 0,
    DateTime? dispatchedAt,
  }) async {
    final uuid = newUuid();
    final now = DateTime.now();
    final eventTime = dispatchedAt ?? now;
    final collectionCenterUuid = _requireCollectionCenterUuid(warehouse);
    final userId = int.tryParse(_currentUserId);
    await _validateStockDecrease(
      warehouse: warehouse,
      crop: crop,
      bags: totalBags,
      grossWeight: totalGrossWeight,
      packagingWeight: totalPackagingWeight,
      netWeight: totalNetWeight,
      partialFullBagMessage:
          'Dispatch uses full bags. If stock weight has changed, perform a stock adjustment first, then dispatch.',
    );

    await _dao.insertDispatchWithQueue(
      dispatch: WarehouseDispatchesCompanion.insert(
        uuid: uuid,
        warehouseId: warehouse.id,
        collectionCenter: Value(_serverCollectionCenterId(warehouse)),
        collectionCenterUuid: collectionCenterUuid,
        collectionCenterName: Value(warehouse.name),
        amcos: Value(warehouse.amcos),
        amcosName: Value(warehouse.amcosName),
        crop: crop.id,
        cropName: crop.name,
        recipientType: recipientType,
        recipientName: recipientName,
        recipientPhone: Value(_nonEmpty(recipientPhone)),
        totalBags: totalBags,
        totalGrossWeight: totalGrossWeight,
        totalPackagingWeight: totalPackagingWeight,
        totalNetWeight: totalNetWeight,
        moistureContent: Value(moistureContent),
        dispatchedBy: Value(userId),
        dispatchedAt: Value(eventTime),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      queueEntry: _queueEntry(
        entityType: 'dispatches',
        entityId: uuid,
        payload: {
          'uuid': uuid,
          'collectionCenter': collectionCenterUuid,
          'crop': crop.id,
          'recipientType': recipientType,
          'recipientName': recipientName,
          if (_nonEmpty(recipientPhone) != null)
            'recipientPhone': _nonEmpty(recipientPhone),
          'totalBags': totalBags,
          'totalGrossWeight': totalGrossWeight,
          'totalPackagingWeight': totalPackagingWeight,
          'totalNetWeight': totalNetWeight,
          'moistureContent': moistureContent,
          if (userId != null) 'dispatchedBy': userId,
          'dispatchedAt': eventTime.toIso8601String(),
        },
      ),
    );
    await _applyLocalInventoryDelta(
      warehouse: warehouse,
      crop: crop,
      bagsDelta: -totalBags,
      grossDelta: -totalGrossWeight,
      packagingDelta: -totalPackagingWeight,
      netDelta: -totalNetWeight,
      timestamp: now,
    );
    await _log(
      'dispatch.create',
      warehouseId: warehouse.id,
      meta: {'uuid': uuid, 'crop': crop.id, 'bags': totalBags},
    );
  }

  @override
  Future<void> recordStockCount({
    required Warehouse warehouse,
    required Crop crop,
    required int countedBags,
    required double countedGrossWeight,
    required double countedPackagingWeight,
    required double countedNetWeight,
    double moistureContent = 0,
    DateTime? countedAt,
  }) async {
    final uuid = newUuid();
    final now = DateTime.now();
    final eventTime = countedAt ?? now;
    final collectionCenterUuid = _requireCollectionCenterUuid(warehouse);
    final userId = int.tryParse(_currentUserId);
    final inventory = await _dao.getInventoryByCrop(
      warehouseId: warehouse.id,
      cropId: crop.id,
    );

    await _dao.insertStockCountWithQueue(
      stockCount: WarehouseStockCountsCompanion.insert(
        uuid: uuid,
        warehouseId: warehouse.id,
        collectionCenter: Value(_serverCollectionCenterId(warehouse)),
        collectionCenterUuid: collectionCenterUuid,
        collectionCenterName: Value(warehouse.name),
        amcos: Value(warehouse.amcos),
        amcosName: Value(warehouse.amcosName),
        crop: crop.id,
        cropName: crop.name,
        expectedBags: Value(inventory?.totalBags ?? 0),
        expectedNetWeight: Value(inventory?.totalNetWeight ?? 0),
        countedBags: countedBags,
        countedGrossWeight: countedGrossWeight,
        countedPackagingWeight: countedPackagingWeight,
        countedNetWeight: countedNetWeight,
        moistureContent: Value(moistureContent),
        countedBy: Value(userId),
        countedAt: Value(eventTime),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      queueEntry: _queueEntry(
        entityType: 'stockCounts',
        entityId: uuid,
        payload: {
          'uuid': uuid,
          'collectionCenter': collectionCenterUuid,
          'crop': crop.id,
          'countedBags': countedBags,
          'countedGrossWeight': countedGrossWeight,
          'countedPackagingWeight': countedPackagingWeight,
          'countedNetWeight': countedNetWeight,
          'moistureContent': moistureContent,
          if (userId != null) 'countedBy': userId,
          'countedAt': eventTime.toIso8601String(),
        },
      ),
    );
    await _log(
      'stock-count.create',
      warehouseId: warehouse.id,
      meta: {'uuid': uuid, 'crop': crop.id},
    );
  }

  @override
  Future<void> recordStockAdjustment({
    required Warehouse warehouse,
    required Crop crop,
    required String adjustmentType,
    required String reason,
    required int bags,
    required double grossWeight,
    required double packagingWeight,
    required double netWeight,
    double moistureContent = 0,
    DateTime? adjustedAt,
  }) async {
    final uuid = newUuid();
    final now = DateTime.now();
    final eventTime = adjustedAt ?? now;
    final collectionCenterUuid = _requireCollectionCenterUuid(warehouse);
    final userId = int.tryParse(_currentUserId);
    final normalizedType = adjustmentType.toUpperCase();
    if (normalizedType == StockAdjustmentType.decrease) {
      await _validateStockDecrease(
        warehouse: warehouse,
        crop: crop,
        bags: bags,
        grossWeight: grossWeight,
        packagingWeight: packagingWeight,
        netWeight: netWeight,
      );
    }

    await _dao.insertStockAdjustmentWithQueue(
      adjustment: WarehouseStockAdjustmentsCompanion.insert(
        uuid: uuid,
        warehouseId: warehouse.id,
        collectionCenter: Value(_serverCollectionCenterId(warehouse)),
        collectionCenterUuid: collectionCenterUuid,
        collectionCenterName: Value(warehouse.name),
        amcos: Value(warehouse.amcos),
        amcosName: Value(warehouse.amcosName),
        crop: crop.id,
        cropName: crop.name,
        adjustmentType: normalizedType,
        reason: reason,
        bags: bags,
        grossWeight: grossWeight,
        packagingWeight: packagingWeight,
        netWeight: netWeight,
        moistureContent: Value(moistureContent),
        adjustedBy: Value(userId),
        adjustedAt: Value(eventTime),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      queueEntry: _queueEntry(
        entityType: 'stockAdjustments',
        entityId: uuid,
        payload: {
          'uuid': uuid,
          'collectionCenter': collectionCenterUuid,
          'crop': crop.id,
          'adjustmentType': normalizedType,
          'reason': reason,
          'bags': bags,
          'grossWeight': grossWeight,
          'packagingWeight': packagingWeight,
          'netWeight': netWeight,
          'moistureContent': moistureContent,
          if (userId != null) 'adjustedBy': userId,
          'adjustedAt': eventTime.toIso8601String(),
        },
      ),
    );

    final sign = normalizedType == StockAdjustmentType.decrease ? -1 : 1;
    await _applyLocalInventoryDelta(
      warehouse: warehouse,
      crop: crop,
      bagsDelta: sign * bags,
      grossDelta: sign * grossWeight,
      packagingDelta: sign * packagingWeight,
      netDelta: sign * netWeight,
      timestamp: now,
    );
    await _log(
      'stock-adjustment.create',
      warehouseId: warehouse.id,
      meta: {'uuid': uuid, 'crop': crop.id, 'type': normalizedType},
    );
  }

  @override
  Future<int> pullForMcu(int mcuId) async {
    var count = 0;
    count += await _pullInventory('/inventory/mcu/$mcuId');
    count += await _pullDispatches('/dispatches/mcu/$mcuId');
    count += await _pullStockCounts('/stock-counts/mcu/$mcuId');
    count += await _pullStockAdjustments('/stock-adjustments/mcu/$mcuId');
    return count;
  }

  @override
  Future<int> pullForCollectionCenter({
    required Warehouse warehouse,
  }) async {
    final collectionCenterUuid = _requireCollectionCenterUuid(warehouse);
    var count = 0;
    count += await _pullInventory(
      '/inventory/collection-center/$collectionCenterUuid',
    );
    count += await _pullDispatches(
      '/dispatches/collection-center/$collectionCenterUuid',
    );
    count += await _pullStockCounts(
      '/stock-counts/collection-center/$collectionCenterUuid',
    );
    count += await _pullStockAdjustments(
      '/stock-adjustments/collection-center/$collectionCenterUuid',
    );
    return count;
  }

  @override
  Future<void> markDispatchSynced(String uuid) => _dao.markDispatchSynced(uuid);

  @override
  Future<void> markDispatchConflict(String uuid) =>
      _dao.markDispatchConflict(uuid);

  @override
  Future<void> markStockCountSynced(String uuid) =>
      _dao.markStockCountSynced(uuid);

  @override
  Future<void> markStockCountConflict(String uuid) =>
      _dao.markStockCountConflict(uuid);

  @override
  Future<void> markStockAdjustmentSynced(String uuid) =>
      _dao.markStockAdjustmentSynced(uuid);

  @override
  Future<void> markStockAdjustmentConflict(String uuid) =>
      _dao.markStockAdjustmentConflict(uuid);

  Future<int> _pullInventory(String path) async {
    try {
      final response = await _dio.get(path);
      final rows = await _rowsWithWarehouseId(response.data);
      for (final item in rows) {
        await _dao.upsertInventory(
          _inventoryFromJson(item.json, warehouseId: item.warehouseId),
        );
      }
      return rows.length;
    } on DioException {
      return 0;
    }
  }

  Future<int> _pullDispatches(String path) async {
    try {
      final response = await _dio.get(path);
      final rows = await _rowsWithWarehouseId(response.data);
      for (final item in rows) {
        await _dao.upsertDispatch(
          _dispatchFromJson(item.json, warehouseId: item.warehouseId),
        );
      }
      return rows.length;
    } on DioException {
      return 0;
    }
  }

  Future<int> _pullStockCounts(String path) async {
    try {
      final response = await _dio.get(path);
      final rows = await _rowsWithWarehouseId(response.data);
      for (final item in rows) {
        await _dao.upsertStockCount(
          _stockCountFromJson(item.json, warehouseId: item.warehouseId),
        );
      }
      return rows.length;
    } on DioException {
      return 0;
    }
  }

  Future<int> _pullStockAdjustments(String path) async {
    try {
      final response = await _dio.get(path);
      final rows = await _rowsWithWarehouseId(response.data);
      for (final item in rows) {
        await _dao.upsertStockAdjustment(
          _stockAdjustmentFromJson(item.json, warehouseId: item.warehouseId),
        );
      }
      return rows.length;
    } on DioException {
      return 0;
    }
  }

  Future<void> _applyLocalInventoryDelta({
    required Warehouse warehouse,
    required Crop crop,
    required int bagsDelta,
    required double grossDelta,
    required double packagingDelta,
    required double netDelta,
    required DateTime timestamp,
  }) async {
    final collectionCenterUuid = _requireCollectionCenterUuid(warehouse);
    final current = await _dao.getInventoryByCrop(
      warehouseId: warehouse.id,
      cropId: crop.id,
    );
    final totalBags = (current?.totalBags ?? 0) + bagsDelta;

    await _dao.upsertInventory(
      WarehouseInventoryItemsCompanion.insert(
        uuid: current?.uuid ?? newUuid(),
        serverId: Value(current?.serverId),
        warehouseId: warehouse.id,
        collectionCenter: Value(
          current?.collectionCenter ?? _serverCollectionCenterId(warehouse),
        ),
        collectionCenterUuid:
            current?.collectionCenterUuid ?? collectionCenterUuid,
        collectionCenterName:
            Value(current?.collectionCenterName ?? warehouse.name),
        amcos: Value(current?.amcos ?? warehouse.amcos),
        amcosName: Value(current?.amcosName ?? warehouse.amcosName),
        mcu: Value(current?.mcu),
        mcuName: Value(current?.mcuName),
        crop: crop.id,
        cropName: crop.name,
        totalBags: Value(totalBags < 0 ? 0 : totalBags),
        totalGrossWeight: Value(
          _nonNegative((current?.totalGrossWeight ?? 0) + grossDelta),
        ),
        totalPackagingWeight: Value(
          _nonNegative((current?.totalPackagingWeight ?? 0) + packagingDelta),
        ),
        totalNetWeight: Value(
          _nonNegative((current?.totalNetWeight ?? 0) + netDelta),
        ),
        createdAt: Value(current?.createdAt ?? timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<void> _validateStockDecrease({
    required Warehouse warehouse,
    required Crop crop,
    required int bags,
    required double grossWeight,
    required double packagingWeight,
    required double netWeight,
    String? partialFullBagMessage,
  }) async {
    final current = await _dao.getInventoryByCrop(
      warehouseId: warehouse.id,
      cropId: crop.id,
    );
    if (current == null || current.totalBags <= 0) {
      throw StateError('No stock available for this crop.');
    }
    if (bags > current.totalBags) {
      throw StateError(
        'Cannot remove $bags bags. Only ${current.totalBags} bags are available.',
      );
    }
    if (_greaterThan(grossWeight, current.totalGrossWeight)) {
      throw StateError('Gross weight cannot exceed available stock.');
    }
    if (_greaterThan(packagingWeight, current.totalPackagingWeight)) {
      throw StateError('Packaging weight cannot exceed available stock.');
    }
    if (_greaterThan(netWeight, current.totalNetWeight)) {
      throw StateError('Net weight cannot exceed available stock.');
    }

    final removesAllBags = bags == current.totalBags;
    if (!removesAllBags) return;

    if (!_nearlyEqual(grossWeight, current.totalGrossWeight) ||
        !_nearlyEqual(packagingWeight, current.totalPackagingWeight) ||
        !_nearlyEqual(netWeight, current.totalNetWeight)) {
      throw StateError(
        partialFullBagMessage ??
            'Removing all bags must remove the full recorded stock for this crop.',
      );
    }
  }

  Future<List<({Map<String, dynamic> json, String warehouseId})>>
      _rowsWithWarehouseId(Object? data) async {
    final rows = _records(data);
    final mapped = <({Map<String, dynamic> json, String warehouseId})>[];
    for (final row in rows) {
      final warehouseId = await _warehouseIdFor(row);
      if (warehouseId == null) continue;
      mapped.add((json: row, warehouseId: warehouseId));
    }
    return mapped;
  }

  Future<String?> _warehouseIdFor(Map<String, dynamic> json) async {
    final collectionCenterUuid = _string(json['collectionCenterUuid']);
    if (collectionCenterUuid != null) {
      final warehouse =
          await _warehouseDao.getWarehouseByUuid(collectionCenterUuid);
      if (warehouse != null) return warehouse.id;
    }

    final collectionCenter = _int(json['collectionCenter']);
    if (collectionCenter != null) {
      final warehouse =
          await _warehouseDao.getWarehouseById(collectionCenter.toString());
      if (warehouse != null) return warehouse.id;
    }

    return null;
  }

  WarehouseInventoryItemsCompanion _inventoryFromJson(
    Map<String, dynamic> json, {
    required String warehouseId,
  }) {
    return WarehouseInventoryItemsCompanion.insert(
      uuid: _string(json['uuid']) ?? newUuid(),
      serverId: Value(_int(json['id'])),
      warehouseId: warehouseId,
      collectionCenter: Value(_int(json['collectionCenter'])),
      collectionCenterUuid: _string(json['collectionCenterUuid']) ?? '',
      collectionCenterName: Value(_string(json['collectionCenterName'])),
      amcos: Value(_int(json['amcos'])),
      amcosName: Value(_string(json['amcosName'])),
      mcu: Value(_int(json['mcu'])),
      mcuName: Value(_string(json['mcuName'])),
      crop: _int(json['crop']) ?? 0,
      cropName: _string(json['cropName']) ?? 'Crop',
      totalBags: Value(_int(json['totalBags']) ?? 0),
      totalGrossWeight: Value(_double(json['totalGrossWeight'])),
      totalPackagingWeight: Value(_double(json['totalPackagingWeight'])),
      totalNetWeight: Value(_double(json['totalNetWeight'])),
      createdAt: Value(_date(json['createdAt'])),
      updatedAt: Value(_date(json['updatedAt'])),
    );
  }

  WarehouseDispatchesCompanion _dispatchFromJson(
    Map<String, dynamic> json, {
    required String warehouseId,
  }) {
    return WarehouseDispatchesCompanion.insert(
      uuid: _string(json['uuid']) ?? newUuid(),
      serverId: Value(_int(json['id'])),
      warehouseId: warehouseId,
      collectionCenter: Value(_int(json['collectionCenter'])),
      collectionCenterUuid: _string(json['collectionCenterUuid']) ?? '',
      collectionCenterName: Value(_string(json['collectionCenterName'])),
      amcos: Value(_int(json['amcos'])),
      amcosName: Value(_string(json['amcosName'])),
      mcu: Value(_int(json['mcu'])),
      mcuName: Value(_string(json['mcuName'])),
      crop: _int(json['crop']) ?? 0,
      cropName: _string(json['cropName']) ?? 'Crop',
      recipientType:
          _string(json['recipientType']) ?? WarehouseRecipientType.other,
      recipientName: _string(json['recipientName']) ?? '',
      recipientPhone: Value(_string(json['recipientPhone'])),
      totalBags: _int(json['totalBags']) ?? 0,
      totalGrossWeight: _double(json['totalGrossWeight']),
      totalPackagingWeight: _double(json['totalPackagingWeight']),
      totalNetWeight: _double(json['totalNetWeight']),
      moistureContent: Value(_double(json['moistureContent'])),
      dispatchedBy: Value(_int(json['dispatchedBy'])),
      dispatchedByName: Value(_string(json['dispatchedByName'])),
      dispatchedAt: Value(_date(json['dispatchedAt']) ?? DateTime.now()),
      syncStatus: const Value('synced'),
      createdAt: Value(_date(json['createdAt']) ?? DateTime.now()),
      updatedAt: Value(_date(json['updatedAt']) ?? DateTime.now()),
    );
  }

  WarehouseStockCountsCompanion _stockCountFromJson(
    Map<String, dynamic> json, {
    required String warehouseId,
  }) {
    return WarehouseStockCountsCompanion.insert(
      uuid: _string(json['uuid']) ?? newUuid(),
      serverId: Value(_int(json['id'])),
      warehouseId: warehouseId,
      collectionCenter: Value(_int(json['collectionCenter'])),
      collectionCenterUuid: _string(json['collectionCenterUuid']) ?? '',
      collectionCenterName: Value(_string(json['collectionCenterName'])),
      amcos: Value(_int(json['amcos'])),
      amcosName: Value(_string(json['amcosName'])),
      mcu: Value(_int(json['mcu'])),
      mcuName: Value(_string(json['mcuName'])),
      crop: _int(json['crop']) ?? 0,
      cropName: _string(json['cropName']) ?? 'Crop',
      expectedBags: Value(_int(json['expectedBags']) ?? 0),
      expectedNetWeight: Value(_double(json['expectedNetWeight'])),
      countedBags: _int(json['countedBags']) ?? 0,
      countedGrossWeight: _double(json['countedGrossWeight']),
      countedPackagingWeight: _double(json['countedPackagingWeight']),
      countedNetWeight: _double(json['countedNetWeight']),
      moistureContent: Value(_double(json['moistureContent'])),
      countedBy: Value(_int(json['countedBy'])),
      countedByName: Value(_string(json['countedByName'])),
      countedAt: Value(_date(json['countedAt']) ?? DateTime.now()),
      syncStatus: const Value('synced'),
      createdAt: Value(_date(json['createdAt']) ?? DateTime.now()),
      updatedAt: Value(_date(json['updatedAt']) ?? DateTime.now()),
    );
  }

  WarehouseStockAdjustmentsCompanion _stockAdjustmentFromJson(
    Map<String, dynamic> json, {
    required String warehouseId,
  }) {
    return WarehouseStockAdjustmentsCompanion.insert(
      uuid: _string(json['uuid']) ?? newUuid(),
      serverId: Value(_int(json['id'])),
      warehouseId: warehouseId,
      collectionCenter: Value(_int(json['collectionCenter'])),
      collectionCenterUuid: _string(json['collectionCenterUuid']) ?? '',
      collectionCenterName: Value(_string(json['collectionCenterName'])),
      amcos: Value(_int(json['amcos'])),
      amcosName: Value(_string(json['amcosName'])),
      mcu: Value(_int(json['mcu'])),
      mcuName: Value(_string(json['mcuName'])),
      crop: _int(json['crop']) ?? 0,
      cropName: _string(json['cropName']) ?? 'Crop',
      adjustmentType:
          _string(json['adjustmentType']) ?? StockAdjustmentType.increase,
      reason: _string(json['reason']) ?? StockAdjustmentReason.other,
      bags: _int(json['bags']) ?? 0,
      grossWeight: _double(json['grossWeight']),
      packagingWeight: _double(json['packagingWeight']),
      netWeight: _double(json['netWeight']),
      moistureContent: Value(_double(json['moistureContent'])),
      adjustedBy: Value(_int(json['adjustedBy'])),
      adjustedByName: Value(_string(json['adjustedByName'])),
      adjustedAt: Value(_date(json['adjustedAt']) ?? DateTime.now()),
      syncStatus: const Value('synced'),
      createdAt: Value(_date(json['createdAt']) ?? DateTime.now()),
      updatedAt: Value(_date(json['updatedAt']) ?? DateTime.now()),
    );
  }

  SyncQueueCompanion _queueEntry({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    return SyncQueueCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      operation: 'create',
      payload: jsonEncode(payload),
    );
  }

  Future<void> _log(
    String action, {
    required String warehouseId,
    Map<String, dynamic>? meta,
  }) {
    return _auditDao.insertLog(AuditLogsCompanion.insert(
      id: newUuid(),
      userId: _currentUserId,
      action: action,
      warehouseId: Value(warehouseId),
      metadata: Value(meta != null ? jsonEncode(meta) : null),
      origin: const Value('offline'),
    ));
  }

  List<Map<String, dynamic>> _records(Object? data) {
    final raw = data is Map<String, dynamic>
        ? data['records'] ?? data['content'] ?? data['data'] ?? data['results']
        : data;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  String _requireCollectionCenterUuid(Warehouse warehouse) {
    final uuid = warehouse.uuid.trim();
    if (uuid.isNotEmpty) return uuid;
    if (int.tryParse(warehouse.id) == null && warehouse.id.trim().isNotEmpty) {
      return warehouse.id;
    }
    throw StateError('This warehouse does not have a collection center UUID.');
  }

  int? _serverCollectionCenterId(Warehouse warehouse) {
    return int.tryParse(warehouse.id);
  }

  String? _nonEmpty(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _nonNegative(double value) => value < 0 ? 0 : value;

  bool _greaterThan(num value, num limit) {
    return value > limit + _weightToleranceKg;
  }

  bool _nearlyEqual(num left, num right) {
    return (left - right).abs() <= _weightToleranceKg;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }
}

const double _weightToleranceKg = 0.01;
