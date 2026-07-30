// lib/core/enums/sync_status.dart
//
// Shared enums for the entire app.
// Keep this file free of Flutter / Drift imports so it can be used
// anywhere without pulling in the whole dependency graph.

/// Tracks the sync lifecycle of every local record.
enum SyncStatus {
  /// Record was created/modified offline and has not been sent to the server.
  pending,

  /// Record has been successfully confirmed by the server.
  synced,

  /// The server returned a conflicting version; needs resolution.
  conflict,
}

/// The roles in the system.
/// Stored as a plain string in the DB (e.g. 'owner', 'worker', 'superAdmin').
enum UserRole {
  owner,
  worker,
  superAdmin;

  static UserRole fromString(String value) {
    final lower = value.toLowerCase();
    if (lower == "mcu_admin" || lower == 'super_admin' || lower == 'superadmin' || lower == 'admin') {
      return UserRole.superAdmin;
    }
    return UserRole.values.firstWhere(
      (r) => r.name.toLowerCase() == lower,
      orElse: () => UserRole.worker,
    );
  }
}

/// Type of change stored in the sync queue.
enum ChangeOperation {
  create,
  update,
  delete;

  static ChangeOperation fromString(String value) {
    return ChangeOperation.values.firstWhere(
      (o) => o.name == value,
      orElse: () => ChangeOperation.update,
    );
  }
}

/// Tables that can have pending sync changes.
enum SyncEntity {
  user,
  warehouse,
  inventoryItem,
  stockMovement,
  auditLog;

  static SyncEntity fromString(String value) {
    return SyncEntity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncEntity.inventoryItem,
    );
  }
}
