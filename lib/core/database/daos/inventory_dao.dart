// lib/core/database/daos/inventory_dao.dart
//
// InventoryDao — covers both InventoryItems and StockMovements.
// These two tables are tightly coupled: every StockMovement also updates
// quantityOnHand on the parent InventoryItem atomically.

import 'package:drift/drift.dart';
import '../app_database.dart';

part 'inventory_dao.g.dart';

@DriftAccessor(tables: [InventoryItems, StockMovements])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  // ── InventoryItem streams ────────────────────────────────────────────────

  /// All active items in a warehouse, ordered by name.
  Stream<List<InventoryItem>> watchItemsByWarehouse(String warehouseId) {
    return (select(inventoryItems)
          ..where(
            (i) =>
                i.warehouseId.equals(warehouseId) &
                i.deletedAt.isNull() &
                i.isActive.isValue(true),
          )
          ..orderBy([(i) => OrderingTerm.asc(i.name)]))
        .watch();
  }

  /// Items at or below their reorder level — used for alerts.
  Stream<List<InventoryItem>> watchLowStockItems(String warehouseId) {
    return (select(inventoryItems)
          ..where(
            (i) =>
                i.warehouseId.equals(warehouseId) &
                i.deletedAt.isNull() &
                i.isActive.isValue(true) &
                i.quantityOnHand.isSmallerOrEqualValue(0),
          ))
        .watch();
  }

  Stream<InventoryItem?> watchItemById(String id) {
    return (select(inventoryItems)..where((i) => i.id.equals(id)))
        .watchSingleOrNull();
  }

  // ── InventoryItem futures ────────────────────────────────────────────────

  Future<List<InventoryItem>> getItemsByWarehouse(String warehouseId) {
    return (select(inventoryItems)
          ..where(
            (i) => i.warehouseId.equals(warehouseId) & i.deletedAt.isNull(),
          ))
        .get();
  }

  Future<InventoryItem?> getItemById(String id) {
    return (select(inventoryItems)..where((i) => i.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<InventoryItem>> getPendingItems() {
    return (select(inventoryItems)
          ..where((i) => i.syncStatus.equals('pending')))
        .get();
  }

  // ── InventoryItem writes ─────────────────────────────────────────────────

  Future<void> insertItem(InventoryItemsCompanion entry) =>
      into(inventoryItems).insert(entry);

  Future<void> upsertItem(InventoryItemsCompanion entry) {
    return into(inventoryItems).insertOnConflictUpdate(entry);
  }

  Future<bool> updateItem(InventoryItemsCompanion entry) {
    return (update(inventoryItems)..where((i) => i.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  Future<void> softDeleteItem(String id) {
    return (update(inventoryItems)..where((i) => i.id.equals(id))).write(
      InventoryItemsCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markItemSynced(String id) {
    return (update(inventoryItems)..where((i) => i.id.equals(id))).write(
      InventoryItemsCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markItemConflict(String id) {
    return (update(inventoryItems)..where((i) => i.id.equals(id))).write(
      InventoryItemsCompanion(
        syncStatus: const Value('conflict'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── StockMovement streams ────────────────────────────────────────────────

  /// All movements for one item, newest first.
  Stream<List<StockMovement>> watchMovementsForItem(String itemId) {
    return (select(stockMovements)
          ..where((m) => m.inventoryItemId.equals(itemId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .watch();
  }

  /// All movements in a warehouse within a date range.
  Stream<List<StockMovement>> watchMovementsByWarehouse(
    String warehouseId, {
    DateTime? from,
    DateTime? to,
  }) {
    return (select(stockMovements)
          ..where((m) {
            var expr = m.warehouseId.equals(warehouseId);
            if (from != null) expr = expr & m.createdAt.isBiggerOrEqualValue(from);
            if (to != null) expr = expr & m.createdAt.isSmallerOrEqualValue(to);
            return expr;
          })
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .watch();
  }

  // ── StockMovement writes — ATOMIC ────────────────────────────────────────

  /// Records a stock movement AND updates quantityOnHand on the parent item
  /// inside a single DB transaction.
  Future<void> recordMovement({
    required StockMovementsCompanion movement,
    required double newQuantity,
  }) {
    return transaction(() async {
      // 1. Insert the movement record.
      await into(stockMovements).insert(movement);

      // 2. Update the item's current quantity + mark as pending sync.
      await (update(inventoryItems)
            ..where((i) => i.id.equals(movement.inventoryItemId.value)))
          .write(
        InventoryItemsCompanion(
          quantityOnHand: Value(newQuantity),
          syncStatus: const Value('pending'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> upsertMovement(StockMovementsCompanion entry) {
    return into(stockMovements).insertOnConflictUpdate(entry);
  }

  Future<void> markMovementSynced(String id) {
    return (update(stockMovements)..where((m) => m.id.equals(id))).write(
      StockMovementsCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<StockMovement>> getPendingMovements() {
    return (select(stockMovements)
          ..where((m) => m.syncStatus.equals('pending')))
        .get();
  }
}