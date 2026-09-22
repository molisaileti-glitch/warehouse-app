import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/features/farmer/data/repositories/drift_farmer_repository.dart';
import 'package:warehouse_app/features/farmer/domain/repositories/farmer_repository.dart';

final farmerRepoProvider = Provider<FarmerRepository>((ref) {
  return DriftFarmerRepository(
    dao: ref.watch(farmerDaoProvider),
    cropDao: ref.watch(cropDaoProvider),
    dio: ref.watch(apiClientProvider).dio,
  );
});

final allFarmersProvider = StreamProvider<List<Farmer>>((ref) {
  final mcuId = ref.watch(currentUserMcuProvider).valueOrNull;
  if (mcuId == null) return const Stream.empty();
  return ref.watch(farmerDaoProvider).watchFarmersByMcu(mcuId);
});

final farmerByIdProvider = StreamProvider.family<Farmer?, int>((ref, id) {
  return ref.watch(farmerRepoProvider).watchFarmerById(id);
});

final farmerDependantsProvider =
    StreamProvider.family<List<FarmerDependant>, int>((ref, farmerId) {
  return ref.watch(farmerRepoProvider).watchDependantsForFarmer(farmerId);
});
