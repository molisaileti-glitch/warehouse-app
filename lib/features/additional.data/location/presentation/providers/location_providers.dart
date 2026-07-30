import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/features/additional.data/location/data/repositories/location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(
    dio: ref.watch(apiClientProvider).dio,
    regionDao: ref.watch(regionDaoProvider),
    districtDao: ref.watch(districtDaoProvider),
    wardDao: ref.watch(wardDaoProvider),
    villageDao: ref.watch(villageDaoProvider),
  );
});
