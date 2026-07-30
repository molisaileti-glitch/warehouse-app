import 'package:warehouse_app/core/database/app_database.dart';

class HarvestBagInput {
  final String tag;
  final double grossWeight;
  final double packagingWeight;
  final double moistureContent;

  const HarvestBagInput({
    required this.tag,
    required this.grossWeight,
    required this.packagingWeight,
    required this.moistureContent,
  });

  HarvestBagWeights calculate() {
    final loadWeight = grossWeight - packagingWeight;
    final moistureWeight = loadWeight * (moistureContent / 100);
    final netWeight = loadWeight - moistureWeight;
    return HarvestBagWeights(
      grossWeight: grossWeight,
      netWeight: netWeight,
      packagingWeight: packagingWeight,
      moistureContent: moistureContent,
      loadWeight: loadWeight,
      moistureWeight: moistureWeight,
    );
  }
}

class HarvestBagWeights {
  final double grossWeight;
  final double netWeight;
  final double packagingWeight;
  final double moistureContent;
  final double loadWeight;
  final double moistureWeight;

  const HarvestBagWeights({
    required this.grossWeight,
    required this.netWeight,
    required this.packagingWeight,
    required this.moistureContent,
    required this.loadWeight,
    required this.moistureWeight,
  });
}

class HarvestCreateInput {
  final Farmer farmer;
  final Warehouse warehouse;
  final Crop crop;
  final CropGrade? cropGrade;
  final MeasurementUnit? uom;
  final String packaging;
  final List<HarvestBagInput> bags;

  const HarvestCreateInput({
    required this.farmer,
    required this.warehouse,
    required this.crop,
    required this.bags,
    this.cropGrade,
    this.uom,
    this.packaging = 'BAGS',
  });
}

class HarvestCreateResult {
  final bool success;
  final FarmerHarvest? harvest;
  final String? error;

  const HarvestCreateResult._({
    required this.success,
    this.harvest,
    this.error,
  });

  factory HarvestCreateResult.success(FarmerHarvest harvest) {
    return HarvestCreateResult._(success: true, harvest: harvest);
  }

  factory HarvestCreateResult.failure(String error) {
    return HarvestCreateResult._(success: false, error: error);
  }
}
