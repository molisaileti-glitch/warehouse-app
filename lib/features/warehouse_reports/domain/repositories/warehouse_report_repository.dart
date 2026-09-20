import 'dart:io';

import '../models/warehouse_report_models.dart';

class WarehouseActivityReportQuery {
  const WarehouseActivityReportQuery({
    required this.collectionCenterUuid,
    required this.fromDate,
    required this.toDate,
    this.cropId,
    this.activityType,
    this.workerId,
    this.page,
    this.size,
  });

  final String collectionCenterUuid;
  final DateTime fromDate;
  final DateTime toDate;
  final int? cropId;
  final String? activityType;
  final int? workerId;
  final int? page;
  final int? size;
}

class WarehouseReportExportData {
  const WarehouseReportExportData({
    required this.fileName,
    required this.warehouseName,
    required this.reportType,
    required this.cropName,
    required this.periodLabel,
    required this.activities,
    required this.users,
    required this.labels,
  });

  final String fileName;
  final String warehouseName;
  final String reportType;
  final String cropName;
  final String periodLabel;
  final List<WarehouseActivityReportRecord> activities;
  final List<WarehouseWorkerReportRecord> users;
  final WarehouseReportLabels labels;
}

class WarehouseReportLabels {
  const WarehouseReportLabels({
    required this.workbookTitle,
    required this.summarySheet,
    required this.userActivitySheet,
    required this.activityDetailsSheet,
    required this.warehouse,
    required this.reportType,
    required this.crop,
    required this.period,
    required this.summary,
    required this.totalBags,
    required this.totalNetWeight,
    required this.totalWeightChange,
    required this.worker,
    required this.roleStatus,
    required this.recordsDone,
    required this.receivedBags,
    required this.dispatchedBags,
    required this.adjustedBags,
    required this.date,
    required this.activity,
    required this.bagTag,
    required this.netWeight,
    required this.performedBy,
    required this.farmerName,
    required this.farmerPhone,
    required this.recipientName,
    required this.recipientType,
    required this.recipientPhone,
    required this.receiptNumber,
    required this.reason,
    required this.previousWeight,
    required this.currentWeight,
    required this.netWeightChange,
    required this.owner,
    required this.receiving,
    required this.dispatch,
    required this.stockAdjustment,
    required this.activityFallback,
  });

  final String workbookTitle;
  final String summarySheet;
  final String userActivitySheet;
  final String activityDetailsSheet;
  final String warehouse;
  final String reportType;
  final String crop;
  final String period;
  final String summary;
  final String totalBags;
  final String totalNetWeight;
  final String totalWeightChange;
  final String worker;
  final String roleStatus;
  final String recordsDone;
  final String receivedBags;
  final String dispatchedBags;
  final String adjustedBags;
  final String date;
  final String activity;
  final String bagTag;
  final String netWeight;
  final String performedBy;
  final String farmerName;
  final String farmerPhone;
  final String recipientName;
  final String recipientType;
  final String recipientPhone;
  final String receiptNumber;
  final String reason;
  final String previousWeight;
  final String currentWeight;
  final String netWeightChange;
  final String owner;
  final String receiving;
  final String dispatch;
  final String stockAdjustment;
  final String activityFallback;
}

abstract class WarehouseReportRepository {
  Future<List<WarehouseActivityReportRecord>> fetchActivity(
    WarehouseActivityReportQuery query,
  );

  Future<List<WarehouseWorkerReportRecord>> fetchWorkers({
    required String collectionCenterUuid,
    required DateTime fromDate,
    required DateTime toDate,
    int? cropId,
  });

  Future<File> saveActivityExcel({
    required WarehouseReportExportData report,
  });
}
