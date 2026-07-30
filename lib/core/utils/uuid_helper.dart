// lib/core/utils/uuid_helper.dart
//
// Central UUID utility so every part of the app generates IDs the same way.
// Using uuid v4 (random) — safe to generate offline without coordination.

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a new UUID v4 string.
/// Call this whenever creating a new local record:
///
///   final id = newUuid();
///   await db.warehouseDao.insertWarehouse(
///     WarehousesCompanion.insert(id: id, name: 'Dar Main', ...),
///   );
String newUuid() => _uuid.v4();

/// Validate that a string looks like a UUID v4.
bool isValidUuid(String value) {
  // Simple regex — sufficient for client-side guard checks.
  const pattern =
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
  return RegExp(pattern, caseSensitive: false).hasMatch(value);
}