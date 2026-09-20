class WarehouseReportBag {
  const WarehouseReportBag({
    required this.stockBagUuid,
    required this.tagNumber,
    required this.grossWeight,
    required this.packagingWeight,
    required this.netWeight,
    this.previousNetWeight,
    this.netWeightDifference,
    required this.moistureContent,
  });

  factory WarehouseReportBag.fromJson(Map<String, dynamic> json) {
    return WarehouseReportBag(
      stockBagUuid: json['stockBagUuid']?.toString() ?? '',
      tagNumber: json['tagNumber']?.toString() ?? '',
      grossWeight: _double(json['grossWeight']),
      packagingWeight: _double(json['packagingWeight']),
      netWeight: _double(json['netWeight']),
      previousNetWeight: _nullableDouble(json['previousNetWeight']),
      netWeightDifference: _nullableDouble(json['netWeightDifference']),
      moistureContent: _double(json['moistureContent']),
    );
  }

  final String stockBagUuid;
  final String tagNumber;
  final double grossWeight;
  final double packagingWeight;
  final double netWeight;
  final double? previousNetWeight;
  final double? netWeightDifference;
  final double moistureContent;
}

class WarehouseActivityReportRecord {
  const WarehouseActivityReportRecord({
    required this.activityType,
    required this.uuid,
    required this.collectionCenterUuid,
    required this.collectionCenterName,
    required this.crop,
    required this.cropName,
    required this.totalBags,
    this.totalGrossWeight,
    this.totalNetWeight,
    this.workerId,
    required this.workerName,
    required this.activityAt,
    this.farmerName,
    this.farmerPhoneNumber,
    this.receiptNumber,
    this.recipientType,
    this.recipientName,
    this.recipientPhone,
    this.adjustmentType,
    this.reason,
    this.netWeightChange,
    required this.bags,
  });

  factory WarehouseActivityReportRecord.fromJson(Map<String, dynamic> json) {
    final rawBags = json['bags'];
    return WarehouseActivityReportRecord(
      activityType: json['activityType']?.toString() ?? '',
      uuid: json['uuid']?.toString() ?? '',
      collectionCenterUuid: json['collectionCenterUuid']?.toString() ?? '',
      collectionCenterName: json['collectionCenterName']?.toString() ?? '',
      crop: _int(json['crop']),
      cropName: json['cropName']?.toString() ?? '',
      totalBags: _int(json['totalBags']),
      totalGrossWeight: _nullableDouble(json['totalGrossWeight']),
      totalNetWeight: _nullableDouble(json['totalNetWeight']),
      workerId: _nullableInt(json['workerId']),
      workerName: json['workerName']?.toString() ?? '',
      activityAt: DateTime.tryParse(json['activityAt']?.toString() ?? '') ??
          DateTime.now(),
      farmerName: _string(json['farmerName']),
      farmerPhoneNumber: _string(json['farmerPhoneNumber']),
      receiptNumber: _string(json['receiptNumber']),
      recipientType: _string(json['recipientType']),
      recipientName: _string(json['recipientName']),
      recipientPhone: _string(json['recipientPhone']),
      adjustmentType: _string(json['adjustmentType']),
      reason: _string(json['reason']),
      netWeightChange: _nullableDouble(json['netWeightChange']),
      bags: rawBags is List
          ? rawBags
              .whereType<Map>()
              .map((row) => WarehouseReportBag.fromJson(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ))
              .toList()
          : const <WarehouseReportBag>[],
    );
  }

  final String activityType;
  final String uuid;
  final String collectionCenterUuid;
  final String collectionCenterName;
  final int crop;
  final String cropName;
  final int totalBags;
  final double? totalGrossWeight;
  final double? totalNetWeight;
  final int? workerId;
  final String workerName;
  final DateTime activityAt;
  final String? farmerName;
  final String? farmerPhoneNumber;
  final String? receiptNumber;
  final String? recipientType;
  final String? recipientName;
  final String? recipientPhone;
  final String? adjustmentType;
  final String? reason;
  final double? netWeightChange;
  final List<WarehouseReportBag> bags;
}

class WarehouseWorkerReportRecord {
  const WarehouseWorkerReportRecord({
    this.workerId,
    required this.workerName,
    required this.assigned,
    required this.receivingCount,
    required this.receivedBags,
    required this.receivedNetWeight,
    required this.dispatchCount,
    required this.dispatchedBags,
    required this.dispatchedNetWeight,
    required this.adjustmentCount,
    required this.adjustedBags,
    required this.adjustmentNetChange,
    required this.totalActivities,
    this.lastActivityAt,
  });

  factory WarehouseWorkerReportRecord.fromJson(Map<String, dynamic> json) {
    return WarehouseWorkerReportRecord(
      workerId: _nullableInt(json['workerId']),
      workerName: json['workerName']?.toString() ?? '',
      assigned: json['assigned'] == true,
      receivingCount: _int(json['receivingCount']),
      receivedBags: _int(json['receivedBags']),
      receivedNetWeight: _double(json['receivedNetWeight']),
      dispatchCount: _int(json['dispatchCount']),
      dispatchedBags: _int(json['dispatchedBags']),
      dispatchedNetWeight: _double(json['dispatchedNetWeight']),
      adjustmentCount: _int(json['adjustmentCount']),
      adjustedBags: _int(json['adjustedBags']),
      adjustmentNetChange: _double(json['adjustmentNetChange']),
      totalActivities: _int(json['totalActivities']),
      lastActivityAt: DateTime.tryParse(json['lastActivityAt']?.toString() ?? ''),
    );
  }

  final int? workerId;
  final String workerName;
  final bool assigned;
  final int receivingCount;
  final int receivedBags;
  final double receivedNetWeight;
  final int dispatchCount;
  final int dispatchedBags;
  final double dispatchedNetWeight;
  final int adjustmentCount;
  final int adjustedBags;
  final double adjustmentNetChange;
  final int totalActivities;
  final DateTime? lastActivityAt;
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
