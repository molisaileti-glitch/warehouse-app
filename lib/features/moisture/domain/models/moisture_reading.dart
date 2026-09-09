enum MoistureZone { top, lowerTop, highBottom, bottom }

class MoistureReading {
  final double value;
  final int? materialCode;
  final DateTime measuredAt;

  const MoistureReading({
    required this.value,
    required this.measuredAt,
    this.materialCode,
  });
}

class GrainMaterial {
  final int code;
  final String name;
  final Set<String> cropAliases;

  const GrainMaterial({
    required this.code,
    required this.name,
    required this.cropAliases,
  });

  static const all = [
    GrainMaterial(
      code: 0x07,
      name: 'Maize / Corn',
      cropAliases: {'maize', 'corn'},
    ),
    GrainMaterial(
      code: 0x05,
      name: 'Rice',
      cropAliases: {'rice', 'paddy'},
    ),
    GrainMaterial(
      code: 0x36,
      name: 'Beans',
      cropAliases: {'bean', 'beans'},
    ),
  ];

  String get codeLabel => 'Cd${code.toRadixString(16).padLeft(2, '0')}';

  bool matchesCode(int? materialCode) => materialCode == code;

  static GrainMaterial? forCropName(String cropName) {
    final normalizedCrop = _normalize(cropName);
    for (final material in all) {
      for (final alias in material.cropAliases) {
        final normalizedAlias = _normalize(alias);
        if (normalizedCrop == normalizedAlias ||
            normalizedCrop.contains(normalizedAlias)) {
          return material;
        }
      }
    }
    return null;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

class BagMoistureResult {
  final double top;
  final double lowerTop;
  final double highBottom;
  final double bottom;
  final DateTime measuredAt;

  const BagMoistureResult({
    required this.top,
    required this.lowerTop,
    required this.highBottom,
    required this.bottom,
    required this.measuredAt,
  });

  double get average => (top + lowerTop + highBottom + bottom) / 4;

  double valueFor(MoistureZone zone) {
    return switch (zone) {
      MoistureZone.top => top,
      MoistureZone.lowerTop => lowerTop,
      MoistureZone.highBottom => highBottom,
      MoistureZone.bottom => bottom,
    };
  }
}
