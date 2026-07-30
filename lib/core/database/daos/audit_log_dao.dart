// lib/core/database/daos/audit_log_dao.dart
//
// AuditLogDao — append-only. Audit rows are never edited or soft-deleted
// locally (they are immutable records of history). The sync engine pushes
// them to the server once connectivity is available.

import 'package:drift/drift.dart';
import '../app_database.dart';

part 'audit_log_dao.g.dart';

@DriftAccessor(tables: [AuditLogs])
class AuditLogDao extends DatabaseAccessor<AppDatabase>
    with _$AuditLogDaoMixin {
  AuditLogDao(super.db);

  // ── Streams ─────────────────────────────────────────────────────────────

  /// All audit logs for a warehouse, newest first.
  Stream<List<AuditLog>> watchLogsByWarehouse(String warehouseId) {
    return (select(auditLogs)
          ..where((l) => l.warehouseId.equals(warehouseId))
          ..orderBy([(l) => OrderingTerm.desc(l.createdAt)]))
        .watch();
  }

  /// Logs for a specific user.
  Stream<List<AuditLog>> watchLogsByUser(String userId) {
    return (select(auditLogs)
          ..where((l) => l.userId.equals(userId))
          ..orderBy([(l) => OrderingTerm.desc(l.createdAt)]))
        .watch();
  }

  // ── Futures ─────────────────────────────────────────────────────────────

  /// Paged query — returns [pageSize] rows starting at [offset].
  Future<List<AuditLog>> getLogsPage({
    String? warehouseId,
    int pageSize = 50,
    int offset = 0,
  }) {
    return (select(auditLogs)
          ..where((l) {
            if (warehouseId != null) return l.warehouseId.equals(warehouseId);
            return const Constant(true);
          })
          ..orderBy([(l) => OrderingTerm.desc(l.createdAt)])
          ..limit(pageSize, offset: offset))
        .get();
  }

  /// All logs not yet synced to the server.
  Future<List<AuditLog>> getPendingLogs() {
    return (select(auditLogs)
          ..where((l) => l.syncStatus.equals('pending')))
        .get();
  }

  // ── Writes ──────────────────────────────────────────────────────────────

  /// Append a new audit entry. Never updates existing rows.
  Future<void> insertLog(AuditLogsCompanion entry) =>
      into(auditLogs).insert(entry);

  /// Upsert used only during sync pull (server may send logs we don't have).
  Future<void> upsertLog(AuditLogsCompanion entry) {
    return into(auditLogs).insertOnConflictUpdate(entry);
  }

  /// Mark as synced once the server confirms receipt.
  Future<void> markLogSynced(String id) {
    return (update(auditLogs)..where((l) => l.id.equals(id))).write(
      AuditLogsCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Bulk mark synced — used after a successful batch push.
  Future<void> markLogsSynced(List<String> ids) {
    return (update(auditLogs)..where((l) => l.id.isIn(ids))).write(
      AuditLogsCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}