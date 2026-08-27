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
      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: id,
          fullName: 'Amina Hassan',
          email: 'amina@example.com',
          role: const Value('manager'),
        ),
      );

      final user = await db.workerDao.getUserById(id);
      expect(user, isNotNull);
      expect(user!.fullName, equals('Amina Hassan'));
      expect(user.email, equals('amina@example.com'));
      expect(user.role, equals('manager'));
      expect(user.syncStatus, equals('pending'));
    });

    test('soft delete sets deletedAt', () async {
      final id = newUuid();
      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: id,
          fullName: 'Test User',
          email: 'test@example.com',
        ),
      );

      await db.workerDao.softDeleteUser(id);

      // watchAllUsers excludes soft-deleted — should be empty.
      final all = await db.workerDao.getAllUsers();
      expect(all.where((u) => u.id == id), isEmpty);

      // Direct fetch still finds the row.
      final deleted = await db.workerDao.getUserById(id);
      expect(deleted?.deletedAt, isNotNull);
      expect(deleted?.syncStatus, equals('pending'));
    });

    test('markUserSynced updates syncStatus', () async {
      final id = newUuid();
      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: id,
          fullName: 'Sync User',
          email: 'sync@example.com',
        ),
      );
      await db.workerDao.markUserSynced(id);

      final user = await db.workerDao.getUserById(id);
      expect(user?.syncStatus, equals('synced'));
    });

    test('watchAllUsers stream emits changes', () async {
      final id = newUuid();

      // Collect first two emissions.
      final emissions = <List<User>>[];
      final sub = db.workerDao.watchAllUsers().listen(emissions.add);

      await Future.delayed(Duration.zero); // let stream emit initial []

      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: id,
          fullName: 'Stream User',
          email: 'stream@example.com',
        ),
      );

      await Future.delayed(Duration.zero); // let stream emit updated list

      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last.any((u) => u.id == id), isTrue);

      await sub.cancel();
    });

    test('pending user and sync entry are stored together', () async {
      final id = newUuid();
      await db.workerDao.insertPendingUser(
        user: UsersCompanion.insert(
          id: id,
          fullName: 'Offline Worker',
          email: 'offline-worker@example.com',
        ),
        queueEntry: SyncQueueCompanion.insert(
          entityType: 'users',
          entityId: id,
          operation: 'create',
          payload: '{}',
        ),
      );

      expect(await db.workerDao.getUserById(id), isNotNull);
      final queue = await db.syncQueueDao.getNextBatch();
      expect(queue.single.entityId, id);
      expect(queue.single.entityType, 'users');
    });
  });

  // ── WarehouseDao ─────────────────────────────────────────────────────────

  group('WarehouseDao', () {
    late String ownerId;

    setUp(() async {
      // Warehouses.ownerId has a FK to Users — insert a user first.
      ownerId = newUuid();
      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: ownerId,
          fullName: 'Owner',
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
          ownerId: Value(ownerId),
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
          ownerId: Value(ownerId),
        ),
      );

      await db.warehouseDao.softDeleteWarehouse(id);
      final all = await db.warehouseDao.getAllWarehouses();
      expect(all.where((w) => w.id == id), isEmpty);
    });

    test('pending warehouse and sync entry are stored together', () async {
      final id = newUuid();
      await db.warehouseDao.insertPendingWarehouse(
        warehouse: WarehousesCompanion.insert(
          id: id,
          name: 'Offline Warehouse',
          ownerId: Value(ownerId),
        ),
        queueEntry: SyncQueueCompanion.insert(
          entityType: 'warehouses',
          entityId: id,
          operation: 'create',
          payload: '{}',
        ),
      );

      expect(await db.warehouseDao.getWarehouseById(id), isNotNull);
      final queue = await db.syncQueueDao.getNextBatch();
      expect(queue.single.entityId, id);
      expect(queue.single.entityType, 'warehouses');
    });

    test('downloaded warehouse can insert before reference sync', () async {
      await db.warehouseDao.ensureWarehouseReferences(
        amcosId: 5,
        amcosName: 'Jkkh',
        mcu: 2,
        mcuName: 'ghgjy',
        villageId: 6004,
        villageName: 'NGULU',
      );

      await db.warehouseDao.upsertWarehouse(
        WarehousesCompanion.insert(
          uuid: const Value('57342846-ad93-4acd-9cf5-6d0f36b4fdc9'),
          id: '13',
          name: 'going home',
          ownerId: const Value('2'),
          gpsLocation: const Value('KILIMANJARO, MWANGA, KWAKOA, NGULU'),
          amcos: const Value(5),
          amcosName: const Value('Jkkh'),
          village: const Value(6004),
          villageName: const Value('NGULU'),
          syncStatus: const Value('synced'),
          synced: const Value(true),
        ),
      );

      final warehouse = await db.warehouseDao.getWarehouseById('13');
      final amcos = await db.amcosDao.getAmcosById(5);
      final village = await db.villageDao.getVillageById(6004);

      expect(warehouse?.name, 'going home');
      expect(amcos?.name, 'Jkkh');
      expect(village?.name, 'NGULU');
    });

    test('server warehouse id replaces local uuid and keeps references',
        () async {
      final localId = newUuid();
      const serverId = '13';

      await db.warehouseDao.ensureWarehouseReferences(
        amcosId: 5,
        amcosName: 'Jkkh',
        mcu: 2,
        mcuName: 'ghgjy',
        villageId: 6004,
        villageName: 'NGULU',
      );
      await db.cropDao.upsertCrops([
        CropTableCompanion.insert(
          id: const Value(4),
          name: 'MAIZE',
        ),
      ]);
      await db.farmerDao.upsertFarmer(
        FarmersCompanion.insert(
          id: const Value(100),
          serverId: const Value(100),
          firstName: 'John',
          lastName: 'Msuya',
          sex: 'MALE',
          idType: 'NIN',
          idNumber: '123',
          dob: '1990-01-01',
          phoneNumber: '0754000000',
          mainCrop: 4,
          secondaryCrop: 4,
          amcos: 5,
          mcu: 2,
          memberType: '',
          maritalStatus: '',
          uuid: const Value('farmer-uuid-100'),
        ),
      );
      await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(
          uuid: Value(localId),
          id: localId,
          name: 'Offline Warehouse',
          ownerId: Value(ownerId),
          amcos: const Value(5),
          village: const Value(6004),
          synced: const Value(false),
          syncStatus: const Value('pending'),
        ),
      );
      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: 'worker-1',
          fullName: 'Worker One',
          email: 'worker1@example.com',
          role: const Value('AMCOS_USER'),
          warehouseId: Value(localId),
        ),
      );
      await db.inventoryDao.insertItem(
        InventoryItemsCompanion.insert(
          id: 'item-1',
          warehouseId: localId,
          name: 'Maize stock',
        ),
      );
      await db.inventoryDao.recordMovement(
        movement: StockMovementsCompanion.insert(
          id: 'movement-1',
          inventoryItemId: 'item-1',
          warehouseId: localId,
          movementType: 'receive',
          quantity: 10,
          quantityBefore: 0,
          recordedById: 'worker-1',
          relatedWarehouseId: Value(localId),
        ),
        newQuantity: 10,
      );
      await db.auditLogDao.insertLog(
        AuditLogsCompanion.insert(
          id: 'audit-1',
          userId: ownerId,
          action: 'warehouse.create',
          warehouseId: Value(localId),
        ),
      );
      await db.harvestDao.insertHarvestWithBags(
        harvest: FarmerHarvestsCompanion.insert(
          uuid: 'harvest-1',
          farmer: 100,
          farmerUuid: const Value('farmer-uuid-100'),
          farmerName: 'John Msuya',
          farmerPhoneNumber: '0754000000',
          grossWeight: 82,
          netWeight: 81,
          packagingWeight: 1,
          moistureContent: 1,
          receiptNumber: 'RCPT-1',
          crop: 4,
          cropName: 'MAIZE',
          warehouseId: localId,
          collectionCenter: const Value(null),
          collectionCenterName: 'Offline Warehouse',
        ),
        bags: const [],
      );
      await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(
          uuid: Value(localId),
          id: serverId,
          name: 'Duplicate Server Warehouse',
          ownerId: const Value('2'),
          amcos: const Value(5),
          village: const Value(6004),
          synced: const Value(true),
          syncStatus: const Value('synced'),
        ),
      );

      expect((await db.warehouseDao.getAllWarehouses()).length, 2);
      expect((await db.warehouseDao.getWarehouseByUuid(localId))?.id, localId);

      await db.warehouseDao.reconcileWarehouseId(
        localId: localId,
        serverWarehouse: WarehousesCompanion.insert(
          uuid: Value(localId),
          id: serverId,
          name: 'Offline Warehouse',
          ownerId: const Value('2'),
          amcos: const Value(5),
          village: const Value(6004),
          synced: const Value(true),
          syncStatus: const Value('synced'),
        ),
      );

      expect(await db.warehouseDao.getWarehouseById(localId), isNull);
      expect(await db.warehouseDao.getWarehouseById(serverId), isNotNull);
      expect((await db.warehouseDao.getAllWarehouses()).length, 1);
      expect(
          (await db.workerDao.getUserById('worker-1'))?.warehouseId, serverId);
      expect(
          (await db.inventoryDao.getItemById('item-1'))?.warehouseId, serverId);
      final harvest = await db.harvestDao.getHarvestByUuid('harvest-1');
      expect(harvest?.warehouseId, serverId);
      expect(harvest?.collectionCenter, int.parse(serverId));
      final auditLogs = await db.auditLogDao.getLogsPage(
        warehouseId: serverId,
      );
      expect(auditLogs.single.id, 'audit-1');
    });

    test('downloaded AMCOS can insert before full location sync', () async {
      await db.amcosDao.ensureAmcosReferences(
        regionId: 2,
        regionName: 'DAR-ES-SALAAM',
        districtId: 10,
        districtName: 'KINONDONI',
        wardId: 215,
        wardName: 'KAWE',
        villageId: 793,
        villageName: 'UKWAMANI',
      );

      await db.amcosDao.upsertAmcos(
        AmcosTableCompanion.insert(
          id: const Value(7),
          name: 'Ukwamani',
          memberCategory: 'FARMERS',
          registrationNumber: 'kawr/2447',
          tinNumber: '33558542222',
          mcu: 5,
          mcuName: 'RICE SHOP',
          region: 2,
          regionName: 'DAR-ES-SALAAM',
          district: 10,
          districtName: 'KINONDONI',
          ward: 215,
          wardName: 'KAWE',
          village: 793,
          villageName: 'UKWAMANI',
          phoneNumber: '0672020998',
          email: 'fadhili68@gmail.com',
          contactPersonName: 'Fadhili',
          contactPersonPhoneNumber: '0672020998',
          contactPersonEmail: 'fadhili68@gmail.com',
          contactPersonTitle: 'busness',
          website: 'Michele.tz',
          status: 'ACTIVE',
          crops: '4',
          idCounter: 1,
        ),
      );

      final amcos = await db.amcosDao.getAmcosById(7);
      final village = await db.villageDao.getVillageById(793);

      expect(amcos?.name, 'Ukwamani');
      expect(village?.name, 'UKWAMANI');
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

      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: ownerId,
          fullName: 'Owner',
          email: 'owner2@example.com',
          role: const Value('owner'),
        ),
      );
      await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(
          id: warehouseId,
          name: 'Test WH',
          ownerId: Value(ownerId),
        ),
      );
      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: workerId,
          fullName: 'Worker',
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

      await db.workerDao.insertUser(
        UsersCompanion.insert(
          id: userId,
          fullName: 'Auditor',
          email: 'audit@example.com',
          role: const Value('owner'),
        ),
      );
      await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(
          id: warehouseId,
          name: 'Audit WH',
          ownerId: Value(userId),
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
