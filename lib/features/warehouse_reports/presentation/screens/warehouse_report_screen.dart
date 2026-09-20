import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/owner/widgets/owner_drawer.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/features/warehouse_reports/data/services/report_file_action_service.dart';
import 'package:warehouse_app/features/warehouse_reports/domain/models/warehouse_report_models.dart';
import 'package:warehouse_app/features/warehouse_reports/domain/repositories/warehouse_report_repository.dart';
import 'package:warehouse_app/features/warehouse_reports/presentation/providers/warehouse_report_providers.dart';
import 'package:warehouse_app/features/worker/presentation/screens/worker_drawer.dart';

class WarehouseReportScreen extends ConsumerStatefulWidget {
  const WarehouseReportScreen({
    super.key,
    required this.ownerFlow,
  });

  final bool ownerFlow;

  @override
  ConsumerState<WarehouseReportScreen> createState() =>
      _WarehouseReportScreenState();
}

class _WarehouseReportScreenState extends ConsumerState<WarehouseReportScreen> {
  final _displayDateFormat = DateFormat('d MMM yyyy');
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  String? _warehouseId;
  int? _cropId;
  String? _activityType;
  String _period = '7';
  bool _loading = false;
  bool _exporting = false;
  bool _hasGenerated = false;
  bool _showFilters = true;
  List<WarehouseActivityReportRecord> _activities = const [];
  List<WarehouseWorkerReportRecord> _users = const [];

  @override
  Widget build(BuildContext context) {
    final s = _ReportStrings(context);
    final warehousesAsync = widget.ownerFlow
        ? ref.watch(currentOwnerWarehousesProvider)
        : _workerWarehouses(ref);
    final crops = ref.watch(allCropsProvider).valueOrNull ?? const <Crop>[];

    return Scaffold(
      drawer: widget.ownerFlow ? const OwnerDrawer() : const WorkerDrawer(),
      appBar: AppBar(
        title: Text(s.warehouseReports),
        actions: const [SyncIndicator()],
      ),
      body: warehousesAsync.when(
        data: (warehouses) {
          final activeWarehouse = _selectedWarehouse(warehouses);
          final activeCrop = _selectedCrop(crops);
          return RefreshIndicator(
            onRefresh: () => _loadReports(activeWarehouse),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Text(
                  s.reportSubtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                if (!_hasGenerated || _showFilters) ...[
                  _ReportTypeSelector(
                    selected: _activityType,
                    onChanged: (value) => setState(() => _activityType = value),
                  ),
                  const SizedBox(height: 14),
                  _FilterCard(
                    warehouses: warehouses,
                    selectedWarehouseId: activeWarehouse?.id,
                    crops: crops,
                    cropId: _cropId,
                    period: _period,
                    fromDate: _fromDate,
                    toDate: _toDate,
                    displayDateFormat: _displayDateFormat,
                    onWarehouseChanged: (value) {
                      setState(() => _warehouseId = value);
                    },
                    onCropChanged: (value) {
                      setState(() => _cropId = value);
                    },
                    onPeriodChanged: _setPeriod,
                    onFromDate: () => _pickDate(isFrom: true),
                    onToDate: () => _pickDate(isFrom: false),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading || activeWarehouse == null
                          ? null
                          : () => _loadReports(activeWarehouse),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.summarize_outlined),
                      label: Text(
                        _loading ? s.generating : s.generateReport,
                      ),
                    ),
                  ),
                ],
                if (_hasGenerated && !_showFilters) ...[
                  _GeneratedReportHeader(
                    reportTitle: _reportTitle,
                    warehouseName: activeWarehouse?.name ?? '-',
                    cropName: activeCrop?.name ?? s.allCrops,
                    fromDate: _fromDate,
                    toDate: _toDate,
                    displayDateFormat: _displayDateFormat,
                    onChangeFilters: () => setState(() => _showFilters = true),
                    onExport: _activities.isEmpty || _exporting
                        ? null
                        : () => _exportReport(activeWarehouse, activeCrop),
                  ),
                  const SizedBox(height: 16),
                  _SummaryStrip(
                    activities: _activities,
                    activityType: _activityType,
                  ),
                  if (widget.ownerFlow && _users.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle(s.userActivity),
                    const SizedBox(height: 8),
                    ..._users.map(_UserReportCard.new),
                  ],
                  const SizedBox(height: 20),
                  _SectionTitle(s.activity),
                  const SizedBox(height: 8),
                  if (_activities.isEmpty)
                    EmptyState(
                      icon: Icons.summarize_outlined,
                      title: s.noReportRecords,
                      subtitle: s.tryDifferentFilters,
                    )
                  else
                    ..._activities.map(_ActivityReportCard.new),
                ],
              ],
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: '$error'),
      ),
    );
  }

  String get _reportTitle {
    return switch (_activityType) {
      'RECEIVING' => _strings.receivingReport,
      'DISPATCH' => _strings.dispatchReport,
      'STOCK_ADJUSTMENT' => _strings.adjustmentReport,
      _ => _strings.activityReport,
    };
  }

  _ReportStrings get _strings => _ReportStrings(context);

  AsyncValue<List<Warehouse>> _workerWarehouses(WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final worker = userId == null
        ? const AsyncValue<User?>.data(null)
        : ref.watch(workerByIdProvider(userId));
    final warehouseId = worker.valueOrNull?.warehouseId;
    if (warehouseId == null) return const AsyncValue.data(<Warehouse>[]);
    final warehouse = ref.watch(warehouseByIdProvider(warehouseId));
    return warehouse.whenData(
      (value) => value == null ? const <Warehouse>[] : <Warehouse>[value],
    );
  }

  Warehouse? _selectedWarehouse(List<Warehouse> warehouses) {
    if (warehouses.isEmpty) return null;
    final selected = _warehouseId;
    if (selected != null) {
      for (final warehouse in warehouses) {
        if (warehouse.id == selected) return warehouse;
      }
    }
    return warehouses.first;
  }

  Crop? _selectedCrop(List<Crop> crops) {
    final selected = _cropId;
    if (selected == null) return null;
    for (final crop in crops) {
      if (crop.id == selected) return crop;
    }
    return null;
  }

  void _setPeriod(String value) {
    final now = DateTime.now();
    setState(() {
      _period = value;
      if (value == 'today') {
        _fromDate = DateTime(now.year, now.month, now.day);
        _toDate = now;
      } else if (value == '7') {
        _fromDate = now.subtract(const Duration(days: 7));
        _toDate = now;
      } else if (value == '30') {
        _fromDate = now.subtract(const Duration(days: 30));
        _toDate = now;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: current,
    );
    if (picked == null) return;
    setState(() {
      _period = 'custom';
      if (isFrom) {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate.isAfter(_toDate)) _fromDate = picked;
      }
    });
  }

  Future<void> _loadReports(Warehouse? warehouse) async {
    if (warehouse == null) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(warehouseReportRepositoryProvider);
      final query = WarehouseActivityReportQuery(
        collectionCenterUuid: warehouse.uuid,
        fromDate: _fromDate,
        toDate: _toDate,
        cropId: _cropId,
        activityType: _activityType,
        page: 1,
        size: 100,
      );
      final activities = await repo.fetchActivity(query);
      final users = widget.ownerFlow
          ? await repo.fetchWorkers(
              collectionCenterUuid: warehouse.uuid,
              fromDate: _fromDate,
              toDate: _toDate,
              cropId: _cropId,
            )
          : const <WarehouseWorkerReportRecord>[];
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _users = users;
        _hasGenerated = true;
        _showFilters = false;
      });
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: _strings.warehouseReports,
          description: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportReport(Warehouse? warehouse, Crop? crop) async {
    if (warehouse == null) return;
    final s = _strings;
    final confirmed = await showConfirmDialog(
      context,
      title: s.exportReportQuestion,
      message: s.createExcelForFilters,
      confirmLabel: s.createReport,
    );
    if (!confirmed || !mounted) return;

    setState(() => _exporting = true);
    var loadingShown = false;
    try {
      showLoadingDialog(
        context,
        title: s.creatingExcelReport,
        description: s.pleaseWait,
      );
      loadingShown = true;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final repo = ref.read(warehouseReportRepositoryProvider);
      final fileName = _exportFileName(warehouse, crop);
      final file = await repo.saveActivityExcel(
        report: WarehouseReportExportData(
          fileName: fileName,
          warehouseName: warehouse.name,
          reportType: _reportTypeLabel,
          cropName: crop?.name ?? s.allCrops,
          periodLabel: _periodLabel,
          activities: _activities,
          users: _users,
          labels: s.excelLabels,
        ),
      );
      if (!mounted) return;
      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
      await _showReportReadyDialog(file.path, fileName);
    } catch (error) {
      if (mounted) {
        if (loadingShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingShown = false;
        }
        await showErrorDialog(
          context,
          title: s.reportExportFailed,
          description: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String get _reportTypeLabel {
    return switch (_activityType) {
      'RECEIVING' => _strings.receiving,
      'DISPATCH' => _strings.dispatch,
      'STOCK_ADJUSTMENT' => _strings.adjustment,
      _ => _strings.activity,
    };
  }

  String get _periodLabel {
    return '${_displayDateFormat.format(_fromDate)} - ${_displayDateFormat.format(_toDate)}';
  }

  String _exportFileName(Warehouse warehouse, Crop? crop) {
    final warehouseName = _filePart(warehouse.name);
    final reportType = _filePart(_reportTypeLabel);
    final cropName = _filePart(crop?.name ?? 'All_Crops');
    final from = DateFormat('dMMM').format(_fromDate);
    final to = DateFormat('dMMMyyyy').format(_toDate);
    final generatedAt = DateFormat('HHmmssSSS').format(DateTime.now());
    return '${warehouseName}_${reportType}_${cropName}_$from-${to}_$generatedAt.xlsx';
  }

  String _filePart(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
  }

  Future<void> _showReportReadyDialog(String path, String fileName) async {
    if (!mounted) return;
    final action = await showAppDialog<String>(
      context,
      title: _strings.reportReady,
      description: fileName,
      type: AppDialogType.success,
      actions: [
        AppDialogAction<String>(
          label: _strings.openExcelFile,
          result: 'open',
          isPrimary: true,
        ),
        AppDialogAction<String>(
          label: _strings.share,
          result: 'share',
        ),
        AppDialogAction<String>(
          label: _strings.save,
          result: 'save',
        ),
      ],
    );
    if (!mounted || action == null) return;
    await _handleReportAction(action, path, fileName);
  }

  Future<void> _handleReportAction(
    String action,
    String path,
    String fileName,
  ) async {
    const fileActions = ReportFileActionService();
    try {
      if (action == 'open') {
        await fileActions.openExcel(path);
      } else if (action == 'share') {
        await fileActions.shareExcel(path, fileName);
      } else if (action == 'save') {
        final saved = await fileActions.saveExcelAs(path, fileName);
        if (mounted && saved) {
          showTopToast(
            context,
            _strings.reportSavedSuccessfully,
            AppColors.success,
            icon: Icons.check_circle_outline_rounded,
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: _strings.reportActionFailed,
        description: '$error',
      );
    }
  }
}

class _ReportTypeSelector extends StatelessWidget {
  const _ReportTypeSelector({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = _ReportStrings(context);
    final options = [
      (label: s.all, value: null),
      (label: s.receiving, value: 'RECEIVING'),
      (label: s.dispatch, value: 'DISPATCH'),
      (label: s.adjustment, value: 'STOCK_ADJUSTMENT'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(s.reportType),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in options) ...[
                ChoiceChip(
                  label: Text(option.label),
                  selected: selected == option.value,
                  onSelected: (_) => onChanged(option.value),
                  selectedColor: AppColors.primary.withValues(alpha: 0.16),
                  labelStyle: TextStyle(
                    color: selected == option.value
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: selected == option.value
                        ? AppColors.primary
                        : AppColors.divider,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.warehouses,
    required this.selectedWarehouseId,
    required this.crops,
    required this.cropId,
    required this.period,
    required this.fromDate,
    required this.toDate,
    required this.displayDateFormat,
    required this.onWarehouseChanged,
    required this.onCropChanged,
    required this.onPeriodChanged,
    required this.onFromDate,
    required this.onToDate,
  });

  final List<Warehouse> warehouses;
  final String? selectedWarehouseId;
  final List<Crop> crops;
  final int? cropId;
  final String period;
  final DateTime fromDate;
  final DateTime toDate;
  final DateFormat displayDateFormat;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<int?> onCropChanged;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onFromDate;
  final VoidCallback onToDate;

  @override
  Widget build(BuildContext context) {
    final s = _ReportStrings(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(s.filters),
          const SizedBox(height: 12),
          _FilterLabel(s.warehouse),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: selectedWarehouseId,
            decoration: InputDecoration(
              labelText: s.selectWarehouse,
              prefixIcon: const Icon(Icons.warehouse_outlined),
            ),
            items: warehouses
                .map(
                  (warehouse) => DropdownMenuItem(
                    value: warehouse.id,
                    child: Text(warehouse.name),
                  ),
                )
                .toList(),
            onChanged: onWarehouseChanged,
          ),
          const SizedBox(height: 12),
          _FilterLabel(s.period),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: period,
            decoration: InputDecoration(
              labelText: s.selectPeriod,
              prefixIcon: const Icon(Icons.date_range_outlined),
            ),
            items: [
              DropdownMenuItem(value: 'today', child: Text(s.today)),
              DropdownMenuItem(value: '7', child: Text(s.sevenDays)),
              DropdownMenuItem(value: '30', child: Text(s.thirtyDays)),
              DropdownMenuItem(value: 'custom', child: Text(s.custom)),
            ],
            onChanged: (value) {
              if (value != null) onPeriodChanged(value);
            },
          ),
          if (period == 'custom') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: s.from,
                    value: displayDateFormat.format(fromDate),
                    onPressed: onFromDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateButton(
                    label: s.to,
                    value: displayDateFormat.format(toDate),
                    onPressed: onToDate,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _FilterLabel(s.crop),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: cropId ?? -1,
            decoration: InputDecoration(
              labelText: s.selectCrop,
              prefixIcon: const Icon(Icons.grass_outlined),
            ),
            items: [
              DropdownMenuItem(value: -1, child: Text(s.allCrops)),
              ...crops.map(
                (crop) => DropdownMenuItem(
                  value: crop.id,
                  child: Text(crop.name),
                ),
              ),
            ],
            onChanged: (value) {
              onCropChanged(value == null || value < 0 ? null : value);
            },
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedReportHeader extends StatelessWidget {
  const _GeneratedReportHeader({
    required this.reportTitle,
    required this.warehouseName,
    required this.cropName,
    required this.fromDate,
    required this.toDate,
    required this.displayDateFormat,
    required this.onChangeFilters,
    required this.onExport,
  });

  final String reportTitle;
  final String warehouseName;
  final String cropName;
  final DateTime fromDate;
  final DateTime toDate;
  final DateFormat displayDateFormat;
  final VoidCallback onChangeFilters;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final s = _ReportStrings(context);
    return AppCard(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reportTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$warehouseName - $cropName',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${displayDateFormat.format(fromDate)} - ${displayDateFormat.format(toDate)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChangeFilters,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(s.changeFilters),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.table_view_rounded),
                  label: Text(s.export),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.activities,
    required this.activityType,
  });

  final List<WarehouseActivityReportRecord> activities;
  final String? activityType;

  @override
  Widget build(BuildContext context) {
    final s = _ReportStrings(context);
    final bags = activities.fold<int>(0, (sum, item) => sum + item.totalBags);
    final net = activities.fold<double>(
      0,
      (sum, item) => sum + (item.totalNetWeight ?? item.netWeightChange ?? 0),
    );
    final isAdjustment = activityType == 'STOCK_ADJUSTMENT';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(s.reportSummary),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: _summaryCountLabel(activityType, s),
                value: '${activities.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(label: s.bags, value: '$bags')),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: isAdjustment
                    ? _adjustmentSummaryLabel(net, s)
                    : s.netWeight,
                value: isAdjustment
                    ? _weightAmount(net)
                    : '${net.toStringAsFixed(2)} kg',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _summaryCountLabel(String? type, _ReportStrings s) {
    return switch (type) {
      'RECEIVING' => s.receiving,
      'DISPATCH' => s.dispatch,
      'STOCK_ADJUSTMENT' => s.adjustment,
      _ => s.activity,
    };
  }

  String _adjustmentSummaryLabel(double value, _ReportStrings s) {
    if (value < 0) return s.weightReduced;
    if (value > 0) return s.weightIncreased;
    return s.netWeightChange;
  }

  String _weightAmount(double value) {
    if (value == 0) return '0.00 kg';
    return '${value.abs().toStringAsFixed(2)} kg';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w900,
        fontSize: 15,
      ),
    );
  }
}

class _UserReportCard extends StatelessWidget {
  const _UserReportCard(this.user);

  final WarehouseWorkerReportRecord user;

  @override
  Widget build(BuildContext context) {
    final s = _ReportStrings(context);
    final role = user.assigned ? s.worker : s.owner;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.workerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _Pill(
                  label: role,
                  color: user.assigned ? AppColors.info : AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    value: '${user.totalActivities}',
                    label: s.records,
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    value: '${user.receivedBags}',
                    label: s.received,
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    value: '${user.dispatchedBags}',
                    label: s.dispatch,
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    value: '${user.adjustedBags}',
                    label: s.adjust,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ActivityReportCard extends StatelessWidget {
  const _ActivityReportCard(this.record);

  final WarehouseActivityReportRecord record;

  @override
  Widget build(BuildContext context) {
    final s = _ReportStrings(context);
    final time = DateFormat('HH:mm').format(record.activityAt);
    final date = DateFormat('d MMM yyyy').format(record.activityAt);
    final actor = record.workerName.isEmpty ? '-' : record.workerName;
    final secondaryLabel = switch (record.activityType) {
      'RECEIVING' => s.farmer,
      'DISPATCH' => s.recipient,
      'STOCK_ADJUSTMENT' => s.adjustmentType,
      _ => s.details,
    };
    final secondaryValue = _secondaryDetailValue(record);
    final bagLabel = record.totalBags == 1 ? 'bag' : 'bags';
    final totalText = record.activityType == 'STOCK_ADJUSTMENT'
        ? '${record.totalBags} $bagLabel - '
            '${_adjustmentSentence(record.netWeightChange ?? 0)}'
        : '${record.totalBags} $bagLabel - ${_displayWeight(record)} kg';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ActivityIcon(record.activityType),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _activityLabel(record.activityType),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              record.cropName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              totalText,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const Divider(height: 18),
            _DetailLine(label: s.performedBy, value: actor),
            if (secondaryValue != '-')
              _DetailLine(label: secondaryLabel, value: secondaryValue),
            if (record.bags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.bags.take(3).map(_bagLine).join('\n'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (record.bags.length > 3)
                Text(
                  '+${record.bags.length - 3} more bags',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayWeight(WarehouseActivityReportRecord record) {
    final value = record.totalNetWeight ?? record.netWeightChange ?? 0;
    return value.toStringAsFixed(2);
  }

  String _bagLine(WarehouseReportBag bag) {
    return '${bag.tagNumber} - ${bag.netWeight.toStringAsFixed(2)} kg';
  }

  String _adjustmentSentence(double value) {
    if (value < 0) {
      return 'weight reduced by ${value.abs().toStringAsFixed(2)} kg';
    }
    if (value > 0) return 'weight increased by ${value.toStringAsFixed(2)} kg';
    return 'no weight difference';
  }

  String _secondaryDetailValue(WarehouseActivityReportRecord record) {
    final value = switch (record.activityType) {
      'RECEIVING' => record.farmerName,
      'DISPATCH' => record.recipientName,
      'STOCK_ADJUSTMENT' => record.adjustmentType,
      _ => null,
    }
        ?.trim();
    return value == null || value.isEmpty ? '-' : value;
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStrings {
  _ReportStrings(BuildContext context)
      : isSw = Localizations.localeOf(context).languageCode == 'sw';

  final bool isSw;

  String pick(String en, String sw) => isSw ? sw : en;

  String get warehouseReports => pick('Warehouse Reports', 'Ripoti za Ghala');
  String get reportSubtitle => pick(
        'View warehouse activities, stock movements and user performance.',
        'Tazama shughuli za ghala, mabadiliko ya stoo na utendaji wa watumiaji.',
      );
  String get generateReport => pick('Generate Report', 'Tengeneza Ripoti');
  String get generating => pick('Generating...', 'Inatengeneza...');
  String get userActivity => pick('User Activity', 'Shughuli za Watumiaji');
  String get activity => pick('Activity', 'Shughuli');
  String get noReportRecords =>
      pick('No report records', 'Hakuna taarifa za ripoti');
  String get tryDifferentFilters => pick(
        'Try a different period, crop, or report type.',
        'Jaribu kipindi, zao, au aina nyingine ya ripoti.',
      );
  String get receivingReport => pick('Receiving Report', 'Ripoti ya Kupokea');
  String get dispatchReport => pick('Dispatch Report', 'Ripoti ya Kutuma');
  String get adjustmentReport =>
      pick('Adjustment Report', 'Ripoti ya Marekebisho');
  String get activityReport => pick('Activity Report', 'Ripoti ya Shughuli');
  String get exportReportQuestion => pick('Export report?', 'Hamisha ripoti?');
  String get createExcelForFilters => pick(
        'Create an Excel report for the selected filters.',
        'Tengeneza ripoti ya Excel kwa vichujio vilivyochaguliwa.',
      );
  String get createReport => pick('Create report', 'Tengeneza ripoti');
  String get creatingExcelReport =>
      pick('Creating Excel report...', 'Inatengeneza ripoti ya Excel...');
  String get pleaseWait => pick('Please wait.', 'Tafadhali subiri.');
  String get reportExportFailed =>
      pick('Report export failed', 'Imeshindwa kuhamisha ripoti');
  String get reportReady => pick('Report ready', 'Ripoti iko tayari');
  String get openExcelFile => pick('Open Excel File', 'Fungua faili ya Excel');
  String get share => pick('Share', 'Shiriki');
  String get save => pick('Save', 'Hifadhi');
  String get reportSavedSuccessfully => pick(
        'Report saved successfully.',
        'Ripoti imehifadhiwa kikamilifu.',
      );
  String get reportActionFailed =>
      pick('Report action failed', 'Kitendo cha ripoti kimeshindwa');
  String get all => pick('All', 'Zote');
  String get receiving => pick('Receiving', 'Kupokea');
  String get dispatch => pick('Dispatch', 'Kutuma');
  String get adjustment => pick('Adjustment', 'Marekebisho');
  String get reportType => pick('Report Type', 'Aina ya Ripoti');
  String get filters => pick('Filters', 'Vichujio');
  String get warehouse => pick('Warehouse', 'Ghala');
  String get selectWarehouse => pick('Select warehouse', 'Chagua ghala');
  String get period => pick('Period', 'Kipindi');
  String get selectPeriod => pick('Select period', 'Chagua kipindi');
  String get today => pick('Today', 'Leo');
  String get sevenDays => pick('7 days', 'Siku 7');
  String get thirtyDays => pick('30 days', 'Siku 30');
  String get custom => pick('Custom', 'Chagua tarehe');
  String get from => pick('From', 'Kuanzia');
  String get to => pick('To', 'Mpaka');
  String get crop => pick('Crop', 'Zao');
  String get selectCrop => pick('Select crop', 'Chagua zao');
  String get allCrops => pick('All crops', 'Mazao yote');
  String get changeFilters => pick('Change filters', 'Badili vichujio');
  String get export => pick('Export', 'Hamisha');
  String get reportSummary => pick('Report Summary', 'Muhtasari wa Ripoti');
  String get bags => pick('Bags', 'Magunia');
  String get netWeight => pick('Net Weight', 'Uzito Halisi');
  String get weightReduced => pick('Weight Reduced', 'Uzito Umepungua');
  String get weightIncreased => pick('Weight Increased', 'Uzito Umeongezeka');
  String get netWeightChange =>
      pick('Net Weight Change', 'Mabadiliko ya Uzito');
  String get records => pick('Records', 'Rekodi');
  String get received => pick('Received', 'Yaliyopokelewa');
  String get adjust => pick('Adjust', 'Rekebisha');
  String get owner => pick('Owner', 'Mmiliki');
  String get worker => pick('Worker', 'Mfanyakazi');
  String get farmer => pick('Farmer', 'Mkulima');
  String get recipient => pick('Recipient', 'Mpokeaji');
  String get adjustmentType => pick('Adjustment Type', 'Aina ya Marekebisho');
  String get farmerName => pick('Farmer Name', 'Jina la Mkulima');
  String get phone => pick('Phone', 'Simu');
  String get farmerPhone => pick('Farmer Phone', 'Simu ya Mkulima');
  String get receiptNumber => pick('Receipt Number', 'Namba ya Risiti');
  String get recipientName => pick('Recipient Name', 'Jina la Mpokeaji');
  String get recipientType => pick('Recipient Type', 'Aina ya Mpokeaji');
  String get recipientPhone => pick('Recipient Phone', 'Simu ya Mpokeaji');
  String get reason => pick('Reason', 'Sababu');
  String get receivingDetails =>
      pick('Receiving details', 'Maelezo ya kupokea');
  String get dispatchDetails => pick('Dispatch details', 'Maelezo ya kutuma');
  String get adjustmentDetails =>
      pick('Adjustment details', 'Maelezo ya marekebisho');
  String get details => pick('Details', 'Maelezo');
  String get stockAdjustment => pick('Stock adjustment', 'Marekebisho ya stoo');
  String get summarySheet => pick('Summary', 'Muhtasari');
  String get activityDetailsSheet =>
      pick('Activity Details', 'Maelezo ya Shughuli');
  String get workbookTitle =>
      pick('WAREHOUSE ACTIVITY REPORT', 'RIPOTI YA SHUGHULI ZA GHALA');
  String get totalBags => pick('Total Bags', 'Jumla ya Magunia');
  String get totalNetWeight =>
      pick('Total Net Weight', 'Jumla ya Uzito Halisi');
  String get totalWeightChange =>
      pick('Total Weight Change', 'Jumla ya Mabadiliko ya Uzito');
  String get roleStatus => pick('Role/Status', 'Wadhifa/Hali');
  String get recordsDone => pick('Records Done', 'Rekodi Zilizofanyika');
  String get receivedBags => pick('Received Bags', 'Magunia Yaliyopokelewa');
  String get dispatchedBags => pick('Dispatched Bags', 'Magunia Yaliyotumwa');
  String get adjustedBags => pick('Adjusted Bags', 'Magunia Yaliyorekebishwa');
  String get date => pick('Date', 'Tarehe');
  String get bagTag => pick('Bag Tag', 'Tagi ya Gunia');
  String get performedBy => pick('Performed By', 'Imefanywa Na');
  String get previousWeight => pick('Previous Weight', 'Uzito wa Awali');
  String get currentWeight => pick('Current Weight', 'Uzito wa Sasa');

  WarehouseReportLabels get excelLabels => WarehouseReportLabels(
        workbookTitle: workbookTitle,
        summarySheet: summarySheet,
        userActivitySheet: userActivity,
        activityDetailsSheet: activityDetailsSheet,
        warehouse: warehouse,
        reportType: reportType,
        crop: crop,
        period: period,
        summary: reportSummary,
        totalBags: totalBags,
        totalNetWeight: totalNetWeight,
        totalWeightChange: totalWeightChange,
        worker: worker,
        roleStatus: roleStatus,
        recordsDone: recordsDone,
        receivedBags: receivedBags,
        dispatchedBags: dispatchedBags,
        adjustedBags: adjustedBags,
        date: date,
        activity: activity,
        bagTag: bagTag,
        netWeight: netWeight,
        performedBy: performedBy,
        farmerName: farmerName,
        farmerPhone: farmerPhone,
        recipientName: recipientName,
        recipientType: recipientType,
        recipientPhone: recipientPhone,
        receiptNumber: receiptNumber,
        reason: reason,
        previousWeight: previousWeight,
        currentWeight: currentWeight,
        netWeightChange: netWeightChange,
        owner: owner,
        receiving: receiving,
        dispatch: dispatch,
        stockAdjustment: stockAdjustment,
        activityFallback: activity,
      );
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon(this.activityType);

  final String activityType;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (activityType) {
      'RECEIVING' => (Icons.call_received_rounded, AppColors.success),
      'DISPATCH' => (Icons.local_shipping_outlined, AppColors.warning),
      'STOCK_ADJUSTMENT' => (Icons.tune_rounded, AppColors.info),
      _ => (Icons.summarize_outlined, AppColors.textSecondary),
    };
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _activityLabel(String activityType) {
  return switch (activityType) {
    'RECEIVING' => 'Receiving',
    'DISPATCH' => 'Dispatch',
    'STOCK_ADJUSTMENT' => 'Stock adjustment',
    _ => activityType,
  };
}
