// lib/core/repositories/inventory_repository.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import '../database/app_database.dart';
import '../utils/uuid_helper.dart';

class InventoryRepository {
  final InventoryDao _dao;
  final SyncQueueDao _syncDao;
  final AuditLogDao _auditDao;
  final Dio _dio;
  final String _currentUserId;

  InventoryRepository({
    required InventoryDao dao,
    required SyncQueueDao syncDao,
    required AuditLogDao auditDao,
    required Dio dio,
    required String currentUserId,
  })  : _dao = dao,
        _syncDao = syncDao,
        _auditDao = auditDao,
        _dio = dio,
        _currentUserId = currentUserId;

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<InventoryItem>> watchItems(String warehouseId) =>
      _dao.watchItemsByWarehouse(warehouseId);

  Stream<List<InventoryItem>> watchLowStock(String warehouseId) =>
      _dao.watchLowStockItems(warehouseId);

  Stream<InventoryItem?> watchItem(String id) => _dao.watchItemById(id);

  Stream<List<StockMovement>> watchMovements(String itemId) =>
      _dao.watchMovementsForItem(itemId);

  Stream<List<StockMovement>> watchWarehouseMovements(
    String warehouseId, {
    DateTime? from,
    DateTime? to,
  }) =>
      _dao.watchMovementsByWarehouse(warehouseId, from: from, to: to);

  // ── Item CRUD ─────────────────────────────────────────────────────────────

  Future<InventoryItem> createItem({
    required String warehouseId,
    required String name,
    String? sku,
    String? category,
    String unit = 'pcs',
    double reorderLevel = 0,
    String? description,
  }) async {
    final id = newUuid();
    final companion = InventoryItemsCompanion.insert(
      id: id,
      warehouseId: warehouseId,
      name: name,
      sku: Value(sku),
      category: Value(category),
      unit: Value(unit),
      reorderLevel: Value(reorderLevel),
      description: Value(description),
      syncStatus: const Value('pending'),
    );
    await _dao.insertItem(companion);
    await _syncDao.enqueue(SyncQueueCompanion.insert(
      entityType: 'inventoryItems',
      entityId: id,
      operation: 'create',
      payload: jsonEncode(_itemToJson(companion)),
    ));
    await _log('inventory.create',
        warehouseId: warehouseId, meta: {'item_id': id, 'name': name});
    return (await _dao.getItemById(id))!;
  }

  Future<void> updateItem({
    required String id,
    String? name,
    String? sku,
    String? category,
    String? unit,
    double? reorderLevel,
    String? description,
  }) async {
    final item = await _dao.getItemById(id);
    if (item == null) return;

    final companion = InventoryItemsCompanion(
      id: Value(id),
      name: name != null ? Value(name) : const Value.absent(),
      sku: sku != null ? Value(sku) : const Value.absent(),
      category: category != null ? Value(category) : const Value.absent(),
      unit: unit != null ? Value(unit) : const Value.absent(),
      reorderLevel:
          reorderLevel != null ? Value(reorderLevel) : const Value.absent(),
      description:
          description != null ? Value(description) : const Value.absent(),
      syncStatus: const Value('pending'),
      updatedAt: Value(DateTime.now()),
    );
    await _dao.updateItem(companion);
    await _syncDao.enqueue(SyncQueueCompanion.insert(
      entityType: 'inventoryItems',
      entityId: id,
      operation: 'update',
      payload: jsonEncode({'id': id, ...?_partialItemJson(companion)}),
    ));
    await _log('inventory.update',
        warehouseId: item.warehouseId, meta: {'item_id': id});
  }

  Future<void> deleteItem(String id) async {
    final item = await _dao.getItemById(id);
    if (item == null) return;
    await _dao.softDeleteItem(id);
    await _syncDao.enqueue(SyncQueueCompanion.insert(
      entityType: 'inventoryItems',
      entityId: id,
      operation: 'delete',
      payload: jsonEncode({'id': id}),
    ));
    await _log('inventory.delete',
        warehouseId: item.warehouseId, meta: {'item_id': id});
  }

  // ── Stock movements ───────────────────────────────────────────────────────

  Future<void> recordDelivery({
    required String itemId,
    required double quantity,
    String? notes,
  }) =>
      _recordMovement(
        itemId: itemId,
        movementType: 'delivery',
        quantity: quantity,
        notes: notes,
      );

  Future<void> recordCount({
    required String itemId,
    required double actualCount,
    String? notes,
  }) async {
    final item = await _dao.getItemById(itemId);
    if (item == null) return;
    final adjustment = actualCount - item.quantityOnHand;
    await _recordMovement(
      itemId: itemId,
      movementType: 'count',
      quantity: adjustment,
      notes: notes,
    );
  }

  Future<void> recordAdjustment({
    required String itemId,
    required double quantity,
    String? notes,
  }) =>
      _recordMovement(
        itemId: itemId,
        movementType: 'adjustment',
        quantity: quantity,
        notes: notes,
      );

  Future<void> recordTransfer({
    required String itemId,
    required String targetWarehouseId,
    required double quantity,
    String? notes,
  }) async {
    final item = await _dao.getItemById(itemId);
    if (item == null) return;
    final movId = newUuid();
    await _dao.recordMovement(
      movement: StockMovementsCompanion.insert(
        id: movId,
        inventoryItemId: itemId,
        warehouseId: item.warehouseId,
        movementType: 'transfer_out',
        quantity: -quantity,
        quantityBefore: item.quantityOnHand,
        recordedById: _currentUserId,
        notes: Value(notes),
        relatedWarehouseId: Value(targetWarehouseId),
        syncStatus: const Value('pending'),
      ),
      newQuantity: item.quantityOnHand - quantity,
    );
    await _syncDao.enqueue(SyncQueueCompanion.insert(
      entityType: 'stockMovements',
      entityId: movId,
      operation: 'create',
      payload: jsonEncode({
        'id': movId,
        'type': 'transfer_out',
        'item_id': itemId,
        'quantity': quantity,
        'target_warehouse': targetWarehouseId
      }),
    ));
    await _log('stock.transfer',
        warehouseId: item.warehouseId,
        meta: {'item_id': itemId, 'qty': quantity, 'to': targetWarehouseId});
  }

  Future<void> _recordMovement({
    required String itemId,
    required String movementType,
    required double quantity,
    String? notes,
  }) async {
    final item = await _dao.getItemById(itemId);
    if (item == null) return;
    final movId = newUuid();
    final newQty = item.quantityOnHand + quantity;

    await _dao.recordMovement(
      movement: StockMovementsCompanion.insert(
        id: movId,
        inventoryItemId: itemId,
        warehouseId: item.warehouseId,
        movementType: movementType,
        quantity: quantity,
        quantityBefore: item.quantityOnHand,
        recordedById: _currentUserId,
        notes: Value(notes),
        syncStatus: const Value('pending'),
      ),
      newQuantity: newQty,
    );

    await _syncDao.enqueue(SyncQueueCompanion.insert(
      entityType: 'stockMovements',
      entityId: movId,
      operation: 'create',
      payload: jsonEncode({
        'id': movId,
        'item_id': itemId,
        'type': movementType,
        'quantity': quantity,
        'quantity_before': item.quantityOnHand
      }),
    ));
    await _log('stock.$movementType',
        warehouseId: item.warehouseId,
        meta: {'item_id': itemId, 'qty': quantity});
  }

  // ── Server pull ───────────────────────────────────────────────────────────

  Future<void> pullFromServer(String warehouseId, {DateTime? since}) async {
    try {
      final params = {
        'warehouse_id': warehouseId,
        if (since != null) 'updated_since': since.toIso8601String()
      };
      final res = await _dio.get('/inventory/', queryParameters: params);
      for (final json in (res.data as List).cast<Map<String, dynamic>>()) {
        await _dao.upsertItem(_itemFromJson(json));
      }
    } on DioException {/* offline */}
  }

  Future<void> _log(String action,
      {required String warehouseId, Map<String, dynamic>? meta}) {
    return _auditDao.insertLog(AuditLogsCompanion.insert(
      id: newUuid(),
      userId: _currentUserId,
      action: action,
      warehouseId: Value(warehouseId),
      metadata: Value(meta != null ? jsonEncode(meta) : null),
      origin: const Value('offline'),
    ));
  }

  Map<String, dynamic> _itemToJson(InventoryItemsCompanion c) => {
        'id': c.id.value,
        'warehouse_id': c.warehouseId.value,
        'name': c.name.value,
        if (c.sku.present) 'sku': c.sku.value,
        if (c.category.present) 'category': c.category.value,
        if (c.unit.present) 'unit': c.unit.value,
        if (c.reorderLevel.present) 'reorder_level': c.reorderLevel.value,
      };

  Map<String, dynamic>? _partialItemJson(InventoryItemsCompanion c) => {
        if (c.name.present) 'name': c.name.value,
        if (c.sku.present) 'sku': c.sku.value,
        if (c.category.present) 'category': c.category.value,
      };

  InventoryItemsCompanion _itemFromJson(Map<String, dynamic> json) {
    return InventoryItemsCompanion.insert(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String,
      name: json['name'] as String,
      sku: Value(json['sku'] as String?),
      category: Value(json['category'] as String?),
      unit: Value(json['unit'] as String? ?? 'pcs'),
      quantityOnHand:
          Value((json['quantity_on_hand'] as num?)?.toDouble() ?? 0),
      reorderLevel: Value((json['reorder_level'] as num?)?.toDouble() ?? 0),
      syncStatus: const Value('synced'),
    );
  }
}

// Note: the live provider for this repository is `inventoryRepoProvider`
// in lib/core/providers/repository_providers.dart.
