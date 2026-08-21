import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/additional.data/amcos/data/repositories/amcos_repository.dart';

final amcosRepositoryProvider = Provider<AmcosRepository>((ref) {
  return AmcosRepository(
    dio: ref.watch(apiClientProvider).dio,
    dao: ref.watch(amcosDaoProvider),
  );
});

final amcosByMcuProvider =
    StreamProvider.family<List<Amcos>, int>((ref, mcuId) {
  return ref.watch(amcosDaoProvider).watchAmcosByMcu(mcuId);
});
