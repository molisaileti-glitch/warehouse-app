import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:warehouse_app/core/database/app_database.dart';

class AmcosRepository {
  final Dio _dio;
  final AmcosDao _dao;

  AmcosRepository({
    required Dio dio,
    required AmcosDao dao,
  })  : _dio = dio,
        _dao = dao;

  Future<AmcosCreateResult> create({
    required String name,
    required String memberCategory,
    required String registrationNumber,
    required String tinNumber,
    required int mcuId,
    required int regionId,
    required int districtId,
    required int wardId,
    required int villageId,
    required String phoneNumber,
    required String email,
    required String contactPersonName,
    required String contactPersonPhoneNumber,
    required String contactPersonEmail,
    required String contactPersonTitle,
    required String website,
    required int cropId,
  }) async {
    try {
      final response = await _dio.post('/amcos', data: {
        'name': name,
        'memberCategory': memberCategory,
        'registrationNumber': registrationNumber,
        'tinNumber': tinNumber,
        'mcu': mcuId,
        'region': regionId,
        'district': districtId,
        'ward': wardId,
        'village': villageId,
        'phoneNumber': phoneNumber,
        'email': email,
        'contactPersonName': contactPersonName,
        'contactPersonPhoneNumber': contactPersonPhoneNumber,
        'contactPersonEmail': contactPersonEmail,
        'contactPersonTitle': contactPersonTitle,
        'website': website,
        'crops': [cropId],
        'idCounter': 0,
      });

      final data = response.data;
      if (data is! Map<String, dynamic> || _int(data['id']) <= 0) {
        return AmcosCreateResult.failure('Invalid AMCOS response');
      }

      await _ensureReferences(data);
      await _dao.upsertAmcos(_fromJson(data));
      return AmcosCreateResult.success(amcosId: _int(data['id']));
    } on DioException catch (error) {
      return AmcosCreateResult.failure(_dioMessage(error));
    } catch (error) {
      return AmcosCreateResult.failure(error.toString());
    }
  }

  Future<int> pullDownstream({DateTime? since, int? mcuId}) async {
    try {
      final res = await _dio.get(
        mcuId == null ? '/amcos' : '/amcos/mcu/$mcuId',
        queryParameters: mcuId != null || since == null
            ? null
            : {'updated_since': since.toIso8601String()},
      );
      final rows = _asList(res.data);
      developer.log(
        '[AmcosSync] source=${mcuId == null ? 'catalog' : 'mcu/$mcuId'} '
        'rows=${rows.length}',
        name: 'sync.amcos',
      );
      await _upsertRows(rows);
      return rows.length;
    } on DioException {
      return 0;
    }
  }

  Future<int> pullByIds(Set<int> ids, {DateTime? since}) async {
    if (ids.isEmpty) return 0;

    final res = await _dio.get(
      '/amcos',
      queryParameters:
          since == null ? null : {'updated_since': since.toIso8601String()},
    );
    final rows = _asList(res.data)
        .where((row) => ids.contains(_int(row['id'])))
        .toList();
    await _upsertRows(rows);
    developer.log(
      '[AmcosSync] requestedIds=$ids matched=${rows.length}',
      name: 'sync.amcos',
    );
    return rows.length;
  }

  Future<void> _upsertRows(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    for (final row in rows) {
      await _ensureReferences(row);
    }
    await _dao.upsertAmcosList(rows.map(_fromJson).toList());
  }

  Future<void> _ensureReferences(Map<String, dynamic> json) {
    return _dao.ensureAmcosReferences(
      regionId: _int(json['region']),
      regionName: _string(json['regionName'] ?? json['region_name']),
      districtId: _int(json['district']),
      districtName: _string(json['districtName'] ?? json['district_name']),
      wardId: _int(json['ward']),
      wardName: _string(json['wardName'] ?? json['ward_name']),
      villageId: _int(json['village']),
      villageName: _string(json['villageName'] ?? json['village_name']),
    );
  }

  AmcosTableCompanion _fromJson(Map<String, dynamic> json) {
    return AmcosTableCompanion.insert(
      id: Value((json['id'])),
      name: _string(json['name']),
      memberCategory:
          _string(json['memberCategory'] ?? json['member_category']),
      registrationNumber:
          _string(json['registrationNumber'] ?? json['registration_number']),
      tinNumber: _string(json['tinNumber'] ?? json['tin_number']),
      mcu: _int(json['mcu']),
      mcuName: _string(json['mcuName'] ?? json['mcu_name']),
      region: _int(json['region']),
      regionName: _string(json['regionName'] ?? json['region_name']),
      district: _int(json['district']),
      districtName: _string(json['districtName'] ?? json['district_name']),
      ward: _int(json['ward']),
      wardName: _string(json['wardName'] ?? json['ward_name']),
      village: _int(json['village']),
      villageName: _string(json['villageName'] ?? json['village_name']),
      phoneNumber: _string(json['phoneNumber'] ?? json['phone_number']),
      email: _string(json['email']),
      contactPersonName:
          _string(json['contactPersonName'] ?? json['contact_person_name']),
      contactPersonPhoneNumber: _string(
        json['contactPersonPhoneNumber'] ?? json['contact_person_phone_number'],
      ),
      contactPersonEmail:
          _string(json['contactPersonEmail'] ?? json['contact_person_email']),
      contactPersonTitle:
          _string(json['contactPersonTitle'] ?? json['contact_person_title']),
      website: _string(json['website']),
      status: _string(json['status']),
      crops: _string(json['crops']),
      idCounter: _int(json['idCounter'] ?? json['id_counter']),
    );
  }

  List<Map<String, dynamic>> _asList(Object? data) {
    final raw = data is Map<String, dynamic>
        ? data['content'] ?? data['records'] ?? data['results'] ?? data['data']
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

  int _int(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  String _string(Object? value) => value?.toString() ?? '';

  String _dioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['detail', 'message', 'error', 'errors']) {
        final value = data[key];
        if (value != null) return value.toString();
      }
    }
    return error.message ?? 'Unable to create AMCOS';
  }
}

class AmcosCreateResult {
  final bool success;
  final int? amcosId;
  final String? error;

  const AmcosCreateResult._({
    required this.success,
    this.amcosId,
    this.error,
  });

  factory AmcosCreateResult.success({required int amcosId}) =>
      AmcosCreateResult._(success: true, amcosId: amcosId);

  factory AmcosCreateResult.failure(String error) =>
      AmcosCreateResult._(success: false, error: error);
}
