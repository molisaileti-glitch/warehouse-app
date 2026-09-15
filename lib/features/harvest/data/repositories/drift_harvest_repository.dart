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
  final WarehouseOperationsDao _warehouseOperationsDao;
  final AuditLogDao _auditDao;
  final Dio _dio;
  final String _currentUserId;

  DriftHarvestRepository({
    required HarvestDao dao,
    required FarmerDao farmerDao,
    required WarehouseDao warehouseDao,
    required CropDao cropDao,
    required WarehouseOperationsDao warehouseOperationsDao,
    required AuditLogDao auditDao,
    required Dio dio,
    required String currentUserId,
  })  : _dao = dao,
        _farmerDao = farmerDao,
        _warehouseDao = warehouseDao,
        _cropDao = cropDao,
        _warehouseOperationsDao = warehouseOperationsDao,
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
    final calculatedBags = input.bags
        .map((bag) => (
              id: newUuid(),
              input: bag,
              weights: bag.calculate(),
            ))
        .toList();
    final totalGross = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.weights.grossWeight,
    );
    final totalNet = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.weights.netWeight,
    );
    final totalPackaging = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.weights.packagingWeight,
    );
    final totalLoad = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.weights.loadWeight,
    );
    final totalMoisture = calculatedBags.fold<double>(
      0,
      (sum, item) => sum + item.weights.moistureWeight,
    );
    final moistureContent =
        totalLoad <= 0 ? 0.0 : (totalMoisture / totalLoad) * 100;
    final collectionCenter = int.tryParse(input.warehouse.id);
    final receivedBy = int.tryParse(_currentUserId);
    final mcu = input.farmer.mcu == 0 ? null : input.farmer.mcu;
    final amcos =
        input.farmer.amcos == 0 ? input.warehouse.amcos : input.farmer.amcos;

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
      final bag = item.input;
      final weights = item.weights;
      return FarmerHarvestBagsCompanion.insert(
        id: item.id,
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

    await _dao.insertPendingHarvestWithBags(
      harvest: harvestCompanion,
      bags: bagCompanions,
      queueEntry: SyncQueueCompanion.insert(
        entityType: 'farmerHarvests',
        entityId: harvestUuid,
        operation: 'create',
        payload: jsonEncode(
          _buildPayload(
            input: input,
            uuid: harvestUuid,
            receiptNumber: receiptNumber,
            farmerName: farmerName,
            totalGross: totalGross,
            totalNet: totalNet,
            totalPackaging: totalPackaging,
            moistureContent: moistureContent,
            collectionCenter: collectionCenter,
            amcos: amcos,
            mcu: mcu,
            bags: calculatedBags,
          ),
        ),
      ),
    );

    await _applyLocalInventoryIncrease(
      warehouse: input.warehouse,
      crop: input.crop,
      totalBags: input.bags.length,
      totalGrossWeight: totalGross,
      totalPackagingWeight: totalPackaging,
      totalNetWeight: totalNet,
      mcu: mcu,
      timestamp: now,
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
      final result = await _saveServerHarvests(
        _readRows(response.data),
        fallbackAmcosId: amcosId,
      );
      saved += result.saved;
      skippedMissingDependency += result.skippedMissingDependency;
    }

    developer.log(
      '[HarvestSync] amcosIds=$sortedIds saved=$saved '
      'skippedMissingDependency=$skippedMissingDependency',
      name: 'sync.harvest',
    );
    return saved;
  }

  @override
  Future<int> pullFromCollectionCenter({
    required int collectionCenterId,
  }) async {
    final response = await _dio.get(
      '/farmer-harvests/collection-center/$collectionCenterId',
    );
    final result = await _saveServerHarvests(_readRows(response.data));
    developer.log(
      '[HarvestSync] collectionCenter=$collectionCenterId '
      'saved=${result.saved} '
      'skippedMissingDependency=${result.skippedMissingDependency}',
      name: 'sync.harvest',
    );
    return result.saved;
  }

  Future<({int saved, int skippedMissingDependency})> _saveServerHarvests(
    List<Map<String, dynamic>> rows, {
    int? fallbackAmcosId,
  }) async {
    var saved = 0;
    var skippedMissingDependency = 0;

    for (final row in rows) {
      final serverId = _nullableInt(row['id']);
      // 'farmerId' is the server integer ID; 'farmer' is the farmerUuid
      // (backend naming inconsistency — both may exist in the response).
      final farmerId = _nullableInt(row['farmerId']);
      // The 'farmer' field is the farmerUuid string, NOT an integer.
      final farmerUuidFromResponse = _nullableString(row['farmer']);
      final cropId = _nullableInt(row['crop']);
      final collectionCenterId = _nullableInt(row['collectionCenter']);
      if (serverId == null ||
          (farmerId == null && farmerUuidFromResponse == null) ||
          cropId == null ||
          collectionCenterId == null) {
        developer.log(
          '[HarvestSync] skipped malformed harvest id=${row['id']} '
          'farmer=${row['farmerId'] ?? row['farmer']} crop=${row['crop']} '
          'collectionCenter=${row['collectionCenter']}',
          name: 'sync.harvest',
        );
        skippedMissingDependency++;
        continue;
      }

      // Try three lookups: serverId → localId → UUID.
      // The 'farmer' field from the response IS the farmerUuid.
      final farmer = (farmerId != null
              ? (await _farmerDao.getFarmerByServerId(farmerId) ??
                  await _farmerDao.getFarmerById(farmerId))
              : null) ??
          (farmerUuidFromResponse != null
              ? await _farmerDao.getFarmerByUuid(farmerUuidFromResponse)
              : null);
      final crop = await _cropDao.getCropById(cropId);
      final warehouse =
          await _warehouseDao.getWarehouseById(collectionCenterId.toString());
      if (farmer == null || crop == null || warehouse == null) {
        developer.log(
          '[HarvestSync] skipped id=$serverId missing '
          'farmer=${farmer == null} crop=${crop == null} '
          'warehouse=${warehouse == null}',
          name: 'sync.harvest',
        );
        skippedMissingDependency++;
        continue;
      }


      final rawUuid = _nullableString(row['uuid']);
      final uuid = rawUuid ?? 'server-harvest-$serverId';
      final guarantorId = _nullableInt(row['guarantor']);
      final guarantor = guarantorId == null
          ? null
          : await _farmerDao.getFarmerByServerId(guarantorId) ??
              await _farmerDao.getFarmerById(guarantorId);
      final receivedAt = _date(row['receivedAt']) ?? DateTime.now();

      await _dao.insertHarvestWithBags(
        harvest: FarmerHarvestsCompanion.insert(
          uuid: uuid,
          serverId: Value(serverId),
          farmer: farmer.id,
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
          amcos: Value(_nullableInt(row['amcos']) ?? fallbackAmcosId),
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

    return (
      saved: saved,
      skippedMissingDependency: skippedMissingDependency,
    );
  }

  String? _validate(HarvestCreateInput input) {
    if (input.bags.isEmpty) return 'Add at least one bag.';
    for (final bag in input.bags) {
      if (bag.grossWeight <= 0) {
        return 'Gross weight must be greater than zero.';
      }
      if (bag.packagingWeight < 0) {
        return 'Packaging weight cannot be negative.';
      }
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
    required double totalGross,
    required double totalNet,
    required double totalPackaging,
    required double moistureContent,
    required int? collectionCenter,
    required int? amcos,
    required int? mcu,
    required List<
            ({String id, HarvestBagInput input, HarvestBagWeights weights})>
        bags,
  }) {
    return {
      'uuid': uuid,
      'farmerUuid': input.farmer.uuid,
      'guarantor': input.farmer.id.toString(),
      'guarantorName': farmerName,
      'grossWeight': _round(totalGross),
      'netWeight': _round(totalNet),
      'packagingWeight': _round(totalPackaging),
      'moistureContent': _round(moistureContent),
      'uom': input.uom?.id.toString(),
      'packaging': input.packaging,
      'receiptNumber': receiptNumber,
      'batchRef': input.batchRef,
      'isBatchMode': input.isBatchMode,
      'amcos': amcos,
      'mcu': mcu,
      'crop': input.crop.id,
      'cropGrade': input.cropGrade?.id,
      'collectionCenter': collectionCenter,
      'farmerBags': bags.map((item) {
        final bag = item.input;
        final weights = item.weights;
        return {
          'uuid': item.id,
          'netWeight': _round(weights.netWeight),
          'tagNumber': bag.tag,
          'loadWeight': _round(weights.loadWeight),
          'grossWeight': _round(weights.grossWeight),
          'moistureWeight': _round(weights.moistureWeight),
          'moistureContent': _round(weights.moistureContent),
          'packagingWeight': _round(weights.packagingWeight),
          'tagType': bag.tagType,
        };
      }).toList(),
    };
  }

  Future<void> _applyLocalInventoryIncrease({
    required Warehouse warehouse,
    required Crop crop,
    required int totalBags,
    required double totalGrossWeight,
    required double totalPackagingWeight,
    required double totalNetWeight,
    required int? mcu,
    required DateTime timestamp,
  }) async {
    final current = await _warehouseOperationsDao.getInventoryByCrop(
      warehouseId: warehouse.id,
      cropId: crop.id,
    );
    final collectionCenter = int.tryParse(warehouse.id);
    final collectionCenterUuid =
        warehouse.uuid.isNotEmpty ? warehouse.uuid : warehouse.id;

    await _warehouseOperationsDao.upsertInventory(
      WarehouseInventoryItemsCompanion.insert(
        uuid: current?.uuid ?? newUuid(),
        serverId: Value(current?.serverId),
        warehouseId: warehouse.id,
        collectionCenter: Value(current?.collectionCenter ?? collectionCenter),
        collectionCenterUuid: current?.collectionCenterUuid.isNotEmpty == true
            ? current!.collectionCenterUuid
            : collectionCenterUuid,
        collectionCenterName:
            Value(current?.collectionCenterName ?? warehouse.name),
        amcos: Value(current?.amcos ?? warehouse.amcos),
        amcosName: Value(current?.amcosName ?? warehouse.amcosName),
        mcu: Value(current?.mcu ?? mcu),
        mcuName: Value(current?.mcuName),
        crop: crop.id,
        cropName: crop.name,
        totalBags: Value((current?.totalBags ?? 0) + totalBags),
        totalGrossWeight: Value(
          _round((current?.totalGrossWeight ?? 0) + totalGrossWeight),
        ),
        totalPackagingWeight: Value(
          _round((current?.totalPackagingWeight ?? 0) + totalPackagingWeight),
        ),
        totalNetWeight: Value(
          _round((current?.totalNetWeight ?? 0) + totalNetWeight),
        ),
        createdAt: Value(current?.createdAt ?? timestamp),
        updatedAt: Value(timestamp),
      ),
    );
    developer.log(
      '[HarvestInventory] warehouse=${warehouse.id} crop=${crop.id} '
      'bags=+$totalBags gross=+${_round(totalGrossWeight)} '
      'net=+${_round(totalNetWeight)}',
      name: 'inventory.harvest',
    );
  }

  List<Map<String, dynamic>> _readRows(dynamic data) {
    final raw = switch (data) {
      List() => data,
      Map<String, dynamic>() =>
        data['content'] ?? data['results'] ?? data['records'] ?? data['data'],
      _ => const [],
    };
    return (raw as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
  }

  MeasurementUnitsCompanion? _measurementUnitFromJson(
      Map<String, dynamic> json) {
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

  String _farmerName(Farmer farmer) {
    return [
      farmer.firstName,
      farmer.middleName,
      farmer.lastName,
    ]
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .join(' ');
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
    final suffix =
        (now.millisecondsSinceEpoch + Random().nextInt(9000)) % 10000;
    return 'RCPT-$date-${suffix.toString().padLeft(4, '0')}';
  }

  double _round(double value) {
    return double.parse(value.toStringAsFixed(3));
  }
}
