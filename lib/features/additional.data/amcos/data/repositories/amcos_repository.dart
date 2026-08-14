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
      await _dao.upsertAmcosList(rows.map(_fromJson).toList());
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
    await _dao.upsertAmcosList(rows.map(_fromJson).toList());
    developer.log(
      '[AmcosSync] requestedIds=$ids matched=${rows.length}',
      name: 'sync.amcos',
    );
    return rows.length;
  }

  AmcosTableCompanion _fromJson(Map<String, dynamic> json) {
    return AmcosTableCompanion.insert(
      id: Value((json['id'])),
      name: _string(json['name']),
      memberCategory: _string(json['memberCategory'] ?? json['member_category']),
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
}
