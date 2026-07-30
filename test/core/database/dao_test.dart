// test/core/database/dao_test.dart
//
// Phase 1 — DAO unit tests.
// Uses openInMemoryDatabase() so no file I/O and tests run fast.
//
// Run: flutter test test/core/database/dao_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/utils/uuid_helper.dart';
import 'package:warehouse_app/features/additional.data/crop/presentation/providers/crop_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  // ── UserDao ──────────────────────────────────────────────────────────────

  group('UserDao', () {
    test('insert and retrieve a user', () async {
      final id = newUuid();
      await db.userDao.insertUser(
        UsersCompanion.insert(
          id: id,
          name: 'Amina Hassan',
          email: 'amina@example.com',
          role: const Value('manager'),
        ),
      );

      final user = await db.userDao.getUserById(id);
      expect(user, isNotNull);
      expect(user!.name, equals('Amina Hassan'));
      expect(user.email, equals('amina@example.com'));
      expect(user.role, equals('manager'));
      expect(user.syncStatus, equals('pending'));
    });

    test('soft delete sets deletedAt', () async {
      final id = newUuid();
      await db.userDao.insertUser(
        UsersCompanion.insert(
          id: id,
          name: 'Test User',
          email: 'test@example.com',
        ),
      );

      await db.userDao.softDeleteUser(id);

      // watchAllUsers excludes soft-deleted — should be empty.
      final all = await db.userDao.getAllUsers();
      expect(all.where((u) => u.id == id), isEmpty);

      // Direct fetch still finds the row.
      final deleted = await db.userDao.getUserById(id);
      expect(deleted?.deletedAt, isNotNull);
      expect(deleted?.syncStatus, equals('pending'));
    });

    test('markUserSynced updates syncStatus', () async {
      final id = newUuid();
      await db.userDao.insertUser(
        UsersCompanion.insert(
          id: id,
          name: 'Sync User',
          email: 'sync@example.com',
        ),
      );
      await db.userDao.markUserSynced(id);

      final user = await db.userDao.getUserById(id);
      expect(user?.syncStatus, equals('synced'));
    });

    test('watchAllUsers stream emits changes', () async {
      final id = newUuid();

      // Collect first two emissions.
      final emissions = <List<User>>[];
      final sub = db.userDao.watchAllUsers().listen(emissions.add);

      await Future.delayed(Duration.zero); // let stream emit initial []

      await db.userDao.insertUser(
        UsersCompanion.insert(
          id: id,
          name: 'Stream User',
          email: 'stream@example.com',
        ),
      );

      await Future.delayed(Duration.zero); // let stream emit updated list

      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last.any((u) => u.id == id), isTrue);

      await sub.cancel();
    });
  });

  // ── WarehouseDao ─────────────────────────────────────────────────────────

  group('WarehouseDao', () {
    late String ownerId;

    setUp(() async {
      // Warehouses.ownerId has a FK to Users — insert a user first.
      ownerId = newUuid();
      await db.userDao.insertUser(
        UsersCompanion.insert(
          id: ownerId,
          name: 'Owner',
          email: 'owner@example.com',
          role: const Value('owner'),
        ),
      );
    });

    test('insert and retrieve a warehouse', () async {
      final id = newUuid();
      await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(
          id: id,
          name: 'Kariakoo Warehouse',
          ownerId: ownerId,
        ),
      );

      final wh = await db.warehouseDao.getWarehouseById(id);
      expect(wh, isNotNull);
      expect(wh!.name, equals('Kariakoo Warehouse'));
      expect(wh.syncStatus, equals('pending'));
    });

    test('soft delete removes from active list', () async {
      final id = newUuid();
      await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(
          id: id,
          name: 'To Delete',
          ownerId: ownerId,
        ),
      );

      await db.warehouseDao.softDeleteWarehouse(id);
      final all = await db.warehouseDao.getAllWarehouses();
      expect(all.where((w) => w.id == id), isEmpty);
    });
  });

  // ── InventoryDao ─────────────────────────────────────────────────────────

  group('InventoryDao', () {
    late String ownerId;
    late String warehouseId;
    late String workerId;

    setUp(() async {
      ownerId = newUuid();
      warehouseId = newUuid();
      workerId = newUuid();

      await db.userDao.insertUser(
        UsersCompanion.insert(
          id: ownerId,
          name: 'Owner',
          email: 'owner2@example.com',
          role: const Value('owner'),
        ),
      );
      await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(
          id: warehouseId,
          name: 'Test WH',
          ownerId: ownerId,
        ),
      );
      await db.userDao.insertUser(
        UsersCompanion.insert(
          id: workerId,
          name: 'Worker',
          email: 'worker@example.com',
          role: const Value('worker'),
          warehouseId: Value(warehouseId),
        ),
      );
    });

    test('insert item and record movement atomically', () async {
      final itemId = newUuid();
      await db.inventoryDao.insertItem(
        InventoryItemsCompanion.insert(
          id: itemId,
          warehouseId: warehouseId,
          name: 'Cement Bags',
          quantityOnHand: const Value(0),
        ),
      );

      final movementId = newUuid();
      await db.inventoryDao.recordMovement(
        movement: StockMovementsCompanion.insert(
          id: movementId,
          inventoryItemId: itemId,
          warehouseId: warehouseId,
          movementType: 'delivery',
          quantity: 50,
          quantityBefore: 0,
          recordedById: workerId,
        ),
        newQuantity: 50,
      );

      final item = await db.inventoryDao.getItemById(itemId);
      expect(item?.quantityOnHand, equals(50.0));
      expect(item?.syncStatus, equals('pending'));
    });
  });

  // ── SyncQueueDao ──────────────────────────────────────────────────────────

  group('SyncQueueDao', () {
    test('enqueue and dequeue a change', () async {
      final entityId = newUuid();
      await db.syncQueueDao.enqueue(
        SyncQueueCompanion.insert(
          entityType: 'inventoryItems',
          entityId: entityId,
          operation: 'create',
          payload: '{"id":"$entityId","name":"Test Item"}',
        ),
      );

      final batch = await db.syncQueueDao.getNextBatch();
      expect(batch, hasLength(1));
      expect(batch.first.entityId, equals(entityId));
      expect(batch.first.operation, equals('create'));

      // After successful sync, remove from queue.
      await db.syncQueueDao.markSynced(batch.first.id);

      final afterSync = await db.syncQueueDao.getNextBatch();
      expect(afterSync, isEmpty);
    });

    test('pending count stream reflects queue size', () async {
      final counts = <int>[];
      final sub = db.syncQueueDao.watchPendingCount().listen(counts.add);
      await Future.delayed(Duration.zero);

      await db.syncQueueDao.enqueue(
        SyncQueueCompanion.insert(
          entityType: 'warehouses',
          entityId: newUuid(),
          operation: 'update',
          payload: '{}',
        ),
      );
      await Future.delayed(Duration.zero);

      expect(counts.last, equals(1));
      await sub.cancel();
    });
  });

  group('CropProvider', () {
    test('normalizes and removes duplicate crop names', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      await db.cropDao.upsertCrops([
        CropTableCompanion.insert(
          id: const Value(1),
          name: 'MAIZE',
        ),
        CropTableCompanion.insert(
          id: const Value(2),
          name: 'rice',
        ),
        CropTableCompanion.insert(
          id: const Value(3),
          name: 'potato',
        ),
        CropTableCompanion.insert(
          id: const Value(4),
          name: 'RICE',
        ),
        CropTableCompanion.insert(
          id: const Value(5),
          name: 'POTATO',
        ),
      ]);

      await db.harvestDao.upsertCropGrades([
        CropGradesCompanion.insert(
          id: const Value(1),
          crop: 4,
          gradeName: 'Rice grade',
        ),
        CropGradesCompanion.insert(
          id: const Value(2),
          crop: 5,
          gradeName: 'Potato grade',
        ),
      ]);

      final crops = await container.read(allCropsProvider.future);

      expect(crops.map((crop) => crop.name), ['MAIZE', 'POTATO', 'RICE']);
      expect(crops.map((crop) => crop.id), [1, 5, 4]);
    });
  });

  // ── AuditLogDao ───────────────────────────────────────────────────────────

  group('AuditLogDao', () {
    late String userId;
    late String warehouseId;

    setUp(() async {
      userId = newUuid();
      warehouseId = newUuid();

      await db.userDao.insertUser(
        UsersCompanion.insert(
          id: userId,
          name: 'Auditor',
          email: 'audit@example.com',
          role: const Value('owner'),
        ),
      );
      await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(
          id: warehouseId,
          name: 'Audit WH',
          ownerId: userId,
        ),
      );
    });

    test('insert and retrieve an audit log', () async {
      final logId = newUuid();
      await db.auditLogDao.insertLog(
        AuditLogsCompanion.insert(
          id: logId,
          userId: userId,
          action: 'inventory.create',
          warehouseId: Value(warehouseId),
          metadata: const Value('{"item":"Cement Bags"}'),
        ),
      );

      final logs = await db.auditLogDao.getLogsPage(
        warehouseId: warehouseId,
      );
      expect(logs, hasLength(1));
      expect(logs.first.action, equals('inventory.create'));
    });

    test('bulk markLogsSynced', () async {
      final ids = List.generate(3, (_) => newUuid());
      for (final id in ids) {
        await db.auditLogDao.insertLog(
          AuditLogsCompanion.insert(
            id: id,
            userId: userId,
            action: 'test.action',
          ),
        );
      }

      await db.auditLogDao.markLogsSynced(ids);
      final pending = await db.auditLogDao.getPendingLogs();
      expect(pending, isEmpty);
    });
  });
}
