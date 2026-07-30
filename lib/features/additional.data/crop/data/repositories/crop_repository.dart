import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:warehouse_app/core/database/app_database.dart';

class CropRepository {
  final Dio _dio;
  final CropDao _dao;

  const CropRepository({
    required Dio dio,
    required CropDao dao,
  })  : _dio = dio,
        _dao = dao;

  Future<int> pullDownstream() async {
    try {
      final res = await _dio.get(
        '/crops',
        queryParameters: const {'page': 0, 'size': 100},
      );
      print('RAW RESPONSE for /crops: ${res.data}');
      final rows = _asRows(res.data);
      final validRows = rows.where(_isValidCropRow).toList();
      await _dao.upsertCrops(validRows.map(_fromJson).toList());
      final savedRows = await _dao.getAllCrops();
      developer.log(
        'Crop sync parsed=${rows.length}, valid=${validRows.length}, saved=${savedRows.length}',
        name: 'CropRepository',
      );
      return validRows.length;
    } on DioException catch (error, stackTrace) {
      developer.log(
        'Crop sync request failed',
        name: 'CropRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    } catch (error, stackTrace) {
      developer.log(
        'Crop sync save failed',
        name: 'CropRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  CropTableCompanion _fromJson(Map<String, dynamic> json) {
    return CropTableCompanion.insert(
      id: Value(_int(json['id'])),
      name: _normalizeCropName(_string(json['name'])),
      type: Value(_nullableString(json['type'])),
      uom: Value(_nullableString(json['uom'])),
      packaging: Value(_nullableString(json['packaging'])),
      grading: Value(_nullableString(json['grading'])),
      moistureContentComputation: Value(
        _bool(json['moistureContentComputation'] ??
            json['moisture_content_computation']),
      ),
      maxMoisureContent: Value(_double(json['maxMoisureContent'])),
      packagingWeight: Value(_double(json['packagingWeight'])),
    );
  }

  List<Map<String, dynamic>> _asRows(Object? data) {
    final raw = data is Map<String, dynamic>
        ? data['records'] ?? data['results'] ?? data['data']
        : data;
    final rows = <Map<String, dynamic>>[];

    void collect(Object? value) {
      if (value is Map<String, dynamic>) {
        rows.add(value);
        return;
      }
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
      }
    }

    collect(raw);
    return rows;
  }

  bool _isValidCropRow(Map<String, dynamic> json) {
    return _int(json['id']) > 0 && _string(json['name']).trim().isNotEmpty;
  }

  int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _double(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _bool(Object? value) {
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  String _string(Object? value) => value?.toString() ?? '';

  String _normalizeCropName(String value) {
    final text = value.trim();
    return switch (text.toLowerCase()) {
      'potato' => 'POTATO',
      'rice' => 'RICE',
      _ => text,
    };
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
