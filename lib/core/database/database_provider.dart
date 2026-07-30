// lib/core/database/database_provider.dart
//
// Riverpod providers for the database and all DAOs.
// Import this file wherever you need DB access.
//
// Why a plain Provider (not AsyncNotifier)?
//   AppDatabase construction is synchronous — it only opens the file handle.
//   The actual connection is lazy (first query). No need for AsyncNotifier.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

// ── Root database provider ────────────────────────────────────────────────

/// The single AppDatabase instance for the lifetime of the app.
/// Override in tests:
///
///   final container = ProviderContainer(
///     overrides: [
///       appDatabaseProvider.overrideWithValue(openInMemoryDatabase()),
///     ],
///   );
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) {
    final db = AppDatabase();
    // Dispose the DB connection when the provider is removed (e.g. in tests).
    ref.onDispose(db.close);
    return db;
  },
  // Keep alive for the full app lifecycle.
  name: 'appDatabase',
);

// ── DAO providers ─────────────────────────────────────────────────────────
// Each DAO is derived from the database — no separate lifecycle needed.

final workerDaoProvider = Provider<WorkerDao>(
  (ref) => ref.watch(appDatabaseProvider).workerDao,
  name: 'workerDao',
);

final warehouseDaoProvider = Provider<WarehouseDao>(
  (ref) => ref.watch(appDatabaseProvider).warehouseDao,
  name: 'warehouseDao',
);

final inventoryDaoProvider = Provider<InventoryDao>(
  (ref) => ref.watch(appDatabaseProvider).inventoryDao,
  name: 'inventoryDao',
);

final syncQueueDaoProvider = Provider<SyncQueueDao>(
  (ref) => ref.watch(appDatabaseProvider).syncQueueDao,
  name: 'syncQueueDao',
);

final auditLogDaoProvider = Provider<AuditLogDao>(
  (ref) => ref.watch(appDatabaseProvider).auditLogDao,
  name: 'auditLogDao',
);

final regionDaoProvider = Provider<RegionDao>(
  (ref) => ref.watch(appDatabaseProvider).regionDao,
  name: 'regionDao',
);

final districtDaoProvider = Provider<DistrictDao>(
  (ref) => ref.watch(appDatabaseProvider).districtDao,
  name: 'districtDao',
);

final wardDaoProvider = Provider<WardDao>(
  (ref) => ref.watch(appDatabaseProvider).wardDao,
  name: 'wardDao',
);

final villageDaoProvider = Provider<VillageDao>(
  (ref) => ref.watch(appDatabaseProvider).villageDao,
  name: 'villageDao',
);

final amcosDaoProvider = Provider<AmcosDao>(
  (ref) => ref.watch(appDatabaseProvider).amcosDao,
  name: 'amcosDao',
);

final cropDaoProvider = Provider<CropDao>(
  (ref) => ref.watch(appDatabaseProvider).cropDao,
  name: 'cropDao',
);

final farmerDaoProvider = Provider<FarmerDao>(
  (ref) => ref.watch(appDatabaseProvider).farmerDao,
  name: 'farmerDao',
);

final harvestDaoProvider = Provider<HarvestDao>(
  (ref) => ref.watch(appDatabaseProvider).harvestDao,
  name: 'harvestDao',
);
