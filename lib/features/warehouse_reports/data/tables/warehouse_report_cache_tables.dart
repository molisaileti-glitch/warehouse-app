const warehouseReportActivitiesTable = 'warehouse_report_activities';
const warehouseReportBagsTable = 'warehouse_report_bags';

const createWarehouseReportActivitiesSql = '''
CREATE TABLE IF NOT EXISTS $warehouseReportActivitiesTable (
  uuid TEXT PRIMARY KEY,
  activity_type TEXT NOT NULL,
  warehouse_id TEXT NOT NULL,
  collection_center_uuid TEXT NOT NULL,
  collection_center_name TEXT NOT NULL,
  crop INTEGER NOT NULL,
  crop_name TEXT NOT NULL,
  total_bags INTEGER NOT NULL DEFAULT 0,
  total_gross_weight REAL,
  total_net_weight REAL,
  worker_id INTEGER,
  worker_name TEXT NOT NULL DEFAULT '',
  activity_at INTEGER NOT NULL,
  farmer_name TEXT,
  farmer_phone_number TEXT,
  receipt_number TEXT,
  recipient_type TEXT,
  recipient_name TEXT,
  recipient_phone TEXT,
  adjustment_type TEXT,
  reason TEXT,
  net_weight_change REAL,
  updated_at INTEGER NOT NULL
)
''';

const createWarehouseReportBagsSql = '''
CREATE TABLE IF NOT EXISTS $warehouseReportBagsTable (
  id TEXT PRIMARY KEY,
  activity_uuid TEXT NOT NULL,
  stock_bag_uuid TEXT NOT NULL DEFAULT '',
  tag_number TEXT NOT NULL DEFAULT '',
  gross_weight REAL NOT NULL DEFAULT 0,
  packaging_weight REAL NOT NULL DEFAULT 0,
  net_weight REAL NOT NULL DEFAULT 0,
  previous_net_weight REAL,
  net_weight_difference REAL,
  moisture_content REAL NOT NULL DEFAULT 0,
  FOREIGN KEY(activity_uuid) REFERENCES $warehouseReportActivitiesTable(uuid)
    ON DELETE CASCADE
)
''';

const createWarehouseReportActivitiesLookupIndexSql = '''
CREATE INDEX IF NOT EXISTS idx_report_activities_lookup
ON $warehouseReportActivitiesTable(
  collection_center_uuid,
  activity_at,
  crop,
  activity_type,
  worker_id
)
''';

const createWarehouseReportBagsActivityIndexSql = '''
CREATE INDEX IF NOT EXISTS idx_report_bags_activity
ON $warehouseReportBagsTable(activity_uuid)
''';
