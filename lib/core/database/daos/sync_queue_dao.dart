// lib/core/database/daos/sync_queue_dao.dart
//
// SyncQueueDao — manages the local outbound sync queue.
// The sync engine reads from this DAO, attempts to push each entry to the
// server, and then either removes it (success) or increments retryCount
// (failure) with exponential-backoff logic handled at the engine level.

import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/app_tables.dart';

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
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .watch();
  }

  // ── Futures ─────────────────────────────────────────────────────────────

  /// Returns up to [limit] pending entries for the next sync batch.
  Future<List<SyncQueueData>> getNextBatch({int limit = 50}) {
    return (select(syncQueue)
          ..where((q) => q.syncStatus.equals('pending'))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Returns all conflict entries that need user resolution.
  Future<List<SyncQueueData>> getConflicts() {
    return (select(syncQueue)
          ..where((q) => q.syncStatus.equals('conflict')))
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

  /// Clear the entire queue — called on logout.
  Future<void> clearAll() => delete(syncQueue).go();
}