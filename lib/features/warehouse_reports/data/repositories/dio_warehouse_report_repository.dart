import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/warehouse_reports/data/tables/warehouse_report_cache_tables.dart';
import 'package:warehouse_app/features/warehouse_reports/domain/models/warehouse_report_models.dart';
import 'package:warehouse_app/features/warehouse_reports/domain/repositories/warehouse_report_repository.dart';

class LocalWarehouseReportRepository implements WarehouseReportRepository {
  LocalWarehouseReportRepository({required AppDatabase database})
      : _database = database;

  final AppDatabase _database;

  @override
  Future<List<WarehouseActivityReportRecord>> fetchActivity(
    WarehouseActivityReportQuery query,
  ) async {
    final conditions = <String>[
      'collection_center_uuid = ?',
      'activity_at >= ?',
      'activity_at <= ?',
    ];
    final variables = <Variable>[
      Variable<String>(query.collectionCenterUuid),
      Variable<int>(_startOfDay(query.fromDate).millisecondsSinceEpoch),
      Variable<int>(_endOfDay(query.toDate).millisecondsSinceEpoch),
    ];

    if (query.cropId != null) {
      conditions.add('crop = ?');
      variables.add(Variable<int>(query.cropId!));
    }
    if (query.activityType?.trim().isNotEmpty == true) {
      conditions.add('activity_type = ?');
      variables.add(Variable<String>(query.activityType!.trim()));
    }
    if (query.workerId != null) {
      conditions.add('worker_id = ?');
      variables.add(Variable<int>(query.workerId!));
    }

    final limit = query.size;
    final offset = limit == null || query.page == null
        ? null
        : ((query.page! <= 1 ? 0 : query.page! - 1) * limit);

    final rows = await _database.customSelect(
      '''
      SELECT *
      FROM $warehouseReportActivitiesTable
      WHERE ${conditions.join(' AND ')}
      ORDER BY activity_at DESC
      ${limit == null ? '' : 'LIMIT $limit'}
      ${offset == null ? '' : 'OFFSET $offset'}
      ''',
      variables: variables,
    ).get();

    final records = <WarehouseActivityReportRecord>[];
    for (final row in rows) {
      final uuid = _stringCell(row, 'uuid');
      records.add(
        WarehouseActivityReportRecord.fromJson({
          'activityType': _stringCell(row, 'activity_type'),
          'uuid': uuid,
          'collectionCenterUuid': _stringCell(row, 'collection_center_uuid'),
          'collectionCenterName': _stringCell(row, 'collection_center_name'),
          'crop': _intCell(row, 'crop'),
          'cropName': _stringCell(row, 'crop_name'),
          'totalBags': _intCell(row, 'total_bags'),
          'totalGrossWeight': _nullableDoubleCell(row, 'total_gross_weight'),
          'totalNetWeight': _nullableDoubleCell(row, 'total_net_weight'),
          'workerId': _nullableIntCell(row, 'worker_id'),
          'workerName': _stringCell(row, 'worker_name'),
          'activityAt': DateTime.fromMillisecondsSinceEpoch(
            _intCell(row, 'activity_at'),
          ).toIso8601String(),
          'farmerName': _nullableStringCell(row, 'farmer_name'),
          'farmerPhoneNumber': _nullableStringCell(
            row,
            'farmer_phone_number',
          ),
          'receiptNumber': _nullableStringCell(row, 'receipt_number'),
          'recipientType': _nullableStringCell(row, 'recipient_type'),
          'recipientName': _nullableStringCell(row, 'recipient_name'),
          'recipientPhone': _nullableStringCell(row, 'recipient_phone'),
          'adjustmentType': _nullableStringCell(row, 'adjustment_type'),
          'reason': _nullableStringCell(row, 'reason'),
          'netWeightChange': _nullableDoubleCell(row, 'net_weight_change'),
          'bags': await _bagsForActivity(uuid),
        }),
      );
    }
    return records;
  }

  @override
  Future<List<WarehouseWorkerReportRecord>> fetchWorkers({
    required String collectionCenterUuid,
    required DateTime fromDate,
    required DateTime toDate,
    int? cropId,
  }) async {
    final cropCondition = cropId == null ? '' : 'AND a.crop = ?';
    final variables = <Variable>[
      Variable<String>(collectionCenterUuid),
      Variable<int>(_startOfDay(fromDate).millisecondsSinceEpoch),
      Variable<int>(_endOfDay(toDate).millisecondsSinceEpoch),
      if (cropId != null) Variable<int>(cropId),
    ];

    final rows = await _database.customSelect(
      '''
      SELECT
        a.worker_id,
        a.worker_name,
        SUM(CASE WHEN a.activity_type = 'RECEIVING' THEN 1 ELSE 0 END) AS receiving_count,
        SUM(CASE WHEN a.activity_type = 'RECEIVING' THEN a.total_bags ELSE 0 END) AS received_bags,
        SUM(CASE WHEN a.activity_type = 'RECEIVING' THEN COALESCE(a.total_net_weight, 0) ELSE 0 END) AS received_net_weight,
        SUM(CASE WHEN a.activity_type = 'DISPATCH' THEN 1 ELSE 0 END) AS dispatch_count,
        SUM(CASE WHEN a.activity_type = 'DISPATCH' THEN a.total_bags ELSE 0 END) AS dispatched_bags,
        SUM(CASE WHEN a.activity_type = 'DISPATCH' THEN COALESCE(a.total_net_weight, 0) ELSE 0 END) AS dispatched_net_weight,
        SUM(CASE WHEN a.activity_type = 'STOCK_ADJUSTMENT' THEN 1 ELSE 0 END) AS adjustment_count,
        SUM(CASE WHEN a.activity_type = 'STOCK_ADJUSTMENT' THEN a.total_bags ELSE 0 END) AS adjusted_bags,
        SUM(CASE WHEN a.activity_type = 'STOCK_ADJUSTMENT' THEN COALESCE(a.net_weight_change, 0) ELSE 0 END) AS adjustment_net_change,
        COUNT(*) AS total_activities,
        MAX(a.activity_at) AS last_activity_at,
        CASE WHEN EXISTS (
          SELECT 1 FROM users u
          JOIN warehouses w ON w.id = u.warehouse_id
          WHERE w.uuid = a.collection_center_uuid
            AND (
              CAST(u.id AS INTEGER) = a.worker_id
              OR u.full_name = a.worker_name
            )
        ) THEN 1 ELSE 0 END AS assigned
      FROM $warehouseReportActivitiesTable a
      WHERE a.collection_center_uuid = ?
        AND a.activity_at >= ?
        AND a.activity_at <= ?
        $cropCondition
      GROUP BY a.worker_id, a.worker_name
      ORDER BY total_activities DESC, a.worker_name ASC
      ''',
      variables: variables,
    ).get();

    return rows.map((row) {
      final lastActivityAt = _nullableIntCell(row, 'last_activity_at');
      return WarehouseWorkerReportRecord.fromJson({
        'workerId': _nullableIntCell(row, 'worker_id'),
        'workerName': _stringCell(row, 'worker_name'),
        'assigned': _intCell(row, 'assigned') == 1,
        'receivingCount': _intCell(row, 'receiving_count'),
        'receivedBags': _intCell(row, 'received_bags'),
        'receivedNetWeight': _doubleCell(row, 'received_net_weight'),
        'dispatchCount': _intCell(row, 'dispatch_count'),
        'dispatchedBags': _intCell(row, 'dispatched_bags'),
        'dispatchedNetWeight': _doubleCell(row, 'dispatched_net_weight'),
        'adjustmentCount': _intCell(row, 'adjustment_count'),
        'adjustedBags': _intCell(row, 'adjusted_bags'),
        'adjustmentNetChange': _doubleCell(row, 'adjustment_net_change'),
        'totalActivities': _intCell(row, 'total_activities'),
        'lastActivityAt': lastActivityAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastActivityAt)
                .toIso8601String(),
      });
    }).toList();
  }

  @override
  Future<File> saveActivityExcel({
    required WarehouseReportExportData report,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeName =
        report.fileName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final fileName =
        safeName.toLowerCase().endsWith('.xlsx') ? safeName : '$safeName.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(_WarehouseXlsxBuilder(report).build(), flush: true);
    return file;
  }

  Future<List<Map<String, dynamic>>> _bagsForActivity(String activityUuid) {
    return _database
        .customSelect(
          '''
      SELECT *
      FROM $warehouseReportBagsTable
      WHERE activity_uuid = ?
      ORDER BY id ASC
      ''',
          variables: [Variable<String>(activityUuid)],
        )
        .get()
        .then((rows) {
          return rows
              .map(
                (row) => {
                  'stockBagUuid': _stringCell(row, 'stock_bag_uuid'),
                  'tagNumber': _stringCell(row, 'tag_number'),
                  'grossWeight': _doubleCell(row, 'gross_weight'),
                  'packagingWeight': _doubleCell(row, 'packaging_weight'),
                  'netWeight': _doubleCell(row, 'net_weight'),
                  'previousNetWeight': _nullableDoubleCell(
                    row,
                    'previous_net_weight',
                  ),
                  'netWeightDifference': _nullableDoubleCell(
                    row,
                    'net_weight_difference',
                  ),
                  'moistureContent': _doubleCell(row, 'moisture_content'),
                },
              )
              .toList();
        });
  }

  String _stringCell(QueryRow row, String key) {
    return row.readNullable<String>(key) ?? '';
  }

  String? _nullableStringCell(QueryRow row, String key) {
    final value = row.readNullable<String>(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  int _intCell(QueryRow row, String key) {
    return _nullableIntCell(row, key) ?? 0;
  }

  int? _nullableIntCell(QueryRow row, String key) {
    try {
      return row.readNullable<int>(key);
    } on ArgumentError {
      final value = row.readNullable<double>(key);
      return value?.toInt();
    }
  }

  double _doubleCell(QueryRow row, String key) {
    return _nullableDoubleCell(row, key) ?? 0;
  }

  double? _nullableDoubleCell(QueryRow row, String key) {
    try {
      return row.readNullable<double>(key);
    } on ArgumentError {
      final value = row.readNullable<int>(key);
      return value?.toDouble();
    }
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }
}

class _WarehouseXlsxBuilder {
  _WarehouseXlsxBuilder(this.report);

  final WarehouseReportExportData report;
  final _dateFormat = DateFormat('d MMM yyyy HH:mm');
  WarehouseReportLabels get labels => report.labels;

  Uint8List build() {
    final archive = _SimpleZipWriter();
    archive.add('[Content_Types].xml', _contentTypes());
    archive.add('_rels/.rels', _rootRels());
    archive.add('xl/workbook.xml', _workbook());
    archive.add('xl/_rels/workbook.xml.rels', _workbookRels());
    archive.add('xl/styles.xml', _styles());
    archive.add(
      'xl/worksheets/sheet1.xml',
      _sheetXml(_summaryRows(), const [28, 28]),
    );
    archive.add(
      'xl/worksheets/sheet2.xml',
      _sheetXml(_userRows(), const [28, 16, 14, 16, 18, 16]),
    );
    archive.add(
      'xl/worksheets/sheet3.xml',
      _sheetXml(
        _activityRows(),
        const [20, 18, 16, 20, 16, 22, 24, 18, 24, 16, 18, 20, 18],
      ),
    );
    return archive.finish();
  }

  List<List<Object?>> _summaryRows() {
    final totalBags = report.activities.fold<int>(
      0,
      (sum, item) => sum + item.totalBags,
    );
    final totalNet = report.activities.fold<double>(
      0,
      (sum, item) => sum + (item.totalNetWeight ?? item.netWeightChange ?? 0),
    );
    return [
      [labels.workbookTitle, ''],
      [labels.warehouse, report.warehouseName],
      [labels.reportType, report.reportType],
      [labels.crop, report.cropName],
      [labels.period, report.periodLabel],
      [],
      [labels.summary, ''],
      [_summaryName(report.reportType), report.activities.length],
      [labels.totalBags, totalBags],
      [
        report.reportType == 'Adjustment'
            ? labels.totalWeightChange
            : labels.totalNetWeight,
        '${totalNet.toStringAsFixed(2)} kg',
      ],
    ];
  }

  List<List<Object?>> _userRows() {
    return [
      [
        labels.worker,
        labels.roleStatus,
        labels.recordsDone,
        labels.receivedBags,
        labels.dispatchedBags,
        labels.adjustedBags,
      ],
      for (final user in report.users)
        [
          user.workerName,
          user.assigned ? labels.worker : labels.owner,
          user.totalActivities,
          user.receivedBags,
          user.dispatchedBags,
          user.adjustedBags,
        ],
    ];
  }

  List<List<Object?>> _activityRows() {
    return [
      [
        labels.date,
        labels.activity,
        labels.crop,
        labels.bagTag,
        labels.netWeight,
        labels.performedBy,
        labels.farmerName,
        labels.farmerPhone,
        labels.recipientName,
        labels.recipientType,
        labels.recipientPhone,
        labels.receiptNumber,
        labels.reason,
      ],
      for (final record in report.activities)
        if (record.bags.isEmpty)
          _activityRow(record, null)
        else
          for (final bag in record.bags) _activityRow(record, bag),
    ];
  }

  List<Object?> _activityRow(
    WarehouseActivityReportRecord record,
    WarehouseReportBag? bag,
  ) {
    return [
      _dateFormat.format(record.activityAt),
      _activityLabel(record.activityType),
      record.cropName,
      bag?.tagNumber ?? '',
      '${(bag?.netWeight ?? record.totalNetWeight ?? record.netWeightChange ?? 0).toStringAsFixed(2)} kg',
      record.workerName,
      record.farmerName ?? '',
      record.farmerPhoneNumber ?? '',
      record.recipientName ?? '',
      record.recipientType ?? '',
      record.recipientPhone ?? '',
      record.receiptNumber ?? '',
      record.reason ?? '',
    ];
  }

  String _summaryName(String reportType) {
    return switch (reportType) {
      'Receiving' => labels.receiving,
      'Dispatch' => labels.dispatch,
      'Adjustment' => labels.stockAdjustment,
      _ => labels.activityFallback,
    };
  }

  String _activityLabel(String activityType) {
    return switch (activityType) {
      'RECEIVING' => labels.receiving,
      'DISPATCH' => labels.dispatch,
      'STOCK_ADJUSTMENT' => labels.stockAdjustment,
      _ => activityType,
    };
  }

  String _sheetXml(List<List<Object?>> rows, List<double> widths) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<cols>');
    for (var i = 0; i < widths.length; i++) {
      buffer.write(
        '<col min="${i + 1}" max="${i + 1}" width="${widths[i]}" customWidth="1"/>',
      );
    }
    buffer
      ..write('</cols>')
      ..write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      buffer.write('<row r="${r + 1}">');
      for (var c = 0; c < row.length; c++) {
        final value = row[c];
        final ref = '${_columnName(c + 1)}${r + 1}';
        final style = r == 0 ? ' s="1"' : '';
        if (value is num) {
          buffer.write('<c r="$ref"$style><v>$value</v></c>');
        } else {
          buffer.write(
            '<c r="$ref" t="inlineStr"$style><is><t>${_xml(value?.toString() ?? '')}</t></is></c>',
          );
        }
      }
      buffer.write('</row>');
    }
    buffer
      ..write('</sheetData>')
      ..write('</worksheet>');
    return buffer.toString();
  }

  String _columnName(int index) {
    var n = index;
    final chars = <String>[];
    while (n > 0) {
      n--;
      chars.insert(0, String.fromCharCode(65 + (n % 26)));
      n ~/= 26;
    }
    return chars.join();
  }

  String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _contentTypes() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';
  }

  String _rootRels() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
  }

  String _workbook() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
<sheet name="${_xml(labels.summarySheet)}" sheetId="1" r:id="rId1"/>
<sheet name="${_xml(labels.userActivitySheet)}" sheetId="2" r:id="rId2"/>
<sheet name="${_xml(labels.activityDetailsSheet)}" sheetId="3" r:id="rId3"/>
</sheets>
</workbook>''';
  }

  String _workbookRels() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
  }

  String _styles() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="12"/><name val="Calibri"/></font></fonts>
<fills count="1"><fill><patternFill patternType="none"/></fill></fills>
<borders count="1"><border/></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
</styleSheet>''';
  }
}

class _SimpleZipWriter {
  final List<int> _bytes = [];
  final List<_ZipEntry> _entries = [];

  void add(String name, String content) {
    final data = Uint8List.fromList(utf8.encode(content));
    final nameBytes = Uint8List.fromList(utf8.encode(name));
    final crc = _crc32(data);
    final offset = _bytes.length;

    _write32(0x04034b50);
    _write16(20);
    _write16(0x0800);
    _write16(0);
    _write16(0);
    _write16(0);
    _write32(crc);
    _write32(data.length);
    _write32(data.length);
    _write16(nameBytes.length);
    _write16(0);
    _bytes.addAll(nameBytes);
    _bytes.addAll(data);
    _entries.add(_ZipEntry(nameBytes, crc, data.length, offset));
  }

  Uint8List finish() {
    final centralOffset = _bytes.length;
    for (final entry in _entries) {
      _write32(0x02014b50);
      _write16(20);
      _write16(20);
      _write16(0x0800);
      _write16(0);
      _write16(0);
      _write16(0);
      _write32(entry.crc);
      _write32(entry.size);
      _write32(entry.size);
      _write16(entry.nameBytes.length);
      _write16(0);
      _write16(0);
      _write16(0);
      _write16(0);
      _write32(0);
      _write32(entry.offset);
      _bytes.addAll(entry.nameBytes);
    }
    final centralSize = _bytes.length - centralOffset;
    _write32(0x06054b50);
    _write16(0);
    _write16(0);
    _write16(_entries.length);
    _write16(_entries.length);
    _write32(centralSize);
    _write32(centralOffset);
    _write16(0);
    return Uint8List.fromList(_bytes);
  }

  void _write16(int value) {
    _bytes
      ..add(value & 0xff)
      ..add((value >> 8) & 0xff);
  }

  void _write32(int value) {
    _bytes
      ..add(value & 0xff)
      ..add((value >> 8) & 0xff)
      ..add((value >> 16) & 0xff)
      ..add((value >> 24) & 0xff);
  }

  int _crc32(Uint8List data) {
    var crc = 0xffffffff;
    for (final byte in data) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}

class _ZipEntry {
  const _ZipEntry(this.nameBytes, this.crc, this.size, this.offset);

  final Uint8List nameBytes;
  final int crc;
  final int size;
  final int offset;
}
