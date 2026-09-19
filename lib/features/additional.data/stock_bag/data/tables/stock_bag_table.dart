class CachedStockBagEntry {
  const CachedStockBagEntry({
    required this.uuid,
    this.serverId,
    required this.warehouseId,
    required this.collectionCenterUuid,
    required this.crop,
    required this.cropName,
    required this.tagNumber,
    required this.grossWeight,
    required this.packagingWeight,
    required this.loadWeight,
    required this.netWeight,
    required this.moistureContent,
    required this.status,
    this.lastSeenAt,
    required this.updatedAt,
  });

  final String uuid;
  final int? serverId;
  final String warehouseId;
  final String collectionCenterUuid;
  final int crop;
  final String cropName;
  final String tagNumber;
  final double grossWeight;
  final double packagingWeight;
  final double loadWeight;
  final double netWeight;
  final double moistureContent;
  final String status;
  final DateTime? lastSeenAt;
  final DateTime updatedAt;
}

const cachedStockBagsTableName = 'cached_stock_bags';

const createCachedStockBagsSql = '''
CREATE TABLE IF NOT EXISTS cached_stock_bags (
  uuid TEXT NOT NULL PRIMARY KEY,
  server_id INTEGER NULL,
  warehouse_id TEXT NOT NULL,
  collection_center_uuid TEXT NOT NULL,
  crop INTEGER NOT NULL,
  crop_name TEXT NOT NULL,
  tag_number TEXT NOT NULL,
  gross_weight REAL NOT NULL DEFAULT 0,
  packaging_weight REAL NOT NULL DEFAULT 0,
  load_weight REAL NOT NULL DEFAULT 0,
  net_weight REAL NOT NULL DEFAULT 0,
  moisture_content REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'IN_STOCK',
  last_seen_at INTEGER NULL,
  updated_at INTEGER NOT NULL
);
''';

const createCachedStockBagsLookupIndexSql = '''
CREATE INDEX IF NOT EXISTS idx_cached_stock_bags_lookup
ON cached_stock_bags (warehouse_id, crop, status);
''';

const createCachedStockBagsTagIndexSql = '''
CREATE INDEX IF NOT EXISTS idx_cached_stock_bags_tag
ON cached_stock_bags (tag_number);
''';
