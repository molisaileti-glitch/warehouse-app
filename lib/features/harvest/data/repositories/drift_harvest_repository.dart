import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/utils/uuid_helper.dart';
import 'package:warehouse_app/features/harvest/domain/models/harvest_model.dart';
import 'package:warehouse_app/features/harvest/domain/repositories/harvest_repository.dart';

class DriftHarvestRepository implements HarvestRepository {
  final HarvestDao _dao;
  final FarmerDao _farmerDao;
  final WarehouseDao _warehouseDao;
  final CropDao _cropDao;
  final SyncQueueDao _syncDao;
  final AuditLogDao _auditDao;
  final Dio _dio;
  final String _currentUserId;

  DriftHarvestRepository({
    required HarvestDao dao,
    required FarmerDao farmerDao,
    required WarehouseDao warehouseDao,
    required CropDao cropDao,
    required SyncQueueDao syncDao,
    required AuditLogDao auditDao,
    required Dio dio,
    required String currentUserId,
  })  : _dao = dao,
        _farmerDao = farmerDao,
        _warehouseDao = warehouseDao,
        _cropDao = cropDao,
        _syncDao = syncDao,
        _auditDao = auditDao,
        _dio = dio,
        _currentUserId = currentUserId;

  @override
  Stream<List<FarmerHarvest>> watchRecentHarvests(String warehouseId) {
    return _dao.watchRecentHarvests(warehouseId);
  }

  @override
  Stream<List<MeasurementUnit>> watchMeasurementUnits() {
    return _dao.watchMeasurementUnits();
  }

  @override
  Stream<List<CropGrade>> watchCropGradesForCrop(int cropId) {
    return _dao.watchCropGradesForCrop(cropId);
  }

  @override
  Future<HarvestCreateResult> recordHarvest(HarvestCreateInput input) async {
    final validationError = _validate(input);
    if (validationError != null) {
      return HarvestCreateResult.failure(validationError);
    }

    final harvestUuid = newUuid();
    final receiptNumber = _generateReceiptNumber();
    final now = DateTime.now();
    final farmerName = _farmerName(input.farmer);
    final cropName = _normalizeCropName(input.crop.name);
    final calculatedBags = input.bags.map((bag) => (bag, bag.calculate())).toList();
    final totalGross = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.$2.grossWeight,
    );
    final totalNet = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.$2.netWeight,
    );
    final totalPackaging = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.$2.packagingWeight,
    );
    final totalLoad = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.$2.loadWeight,
    );
    final totalMoisture = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.$2.moistureWeight,
    );
    final moistureContent = totalLoad <= 0 ? 0.0 : (totalMoisture / totalLoad) * 100;
    final collectionCenter = int.tryParse(input.warehouse.id);
    final receivedBy = int.tryParse(_currentUserId);
    final mcu = input.farmer.mcu == 0 ? null : input.farmer.mcu;
    final amcos = input.farmer.amcos == 0 ? input.warehouse.amcos : input.farmer.amcos;

    final harvestCompanion = FarmerHarvestsCompanion.insert(
      uuid: harvestUuid,
      farmer: input.farmer.id,
      farmerUuid: Value(input.farmer.uuid),
      farmerName: farmerName,
      farmerPhoneNumber: input.farmer.phoneNumber,
      guarantor: Value(input.farmer.id),
      guarantorName: Value(farmerName),
      grossWeight: _round(totalGross),
      netWeight: _round(totalNet),
      packagingWeight: _round(totalPackaging),
      moistureContent: _round(moistureContent),
      uom: Value(input.uom?.id),
      uomName: Value(input.uom?.name),
      packaging: Value(input.packaging),
      receiptNumber: receiptNumber,
      amcos: Value(amcos),
      amcosName: Value(input.farmer.amcosName ?? input.warehouse.amcosName),
      mcu: Value(mcu),
      mcuName: Value(input.farmer.mcuName),
      receivedBy: Value(receivedBy),
      crop: input.crop.id,
      cropName: cropName,
      cropGrade: Value(input.cropGrade?.id),
      cropGradeName: Value(input.cropGrade?.gradeName),
      warehouseId: input.warehouse.id,
      collectionCenter: Value(collectionCenter),
      collectionCenterName: input.warehouse.name,
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pending'),
    );

    final bagCompanions = calculatedBags.map((item) {
      final bag = item.$1;
      final weights = item.$2;
      return FarmerHarvestBagsCompanion.insert(
        id: newUuid(),
        harvestUuid: harvestUuid,
        netWeight: _round(weights.netWeight),
        tag: bag.tag,
        loadWeight: _round(weights.loadWeight),
        grossWeight: _round(weights.grossWeight),
        moistureWeight: _round(weights.moistureWeight),
        moistureContent: _round(weights.moistureContent),
        packagingWeight: _round(weights.packagingWeight),
      );
    }).toList();

    await _dao.insertHarvestWithBags(
      harvest: harvestCompanion,
      bags: bagCompanions,
    );

    await _syncDao.enqueue(
      SyncQueueCompanion.insert(
        entityType: 'farmerHarvests',
        entityId: harvestUuid,
        operation: 'create',
        payload: jsonEncode(
          _buildPayload(
            input: input,
            uuid: harvestUuid,
            receiptNumber: receiptNumber,
            farmerName: farmerName,
            cropName: cropName,
            totalGross: totalGross,
            totalNet: totalNet,
            totalPackaging: totalPackaging,
            moistureContent: moistureContent,
            collectionCenter: collectionCenter,
            receivedBy: receivedBy,
            amcos: amcos,
            mcu: mcu,
            bags: calculatedBags,
          ),
        ),
      ),
    );

    await _auditDao.insertLog(
      AuditLogsCompanion.insert(
        id: newUuid(),
        userId: _currentUserId,
        action: 'harvest.record',
        warehouseId: Value(input.warehouse.id),
        metadata: Value(
          jsonEncode({
            'uuid': harvestUuid,
            'receiptNumber': receiptNumber,
            'farmer': input.farmer.id,
            'crop': input.crop.id,
            'netWeight': _round(totalNet),
          }),
        ),
        origin: const Value('offline'),
      ),
    );

    final saved = await _dao.getHarvestByUuid(harvestUuid);
    if (saved == null) {
      return HarvestCreateResult.failure('Harvest was not saved locally.');
    }
    return HarvestCreateResult.success(saved);
  }

  @override
  Future<int> pullReferenceData() async {
    var count = 0;
    try {
      final unitsResponse = await _dio.get('/measurement-units');
      final units = _readRows(unitsResponse.data)
          .map(_measurementUnitFromJson)
          .whereType<MeasurementUnitsCompanion>()
          .toList();
      await _dao.upsertMeasurementUnits(units);
      count += units.length;
    } on DioException {
      // Offline-first: keep using whatever reference data is cached locally.
    }

    try {
      final gradesResponse = await _dio.get('/crop-grades');
      final grades = _readRows(gradesResponse.data)
          .map(_cropGradeFromJson)
          .whereType<CropGradesCompanion>()
          .toList();
      await _dao.upsertCropGrades(grades);
      count += grades.length;
    } on DioException {
      // Offline-first: keep using whatever reference data is cached locally.
    }
    return count;
  }

  @override
  Future<int> pullFromServer({required Set<int> amcosIds}) async {
    var saved = 0;
    var skippedMissingDependency = 0;
    final sortedIds = amcosIds.where((id) => id > 0).toList()..sort();

    for (final amcosId in sortedIds) {
      final response = await _dio.get('/farmer-harvests/amcos/$amcosId');
      for (final row in _readRows(response.data)) {
        final serverId = _nullableInt(row['id']);
        final farmerId = _nullableInt(row['farmer']);
        final cropId = _nullableInt(row['crop']);
        final collectionCenterId = _nullableInt(row['collectionCenter']);
        if (serverId == null ||
            farmerId == null ||
            cropId == null ||
            collectionCenterId == null) {
          skippedMissingDependency++;
          continue;
        }

        final farmer = await _farmerDao.getFarmerById(farmerId);
        final crop = await _cropDao.getCropById(cropId);
        final warehouse =
            await _warehouseDao.getWarehouseById(collectionCenterId.toString());
        if (farmer == null || crop == null || warehouse == null) {
          skippedMissingDependency++;
          continue;
        }

        final rawUuid = _nullableString(row['uuid']);
        final uuid = rawUuid ?? 'server-harvest-$serverId';
        final guarantorId = _nullableInt(row['guarantor']);
        final guarantor = guarantorId == null
            ? null
            : await _farmerDao.getFarmerById(guarantorId);
        final receivedAt = _date(row['receivedAt']) ?? DateTime.now();

        await _dao.insertHarvestWithBags(
          harvest: FarmerHarvestsCompanion.insert(
            uuid: uuid,
            serverId: Value(serverId),
            farmer: farmerId,
            farmerUuid: Value(farmer.uuid),
            farmerName: _string(
              row['farmerName'],
              fallback: '${farmer.firstName} ${farmer.lastName}'.trim(),
            ),
            farmerPhoneNumber: _string(
              row['farmerPhoneNumber'],
              fallback: farmer.phoneNumber,
            ),
            guarantor: Value(guarantor?.id),
            guarantorName: Value(_nullableString(row['guarantorName'])),
            grossWeight: _double(row['grossWeight']),
            netWeight: _double(row['netWeight']),
            packagingWeight: _double(row['packagingWeight']),
            moistureContent: _double(row['moistureContent']),
            packaging: Value(_string(row['packaging'], fallback: 'BAGS')),
            receiptNumber: _string(
              row['receiptNumber'],
              fallback: 'SERVER-$serverId',
            ),
            amcos: Value(_nullableInt(row['amcos']) ?? amcosId),
            amcosName: Value(_nullableString(row['amcosName'])),
            mcu: Value(_nullableInt(row['mcu'])),
            mcuName: Value(_nullableString(row['mcuName'])),
            receivedBy: Value(_nullableInt(row['receivedBy'])),
            receivedByName: Value(_nullableString(row['receivedByName'])),
            crop: cropId,
            cropName: _string(row['cropName'], fallback: crop.name),
            warehouseId: collectionCenterId.toString(),
            collectionCenter: Value(collectionCenterId),
            collectionCenterName: _string(
              row['collectionCenterName'],
              fallback: warehouse.name,
            ),
            receivedAt: Value(receivedAt),
            syncStatus: const Value('synced'),
            updatedAt: Value(_date(row['updatedAt']) ?? receivedAt),
          ),
          bags: const [],
        );
        saved++;
      }
    }

    developer.log(
      '[HarvestSync] amcosIds=$sortedIds saved=$saved '
      'skippedMissingDependency=$skippedMissingDependency',
      name: 'sync.harvest',
    );
    return saved;
  }

  String? _validate(HarvestCreateInput input) {
    if (input.bags.isEmpty) return 'Add at least one bag.';
    for (final bag in input.bags) {
      if (bag.grossWeight <= 0) return 'Gross weight must be greater than zero.';
      if (bag.packagingWeight < 0) return 'Packaging weight cannot be negative.';
      if (bag.packagingWeight > bag.grossWeight) {
        return 'Packaging weight cannot be greater than gross weight.';
      }
      if (bag.moistureContent < 0 || bag.moistureContent > 100) {
        return 'Moisture content must be between 0 and 100.';
      }
    }
    return null;
  }

  int? _nullableInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _date(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '');
  }

  String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic> _buildPayload({
    required HarvestCreateInput input,
    required String uuid,
    required String receiptNumber,
    required String farmerName,
    required String cropName,
    required double totalGross,
    required double totalNet,
    required double totalPackaging,
    required double moistureContent,
    required int? collectionCenter,
    required int? receivedBy,
    required int? amcos,
    required int? mcu,
    required List<(HarvestBagInput, HarvestBagWeights)> bags,
  }) {
    return {
      'uuid': uuid,
      'farmer': input.farmer.id,
      'farmerUuid': input.farmer.uuid,
      'farmerName': farmerName,
      'farmerPhoneNumber': input.farmer.phoneNumber,
      'guarantor': input.farmer.id,
      'guarantorName': farmerName,
      'grossWeight': _round(totalGross),
      'netWeight': _round(totalNet),
      'packagingWeight': _round(totalPackaging),
      'moistureContent': _round(moistureContent),
      'uom': input.uom?.id,
      'packaging': input.packaging,
      'receiptNumber': receiptNumber,
      'amcos': amcos,
      'amcosName': input.farmer.amcosName ?? input.warehouse.amcosName,
      'mcu': mcu,
      'mcuName': input.farmer.mcuName,
      'receivedBy': receivedBy,
      'receivedByName': null,
      'crop': input.crop.id,
      'cropName': cropName,
      'cropGrade': input.cropGrade?.id,
      'cropGradeName': input.cropGrade?.gradeName,
      'collectionCenter': collectionCenter,
      'collectionCenterName': input.warehouse.name,
      'farmerBags': bags.map((item) {
        final bag = item.$1;
        final weights = item.$2;
        return {
          'netWeight': _round(weights.netWeight),
          'tag': bag.tag,
          'loadWeight': _round(weights.loadWeight),
          'grossWeight': _round(weights.grossWeight),
          'moistureWeight': _round(weights.moistureWeight),
          'moistureContent': _round(weights.moistureContent),
          'packagingWeight': _round(weights.packagingWeight),
        };
      }).toList(),
    };
  }

  List<Map<String, dynamic>> _readRows(dynamic data) {
    final raw = switch (data) {
      List() => data,
      Map<String, dynamic>() => data['results'] ?? data['records'] ?? data['data'],
      _ => const [],
    };
    return (raw as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
  }

  MeasurementUnitsCompanion? _measurementUnitFromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final name = json['name']?.toString();
    if (id == null || name == null || name.isEmpty) return null;
    return MeasurementUnitsCompanion.insert(
      id: Value(id),
      name: name,
      type: Value(json['type']?.toString()),
    );
  }

  CropGradesCompanion? _cropGradeFromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final crop = _asInt(json['crop']);
    final gradeName = json['gradeName']?.toString();
    if (id == null || crop == null || gradeName == null || gradeName.isEmpty) {
      return null;
    }
    return CropGradesCompanion.insert(
      id: Value(id),
      crop: crop,
      gradeName: gradeName,
      unitPrice: Value((json['unitPrice'] as num?)?.toDouble()),
      status: Value(json['status']?.toString()),
      amcos: Value(_asInt(json['amcos'])),
      amcosName: Value(json['amcosName']?.toString()),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _farmerName(Farmer farmer){
    return [
      farmer.firstName,
      farmer.middleName,
      farmer.lastName,
    ].whereType<String>().map((v) => v.trim()).where((v) => v.isNotEmpty).join(' ');
  }

  String _normalizeCropName(String value) {
    final text = value.trim();
    return switch (text.toLowerCase()) {
      'potato' => 'POTATO',
      'rice' => 'RICE',
      _ => text,
    };
  }

  String _generateReceiptNumber() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final suffix = (now.millisecondsSinceEpoch + Random().nextInt(9000)) % 10000;
    return 'RCPT-$date-${suffix.toString().padLeft(4, '0')}';
  }

  double _round(double value) {
    return double.parse(value.toStringAsFixed(3));
  }
}
