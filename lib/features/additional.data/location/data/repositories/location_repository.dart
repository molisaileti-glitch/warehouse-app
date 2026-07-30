import 'package:dio/dio.dart';
import 'package:warehouse_app/core/database/app_database.dart';

class LocationRepository {
  final Dio _dio;
  final RegionDao _regionDao;
  final DistrictDao _districtDao;
  final WardDao _wardDao;
  final VillageDao _villageDao;

  LocationRepository({
    required Dio dio,
    required RegionDao regionDao,
    required DistrictDao districtDao,
    required WardDao wardDao,
    required VillageDao villageDao,
  })  : _dio = dio,
        _regionDao = regionDao,
        _districtDao = districtDao,
        _wardDao = wardDao,
        _villageDao = villageDao;

  Future<int> pullDownstream({DateTime? since}) async {
    var count = 0;
    count += await _pullRegions(since: since);
    count += await _pullDistricts(since: since);
    count += await _pullWards(since: since);
    count += await _pullVillages(since: since);
    return count;
  }

  Future<int> _pullRegions({DateTime? since}) async {
    final rows = await _getList('/regions', since: since);
    await _regionDao.upsertRegions(
      rows
          .map(
            (json) => RegionsTableCompanion.insert(
              id: Value(json['id']),
              name: _string(json['name']),
              postCode: _string(json['postCode'] ?? json['post_code']),
            ),
          )
          .toList(),
    );
    return rows.length;
  }

  Future<int> _pullDistricts({DateTime? since}) async {
    final rows = await _getList('/districts', since: since);
    await _districtDao.upsertDistricts(
      rows
          .map(
            (json) => DistrictsTableCompanion.insert(
              id: Value(json['id']),
              name: _string(json['name']),
              region: _int(json['region']),
              regionName: _string(json['regionName'] ?? json['region_name']),
            ),
          )
          .toList(),
    );
    return rows.length;
  }

  Future<int> _pullWards({DateTime? since}) async {
    final rows = await _getList('/wards', since: since);
    await _wardDao.upsertWards(
      rows
          .map(
            (json) => WardsTableCompanion.insert(
              id: Value(json['id']),
              name: _string(json['name']),
              district: _int(json['district']),
              districtName:
                  _string(json['districtName'] ?? json['district_name']),
            ),
          )
          .toList(),
    );
    return rows.length;
  }

  Future<int> _pullVillages({DateTime? since}) async {
    final rows = await _getList('/villages', since: since);
    await _villageDao.upsertVillages(
      rows
          .map(
            (json) => VillagesTableCompanion.insert(
              id: Value(json['id']),
              name: _string(json['name']),
              ward: _int(json['ward']),
              wardName: _string(json['wardName'] ?? json['ward_name']),
            ),
          )
          .toList(),
    );
    return rows.length;
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    DateTime? since,
  }) async {
    try {
      final res = await _dio.get(
        path,
        queryParameters: since == null
            ? null
            : {'updated_since': since.toIso8601String()},
      );
      final rows = _asList(res.data);
      print('Reference sync $path rows=${rows.length}');
      return rows;
    } on DioException {
      return const [];
    }
  }

  List<Map<String, dynamic>> _asList(Object? data) {
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

  int _int(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  String _string(Object? value) => value?.toString() ?? '';
}
