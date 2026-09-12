class WarehouseRecipientType {
  static const buyer = 'BUYER';
  static const farmer = 'FARMER';
  static const other = 'OTHER';

  static const values = [buyer, farmer, other];
}

class StockAdjustmentType {
  static const increase = 'INCREASE';
  static const decrease = 'DECREASE';

  static const values = [increase, decrease];
}

class StockAdjustmentReason {
  static const damagedStock = 'DAMAGED_STOCK';
  static const missingStock = 'MISSING_STOCK';
  static const moistureLoss = 'MOISTURE_LOSS';
  static const correction = 'CORRECTION';
  static const other = 'OTHER';

  static const values = [
    damagedStock,
    missingStock,
    moistureLoss,
    correction,
    other,
  ];
}

class WarehouseOperationBagDraft {
  final String? stockBagUuid;
  final String? tagNumber;
  final double? recordedGrossWeight;
  final double? recordedPackagingWeight;
  final double? recordedNetWeight;
  final double grossWeight;
  final double packagingWeight;
  final double netWeight;
  final double moistureContent;

  const WarehouseOperationBagDraft({
    this.stockBagUuid,
    this.tagNumber,
    this.recordedGrossWeight,
    this.recordedPackagingWeight,
    this.recordedNetWeight,
    required this.grossWeight,
    required this.packagingWeight,
    required this.netWeight,
    required this.moistureContent,
  });
}

class StockBag {
  final int? id;
  final String uuid;
  final String tagNumber;
  final int crop;
  final String cropName;
  final double grossWeight;
  final double packagingWeight;
  final double loadWeight;
  final double netWeight;
  final double moistureContent;
  final String status;

  const StockBag({
    this.id,
    required this.uuid,
    required this.tagNumber,
    required this.crop,
    required this.cropName,
    required this.grossWeight,
    required this.packagingWeight,
    required this.loadWeight,
    required this.netWeight,
    required this.moistureContent,
    required this.status,
  });

  factory StockBag.fromJson(Map<String, dynamic> json) {
    return StockBag(
      id: _int(json['id']),
      uuid: json['uuid']?.toString() ?? '',
      tagNumber: json['tagNumber']?.toString() ?? '',
      crop: _int(json['crop']) ?? 0,
      cropName: json['cropName']?.toString() ?? '',
      grossWeight: _double(json['grossWeight']),
      packagingWeight: _double(json['packagingWeight']),
      loadWeight: _double(json['loadWeight']),
      netWeight: _double(json['netWeight']),
      moistureContent: _double(json['moistureContent']),
      status: json['status']?.toString() ?? '',
    );
  }
}

class WarehouseOperationBag {
  final int? id;
  final String uuid;
  final String operationUuid;
  final String stockBagUuid;
  final String tagNumber;
  final int? bagNumber;
  final double grossWeight;
  final double packagingWeight;
  final double loadWeight;
  final double netWeight;
  final double moistureContent;
  final DateTime? measuredAt;
  final String status;

  const WarehouseOperationBag({
    this.id,
    required this.uuid,
    required this.operationUuid,
    required this.stockBagUuid,
    required this.tagNumber,
    this.bagNumber,
    required this.grossWeight,
    required this.packagingWeight,
    required this.loadWeight,
    required this.netWeight,
    required this.moistureContent,
    this.measuredAt,
    required this.status,
  });

  factory WarehouseOperationBag.fromJson(Map<String, dynamic> json) {
    final grossWeight =
        _double(json['measuredGrossWeight'] ?? json['grossWeight']);
    final packagingWeight =
        _double(json['measuredPackagingWeight'] ?? json['packagingWeight']);
    final loadWeight =
        _double(json['loadWeight'] ?? grossWeight - packagingWeight);

    return WarehouseOperationBag(
      id: _int(json['id']),
      uuid: json['uuid']?.toString() ?? '',
      operationUuid: (json['operationUuid'] ??
              json['dispatchUuid'] ??
              json['stockCountUuid'] ??
              json['stockAdjustmentUuid'])
          ?.toString() ??
          '',
      stockBagUuid:
          (json['stockBagUuid'] ??
                      json['stockBag'] ??
                      json['bagUuid'] ??
                      json['uuid'])
                  ?.toString() ??
              '',
      tagNumber: json['tagNumber']?.toString() ?? '',
      bagNumber: _int(json['bagNumber']),
      grossWeight: grossWeight,
      packagingWeight: packagingWeight,
      loadWeight: loadWeight,
      netWeight: _double(json['measuredNetWeight'] ?? json['netWeight']),
      moistureContent: _double(json['moistureContent']),
      measuredAt: _dateTime(
        json['measuredAt'] ?? json['moistureMeasuredAt'] ?? json['createdAt'],
      ),
      status: json['status']?.toString() ?? '',
    );
  }
}

int? _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTime(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
