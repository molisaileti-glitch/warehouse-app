// lib/core/database/daos/sync_queue_dao.dart
//
// SyncQueueDao — manages the local outbound sync queue.
// The sync engine reads from this DAO, attempts to push each entry to the
// server, and then either removes it (success) or increments retryCount
// (failure) with exponential-backoff logic handled at the engine level.

import 'package:drift/drift.dart';
import '../app_database.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  // ── Streams ─────────────────────────────────────────────────────────────

  /// Emits the count of pending items — drives the sync indicator badge in UI.
  Stream<int> watchPendingCount() {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)
      ..addColumns([count])
      ..where(syncQueue.syncStatus.equals('pending'));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// All pending entries ordered by creation time (FIFO).
  Stream<List<SyncQueueData>> watchPendingEntries() {
    return (select(syncQueue)
          ..where((q) => q.syncStatus.equals('pending'))
          ..orderBy([
            (q) => OrderingTerm.asc(q.createdAt),
            (q) => OrderingTerm.asc(q.id),
          ]))
        .watch();
  }

  // ── Futures ─────────────────────────────────────────────────────────────

  /// Returns up to [limit] pending entries for the next sync batch.
  ///
  /// Entries are ordered by entity-type dependency priority so that upstream
  /// records (e.g. AMCOS, warehouses, farmers) are always pushed before the
  /// downstream records that reference them (e.g. dependants, harvests).
  /// Within the same entity type, creation order (createdAt, id) is preserved.
  Future<List<SyncQueueData>> getNextBatch({
    int limit = 50,
    Set<String>? entityTypes,
  }) {
    return (select(syncQueue)
          ..where(
            (q) =>
                q.syncStatus.equals('pending') &
                (entityTypes == null
                    ? const Constant(true)
                    : q.entityType.isIn(entityTypes)),
          )
          ..orderBy([
            // Priority order: lower number = pushed first.
            (q) => OrderingTerm.asc(
              const CustomExpression<int>('''
                CASE entity_type
                  WHEN 'amcos'            THEN 1
                  WHEN 'warehouses'       THEN 2
                  WHEN 'users'            THEN 3
                  WHEN 'farmers'          THEN 4
                  WHEN 'farmerDependants' THEN 5
                  WHEN 'farmerHarvests'   THEN 6
                  ELSE                        99
                END'''),
            ),
            (q) => OrderingTerm.asc(q.createdAt),
            (q) => OrderingTerm.asc(q.id),
          ])
          ..limit(limit))
        .get();
  }

  /// Returns all conflict entries that need user resolution.
  Future<List<SyncQueueData>> getConflicts() {
    return (select(syncQueue)..where((q) => q.syncStatus.equals('conflict')))
        .get();
  }

  Future<int> getPendingCount() async {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)
      ..addColumns([count])
      ..where(syncQueue.syncStatus.equals('pending'));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ── Writes ──────────────────────────────────────────────────────────────

  /// Enqueue a new change. Called by repositories whenever a local write
  /// happens while offline (or always — the sync engine deduplicates).
  Future<int> enqueue(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry);

  /// Mark an entry as successfully synced and remove it from the queue.
  Future<void> markSynced(int id) {
    return (delete(syncQueue)..where((q) => q.id.equals(id))).go();
  }

  /// Record a failed attempt — increments retryCount and sets lastAttemptAt.
  Future<void> recordFailure(int id) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: const Value(
          // We read the current value in the sync engine before calling this,
          // so the engine passes the incremented value directly.
          0, // placeholder — engine calls recordFailureWithCount instead.
        ),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  /// Preferred variant: engine passes the new retryCount explicitly.
  Future<void> recordFailureWithCount(int id, int newRetryCount) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(newRetryCount),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark an entry as conflicted — needs user resolution.
  Future<void> markConflict(int id) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      const SyncQueueCompanion(syncStatus: Value('conflict')),
    );
  }

  /// Remove all synced entries (house-keeping, run periodically).
  Future<void> purgeSync() {
    return (delete(syncQueue)..where((q) => q.syncStatus.equals('synced')))
        .go();
  }

  /// Reset 'conflict' entries back to 'pending' so they are retried on the
  /// next sync. Called at app startup to recover entries that were wrongly
  /// moved to conflict by a previous version of the sync logic (which treated
  /// 400/422 HTTP errors as permanent conflicts instead of retryable failures).
  Future<void> resetConflictsToPending() {
    return (update(syncQueue)..where((q) => q.syncStatus.equals('conflict')))
        .write(
      const SyncQueueCompanion(
        syncStatus: Value('pending'),
        retryCount: Value(0),
      ),
    );
  }

  /// Clear the entire queue — called on logout.
  Future<void> clearAll() => delete(syncQueue).go();
}
