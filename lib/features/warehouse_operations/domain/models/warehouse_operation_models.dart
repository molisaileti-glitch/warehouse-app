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
