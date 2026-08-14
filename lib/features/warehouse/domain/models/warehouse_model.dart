import 'package:warehouse_app/core/database/app_database.dart';

class WarehouseModel {
  final String uuid;
  final String id;
  final String name;
  final String? ownerId;
  final String? gpsLocation;
  final int? amcos;
  final String? amcosName;
  final int? village;
  final String? villageName;
  final bool? synced;
  final String? syncAction;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WarehouseModel({
    required this.uuid,
    required this.id,
    required this.name,
    this.ownerId,
    this.gpsLocation,
    this.amcos,
    this.amcosName,
    this.village,
    this.villageName,
    this.synced,
    this.syncAction,
    this.createdAt,
    this.updatedAt,
  });

  factory WarehouseModel.fromDb(Warehouse warehouse) {
    return WarehouseModel(
      uuid: warehouse.uuid,
      id: warehouse.id,
      name: warehouse.name,
      ownerId: warehouse.ownerId,
      gpsLocation: warehouse.gpsLocation,
      amcos: warehouse.amcos,
      amcosName: warehouse.amcosName,
      village: warehouse.village,
      villageName: warehouse.villageName,
      synced: warehouse.synced,
      syncAction: warehouse.syncAction,
      createdAt: warehouse.createdAt,
      updatedAt: warehouse.updatedAt,
    );
  }

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    return WarehouseModel(
      uuid: _stringFromJson(json, ['uuid', 'UUID']) ?? idValue.toString(),
      id: idValue == null ? '' : idValue.toString(),
      name: _stringFromJson(json, ['name']) ?? '',
      ownerId: _stringFromJson(json, ['mcu', 'ownerId', 'owner_id']),
      gpsLocation:
          _stringFromJson(json, ['gpsLocation', 'gps_location', 'location']),
      amcos: _intFromJson(json, ['amcos']),
      amcosName: _stringFromJson(json, ['amcosName', 'amcos_name']),
      village: _intFromJson(json, ['village']),
      villageName: _stringFromJson(json, ['villageName', 'village_name']),
      synced: json['synced'] as bool? ??
          (json['syncStatus']?.toString() == 'synced'),
      syncAction:
          _stringFromJson(json, ['syncAction', 'sync_action']) ?? 'created',
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  WarehousesCompanion toCompanion({
    String? syncStatus,
    DateTime? updatedAt,
    bool? syncedValue,
  }) {
    return WarehousesCompanion.insert(
      uuid: Value(uuid),
      id: id,
      name: name,
      ownerId: Value(ownerId),
      gpsLocation: Value(gpsLocation),
      amcos: Value(amcos),
      amcosName: Value(amcosName),
      village: Value(village),
      villageName: Value(villageName),
      synced: Value(syncedValue ?? synced ?? false),
      syncAction: Value(syncAction ?? 'created'),
      createdAt: Value(createdAt ?? DateTime.now()),
      syncStatus: Value(syncStatus ?? 'pending'),
      updatedAt: Value(updatedAt ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'id': int.tryParse(id) ?? id,
      'name': name,
      if (ownerId != null) 'mcu': int.tryParse(ownerId!) ?? ownerId,
      if (gpsLocation != null) 'gpsLocation': gpsLocation,
      if (amcos != null) 'amcos': amcos,
      if (amcosName != null) 'amcosName': amcosName,
      if (village != null) 'village': village,
      if (villageName != null) 'villageName': villageName,
      if (synced != null) 'synced': synced,
      if (syncAction != null) 'syncAction': syncAction,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toSyncPayload() {
    return {
      'uuid': uuid,
      'name': name,
      if (ownerId != null) 'mcu': int.tryParse(ownerId!) ?? ownerId,
      if (gpsLocation != null) 'gpsLocation': gpsLocation,
      if (amcos != null) 'amcos': amcos,
      if (amcosName != null) 'amcosName': amcosName,
      if (village != null) 'village': village,
      if (villageName != null) 'villageName': villageName,
    };
  }

  static String? _stringFromJson(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value.toString();
    }
    return null;
  }

  static int? _intFromJson(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }
    return null;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
