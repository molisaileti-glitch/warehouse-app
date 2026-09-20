import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/features/warehouse_reports/data/repositories/dio_warehouse_report_repository.dart';
import 'package:warehouse_app/features/warehouse_reports/domain/repositories/warehouse_report_repository.dart';

final warehouseReportRepositoryProvider =
    Provider<WarehouseReportRepository>((ref) {
  return LocalWarehouseReportRepository(
    database: ref.watch(appDatabaseProvider),
  );
});
