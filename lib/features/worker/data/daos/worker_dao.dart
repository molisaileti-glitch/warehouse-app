// lib/features/worker/data/daos/worker_dao.dart
//
// UserDao — all local DB operations for the Users table.
// Exposes both Future (one-shot) and Stream (reactive) methods.

import 'package:drift/drift.dart';
import 'package:warehouse_app/core/database/app_database.dart';

part 'worker_dao.g.dart';

@DriftAccessor(tables: [Users, SyncQueue])
class WorkerDao extends DatabaseAccessor<AppDatabase> with _$WorkerDaoMixin {
  WorkerDao(super.db);

  // ── Streams (reactive — UI rebuilds automatically) ──────────────────────

  /// Emits the full user list whenever any row changes.
  /// Excludes soft-deleted records.
  Stream<List<User>> watchAllUsers() {
    return (select(users)
          ..where((u) => u.deletedAt.isNull())
          ..orderBy([(u) => OrderingTerm.asc(u.fullName)]))
        .watch();
  }

  /// Emits users belonging to a specific warehouse.
  Stream<List<User>> watchUsersByWarehouse(String warehouseId) {
    return (select(users)
          ..where(
            (u) => u.warehouseId.equals(warehouseId) & u.deletedAt.isNull(),
          ))
        .watch();
  }

  /// Watches a single user by UUID.
  Stream<User?> watchUserById(String id) {
    return (select(users)..where((u) => u.id.equals(id))).watchSingleOrNull();
  }

  // ── Futures (one-shot queries) ──────────────────────────────────────────

  /// Returns all non-deleted users.
  Future<List<User>> getAllUsers() {
    return (select(users)
          ..where((u) => u.deletedAt.isNull())
          ..orderBy([(u) => OrderingTerm.asc(u.fullName)]))
        .get();
  }

  /// Returns a single user or null.
  Future<User?> getUserById(String id) {
    return (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  /// Returns a user by email (for login look-ups).
  Future<User?> getUserByEmail(String email) {
    return (select(users)..where((u) => u.email.equals(email)))
        .getSingleOrNull();
  }

  Future<void> deleteUserById(String id) {
    return (delete(users)..where((u) => u.id.equals(id))).go();
  }

  /// Returns all users whose sync_status is 'pending'.
  Future<List<User>> getPendingUsers() {
    return (select(users)..where((u) => u.syncStatus.equals('pending'))).get();
  }

  // ── Writes ──────────────────────────────────────────────────────────────

  /// Insert a new user. Caller must supply a UUID v4 `id`.
  Future<void> insertUser(UsersCompanion entry) => into(users).insert(entry);

  /// Upsert — insert or replace on conflict (used during sync pull).
  Future<void> upsertUser(UsersCompanion entry) {
    return into(users).insertOnConflictUpdate(entry);
  }

  Future<void> insertPendingUser({
    required UsersCompanion user,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await into(users).insertOnConflictUpdate(user);
      await into(syncQueue).insert(queueEntry);
    });
  }

  /// Update an existing user by UUID.
  Future<bool> updateUser(UsersCompanion entry) {
    return (update(users)..where((u) => u.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  Future<void> setUserWarehouse({
    required String id,
    required String warehouseId,
  }) {
    return (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        warehouseId: Value(warehouseId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updatePendingUser({
    required UsersCompanion user,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await (update(users)..where((item) => item.id.equals(user.id.value)))
          .write(user);
      await into(syncQueue).insert(queueEntry);
    });
  }

  /// Soft-delete: sets deleted_at and marks sync_status = 'pending'.
  Future<void> softDeleteUser(String id) {
    return (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deletePendingUser({
    required String id,
    required SyncQueueCompanion queueEntry,
  }) {
    return transaction(() async {
      await (update(users)..where((item) => item.id.equals(id))).write(
        UsersCompanion(
          deletedAt: Value(DateTime.now()),
          syncStatus: const Value('pending'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await into(syncQueue).insert(queueEntry);
    });
  }

  /// Mark a user as synced after the server confirms.
  Future<void> markUserSynced(String id) {
    return (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark a user as conflicted — needs resolution.
  Future<void> markUserConflict(String id) {
    return (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        syncStatus: const Value('conflict'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
