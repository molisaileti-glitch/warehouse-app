# Sync Fix & Offline AMCOS Support — Implementation Plan

## Goal Description

The app is local-first, but several gaps in sync logic and backend API changes are causing failures. Additionally, **AMCOS** (Agricultural Marketing Co-operative Societies) are now created offline in the app, which requires treating them as first-class syncable entities that other records (Farmers, Harvests) depend on.

This plan addresses:
1.  **Offline-created AMCOS**: Adding UUID/Sync support and ensuring they are pushed before dependent entities.
2.  **Farmer/Dependant Sync**: Adding missing `uuid` and `syncStatus` columns to track registration state.
3.  **Sync Engine Robustness**: Enforcing push ordering and resolving local IDs to server IDs in payloads.
4.  **Backend Gaps**: Linking farmers by `amcosMemberID` when UUIDs are missing on the server.

---

## User Review Required

> [!IMPORTANT]
> **AMCOS ID Conflict**: We will follow the existing project pattern of using negative integers derived from UUIDs for local-only IDs. This ensures `id` remains the primary key while allowing offline creation.
> **Sync Ordering**: AMCOS will be pushed first, followed by Warehouses, Users, Farmers, Dependants, and finally Harvests.

---

## Proposed Changes

### Core Database & Schema (v12)

#### [MODIFY] [`amcos_table.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/features/additional.data/amcos/data/tables/amcos_table.dart)
Add `uuid` (text) and `syncStatus` (text) to `AmcosTable`. We will not use `SyncMixin` here to avoid adding `createdAt`/`updatedAt` if they aren't needed, but will ensure consistency with the `Syncable` pattern. Actually, using `SyncMixin` is safer for the sync engine.

#### [MODIFY] [`farmer_tables.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/features/farmer/data/tables/farmer_tables.dart)
- `Farmers`: Add `syncStatus` column.
- `FarmerDependants`: Add `uuid` and `syncStatus` columns.

#### [MODIFY] [`app_database.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/core/database/app_database.dart)
Bump `schemaVersion` to **12**.
Implement migration:
- `ALTER TABLE amcos ADD COLUMN uuid TEXT`
- `ALTER TABLE amcos ADD COLUMN sync_status TEXT DEFAULT 'synced'`
- `ALTER TABLE farmers ADD COLUMN sync_status TEXT DEFAULT 'synced'`
- `ALTER TABLE farmer_dependants ADD COLUMN uuid TEXT`
- `ALTER TABLE farmer_dependants ADD COLUMN sync_status TEXT DEFAULT 'synced'`
- Initialize `sync_status = 'pending'` for any local records (those with negative IDs).

---

### Data Access Objects (DAOs)

#### [MODIFY] [`amcos_dao.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/features/additional.data/amcos/data/daos/amcos_dao.dart)
Add:
- `getAmcosByUuid(String uuid)`
- `markAmcosSynced(String uuid, int serverId)`
- `insertPendingAmcos(...)` for offline creation.

#### [MODIFY] [`farmer_dao.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/features/farmer/data/daos/farmer_dao.dart)
Add:
- `markFarmerSynced(String uuid)`
- `markDependantSynced(String uuid)`

#### [MODIFY] [`sync_queue_dao.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/core/database/daos/sync_queue_dao.dart)
Update `getNextBatch` to order by entity-type priority:
`amcos → warehouses → users → farmers → farmerDependants → farmerHarvests`

---

### Repositories

#### [MODIFY] [`amcos_repository.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/features/additional.data/amcos/data/repositories/amcos_repository.dart)
Refactor `create` to be local-first:
1. Generate UUID.
2. Generate negative local ID.
3. Call `_dao.insertPendingAmcos`.
4. Enqueue `create` operation in `syncQueue`.

#### [MODIFY] [`drift_farmer_repository.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/features/farmer/data/repositories/drift_farmer_repository.dart)
Ensure `FarmerDependantModel` is created with a generated UUID and passed to the DAO.

#### [MODIFY] [`drift_harvest_repository.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/features/harvest/data/repositories/drift_harvest_repository.dart)
In `pullFromServer`, add fallback to look up farmer by `farmer` (UUID) if `serverId` lookup fails.

---

### Sync Engine

#### [MODIFY] [`sync_engine.dart`](file:///d:/projects/ShambaBora/shambabora_mobile/lib/core/sync/sync_engine.dart)
- Add `'amcos'` to `_syncableEntityTypes`.
- Update `_pushEntry`:
    - Case `'amcos'`: Post to `/amcos`, then call `_applyAmcosCreateResponse`.
    - Case `'farmers'`: Resolve `amcos` local ID to server ID.
    - Case `'farmerHarvests'`: Resolve `amcos` local ID to server ID.
- Update `_markEntitySynced` and `_markEntityConflict` to handle `'amcos'`, `'farmers'`, and `'farmerDependants'`.
- Implement `_resolveAmcosServerId(int localId)` utility.

---

## Verification Plan

### Automated Tests
- Run `flutter pub run build_runner build --delete-conflicting-outputs` to verify schema regeneration.
- (Optional) Unit tests for `SyncQueueDao` ordering if test harness exists.

### Manual Verification
1.  **Offline AMCOS Flow**:
    - Create AMCOS offline → Create Farmer for that AMCOS → Create Harvest.
    - Run Sync → Verify AMCOS pushes first → Farmer uses server AMCOS ID → Harvest uses server AMCOS ID.
2.  **Dependant Sync**:
    - Register farmer with dependants offline → Sync → Verify dependants are linked correctly on server using server `farmerId`.
3.  **Harvest Pull**:
    - Pull a harvest for a farmer that was recently synced (no UUID on backend yet) → Verify it links to local farmer correctly via fallback.
