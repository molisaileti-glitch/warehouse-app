import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/domain/models/harvest_model.dart';
import 'package:warehouse_app/features/scale/presentation/providers/weight_scale_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

const _packagingOptions = ['BAGS'];

class HarvestRecordScreen extends ConsumerStatefulWidget {
  final String warehouseId;

  const HarvestRecordScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<HarvestRecordScreen> createState() =>
      _HarvestRecordScreenState();
}

class _HarvestRecordScreenState extends ConsumerState<HarvestRecordScreen> {
  final _detailsFormKey = GlobalKey<FormState>();
  final _bagFormKey = GlobalKey<FormState>();
  final _tagCtrl = TextEditingController();
  final _packagingCtrl = TextEditingController(text: '0');
  final _moistureCtrl = TextEditingController(text: '0');

  int? _farmerId;
  int? _cropId;
  int? _cropGradeId;
  int? _uomId;
  String _packaging = 'BAGS';
  bool _submitting = false;
  bool _scanning = false;
  final List<HarvestBagInput> _bags = [];

  @override
  void initState() {
    super.initState();
    _packagingCtrl.addListener(_recalculate);
    _moistureCtrl.addListener(_recalculate);
    Future.microtask(_pullReferenceData);
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    _packagingCtrl.dispose();
    _moistureCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    if (mounted) setState(() {});
  }

  Future<void> _pullReferenceData() async {
    await ref.read(harvestRepositoryProvider).pullReferenceData();
    if (!mounted) return;
    ref.invalidate(measurementUnitsProvider);
    if (_cropId != null) {
      ref.invalidate(cropGradesForCropProvider(_cropId!));
    }
  }

  Future<void> _submit({
    required Warehouse warehouse,
    required List<Farmer> farmers,
    required List<Crop> crops,
    required List<CropGrade> grades,
    required List<MeasurementUnit> units,
  }) async {
    if (!(_detailsFormKey.currentState?.validate() ?? false)) return;

    if (_bags.isEmpty) {
      _showError('Add at least one weighed bag before saving.');
      return;
    }

    final farmer = farmers.where((item) => item.id == _farmerId).firstOrNull;
    final crop = crops.where((item) => item.id == _cropId).firstOrNull;
    final grade = grades.where((item) => item.id == _cropGradeId).firstOrNull;
    final unit = units
        .where((item) => item.id == (_uomId ?? _preferredUnitId(units)))
        .firstOrNull;

    if (farmer == null || crop == null || unit == null) {
      _showError('Select farmer, crop, and measurement unit.');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Complete Receiving',
      message:
          'Save ${_bags.length} bag(s) for offline sync to farmer harvests?',
      confirmLabel: 'Save',
    );
    if (!confirmed) return;

    setState(() => _submitting = true);
    final result = await ref.read(harvestRepositoryProvider).recordHarvest(
          HarvestCreateInput(
            farmer: farmer,
            warehouse: warehouse,
            crop: crop,
            cropGrade: grade,
            uom: unit,
            packaging: _packaging,
            bags: List.unmodifiable(_bags),
          ),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.success) {
      _showError(result.error ?? 'Failed to save harvest.');
      return;
    }

    final savedHarvest = result.harvest!;
    final savedBagCount = _bags.length;

    setState(() {
      _bags.clear();
      _tagCtrl.clear();
      _packagingCtrl.text = crop.packagingWeight?.toString() ?? '0';
      _moistureCtrl.text = '0';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Harvest saved locally. Receipt ${savedHarvest.receiptNumber}',
        ),
        backgroundColor: AppColors.success,
      ),
    );

    await _showReceiptDialog(savedHarvest, savedBagCount);
  }

  @override
  Widget build(BuildContext context) {
    final warehouseAsync = ref.watch(warehouseByIdProvider(widget.warehouseId));
    final farmersAsync = ref.watch(allFarmersProvider);
    final cropsAsync = ref.watch(allCropsProvider);
    final unitsAsync = ref.watch(measurementUnitsProvider);
    final scaleState = ref.watch(weightScaleControllerProvider);
    final selectedCropId = _cropId;
    final gradesAsync = selectedCropId == null
        ? const AsyncValue.data(<CropGrade>[])
        : ref.watch(cropGradesForCropProvider(selectedCropId));
    final harvestsAsync =
        ref.watch(harvestsByWarehouseProvider(widget.warehouseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Receive Crop'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.workerDashboard);
            }
          },
        ),
      ),
      body: warehouseAsync.when(
        loading: () => const LoadingView(message: 'Loading warehouse...'),
        error: (e, _) => ErrorView(message: '$e'),
        data: (warehouse) {
          if (warehouse == null) {
            return const EmptyState(
              icon: Icons.warehouse_outlined,
              title: 'Warehouse not found',
            );
          }
          return _buildContent(
            warehouse: warehouse,
            farmersAsync: farmersAsync,
            cropsAsync: cropsAsync,
            unitsAsync: unitsAsync,
            gradesAsync: gradesAsync,
            harvestsAsync: harvestsAsync,
            scaleState: scaleState,
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required Warehouse warehouse,
    required AsyncValue<List<Farmer>> farmersAsync,
    required AsyncValue<List<Crop>> cropsAsync,
    required AsyncValue<List<MeasurementUnit>> unitsAsync,
    required AsyncValue<List<CropGrade>> gradesAsync,
    required AsyncValue<List<FarmerHarvest>> harvestsAsync,
    required WeightScaleState scaleState,
  }) {
    final farmers = farmersAsync.valueOrNull ?? const <Farmer>[];
    final crops = cropsAsync.valueOrNull ?? const <Crop>[];
    final units = unitsAsync.valueOrNull ?? const <MeasurementUnit>[];
    final grades = gradesAsync.valueOrNull ?? const <CropGrade>[];
    final selectedCrop = crops.where((crop) => crop.id == _cropId).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _scaleCard(scaleState),
          const SizedBox(height: 16),
          Form(
            key: _detailsFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warehouse.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Collection center',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Farmer'),
                _asyncGate(
                  async: farmersAsync,
                  emptyTitle: 'No farmers available',
                  emptySubtitle:
                      'Sync or register farmers before recording harvests.',
                  child: DropdownButtonFormField<int>(
                    initialValue: _farmerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Farmer',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: farmers.map((farmer) {
                      return DropdownMenuItem(
                        value: farmer.id,
                        child: Text(
                          '${_farmerName(farmer)} - ${farmer.phoneNumber}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _farmerId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle('Crop'),
                _asyncGate(
                  async: cropsAsync,
                  emptyTitle: 'No crops available',
                  emptySubtitle: 'Sync crop reference data first.',
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _cropId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Crop',
                          prefixIcon: Icon(Icons.grass_outlined),
                        ),
                        items: crops.map((crop) {
                          return DropdownMenuItem(
                            value: crop.id,
                            child: Text(
                              crop.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _cropId = value;
                            _cropGradeId = null;
                            final crop = crops
                                .where((item) => item.id == value)
                                .firstOrNull;
                            _packagingCtrl.text =
                                crop?.packagingWeight?.toString() ?? '0';
                          });
                        },
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _cropGradeDropdown(gradesAsync, grades),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: _uomId ?? _preferredUnitId(units),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Measurement unit',
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                        items: units.map((unit) {
                          return DropdownMenuItem(
                            value: unit.id,
                            child: Text(
                              unit.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: units.isEmpty
                            ? null
                            : (value) => setState(() => _uomId = value),
                        validator: (_) => units.isEmpty
                            ? 'Sync measurement units first'
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Bag Reading'),
          Form(
            key: _bagFormKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _packaging,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Packaging',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: _packagingOptions.map((packaging) {
                    return DropdownMenuItem(
                      value: packaging,
                      child: Text(packaging, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _packaging = value);
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _tagCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bag tag',
                    prefixIcon: Icon(Icons.qr_code_2_outlined),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: _required,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        controller: _packagingCtrl,
                        label: 'Packaging weight',
                        icon: Icons.inventory_2_outlined,
                        validator: _nonNegative,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: _moistureCtrl,
                        label: 'Moisture (%)',
                        icon: Icons.water_drop_outlined,
                        validator: _percentage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _calculationPreview(scaleState, selectedCrop),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _canAddBag(scaleState)
                ? () => _addBag(scaleState, selectedCrop)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.workerColor,
            ),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Add Bag'),
          ),
          const SizedBox(height: 20),
          _bagsCard(),
          const SizedBox(height: 24),
          _submitting
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.workerColor,
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _bags.isEmpty
                      ? null
                      : () => _submit(
                            warehouse: warehouse,
                            farmers: farmers,
                            crops: crops,
                            grades: grades,
                            units: units,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ownerColor,
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Complete Receiving'),
                ),
          const SizedBox(height: 28),
          _sectionTitle('Recent Harvests'),
          harvestsAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: '$e'),
            data: (harvests) {
              if (harvests.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No harvests yet',
                );
              }
              return Column(
                children: harvests.take(5).map(_harvestTile).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _scaleCard(WeightScaleState scaleState) {
    final statusColor = scaleState.isConnected && scaleState.isStable
        ? AppColors.success
        : scaleState.isConnected
            ? AppColors.warning
            : AppColors.textMuted;
    final statusText = scaleState.isConnected
        ? scaleState.isStable
            ? 'Stable'
            : 'Unstable'
        : 'Not connected';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.ownerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppColors.ownerColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scale Reading',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      scaleState.isConnected
                          ? scaleState.deviceName
                          : 'Connect scale before weighing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(statusText, statusColor),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                scaleState.weight.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  scaleState.uom,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (scaleState.lastError.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              scaleState.lastError,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanning || scaleState.isConnecting
                      ? null
                      : _scanAndConnectScale,
                  icon: _scanning || scaleState.isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          scaleState.isConnected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_searching_rounded,
                        ),
                  label: Text(
                    scaleState.isConnected ? 'Change Scale' : 'Connect Scale',
                  ),
                ),
              ),
              if (scaleState.isConnected) ...[
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Disconnect scale',
                  onPressed: () => ref
                      .read(weightScaleControllerProvider.notifier)
                      .disconnect(),
                  icon: const Icon(Icons.link_off_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _scanAndConnectScale() async {
    setState(() => _scanning = true);
    final controller = ref.read(weightScaleControllerProvider.notifier);
    final devices = await controller.scanForScales();
    if (!mounted) return;
    setState(() => _scanning = false);

    if (devices.isEmpty) {
      final error = ref.read(weightScaleControllerProvider).lastError;
      _showError(error.isEmpty ? 'No scales found nearby.' : error);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Scales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final result = devices[index];
                      final device = result.device;
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(
                            Icons.bluetooth_rounded,
                            color: AppColors.ownerColor,
                          ),
                          title: Text(
                            _deviceName(device),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${device.remoteId} - ${result.rssi} dBm',
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            controller.connectToDevice(device);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addBag(WeightScaleState scaleState, Crop? crop) {
    if (!(_detailsFormKey.currentState?.validate() ?? false)) return;
    if (!(_bagFormKey.currentState?.validate() ?? false)) return;

    if (!scaleState.isConnected || !scaleState.isStreaming) {
      _showError('Connect the scale before adding a bag.');
      return;
    }
    if (!scaleState.isStable) {
      _showError('Please wait until the scale reading is stable.');
      return;
    }
    if (scaleState.weight <= 0) {
      _showError('Weight must be greater than zero.');
      return;
    }

    final packagingWeight = _number(_packagingCtrl);
    final moistureContent = _number(_moistureCtrl);
    if (packagingWeight > scaleState.weight) {
      _showError('Packaging weight cannot be greater than gross weight.');
      return;
    }

    setState(() {
      _bags.add(
        HarvestBagInput(
          tag: _tagCtrl.text.trim(),
          grossWeight: scaleState.weight,
          packagingWeight: packagingWeight,
          moistureContent: moistureContent,
        ),
      );
      _tagCtrl.clear();
      _packagingCtrl.text = crop?.packagingWeight?.toString() ?? '0';
      _moistureCtrl.text = '0';
    });

    ref.read(weightScaleControllerProvider.notifier).requestCurrentWeight();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bag added to this receiving session.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  bool _canAddBag(WeightScaleState scaleState) {
    return scaleState.isConnected &&
        scaleState.isStreaming &&
        scaleState.isStable &&
        scaleState.weight > 0;
  }

  Widget _calculationPreview(WeightScaleState scaleState, Crop? crop) {
    final gross = scaleState.weight;
    final packaging = _number(_packagingCtrl);
    final moisture = _number(_moistureCtrl);
    final load = gross - packaging;
    final moistureWeight = load * moisture / 100;
    final net = load - moistureWeight;
    final invalid =
        gross > 0 && (packaging > gross || moisture < 0 || moisture > 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: invalid
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: invalid
              ? AppColors.error.withValues(alpha: 0.25)
              : AppColors.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net weight',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            invalid
                ? 'Check weights'
                : '${_formatWeight(net)} ${crop?.uom ?? scaleState.uom}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: invalid ? AppColors.error : AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gross ${_formatWeight(gross)} - tare ${_formatWeight(packaging)} - moisture ${_formatWeight(moistureWeight)}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _bagsCard() {
    final totalGross = _bags.fold<double>(
      0,
      (sum, bag) => sum + bag.grossWeight,
    );
    final totalPackaging = _bags.fold<double>(
      0,
      (sum, bag) => sum + bag.packagingWeight,
    );
    final totalNet = _bags.fold<double>(
      0,
      (sum, bag) => sum + bag.calculate().netWeight,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Added Bags',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              _statusPill('${_bags.length}', AppColors.ownerColor),
            ],
          ),
          const SizedBox(height: 12),
          if (_bags.isEmpty)
            const Text(
              'No bags added yet.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            for (var i = 0; i < _bags.length; i++) _bagRow(i, _bags[i]),
            const Divider(height: 24),
            _summaryRow('Total gross', totalGross),
            _summaryRow('Total tare', totalPackaging),
            _summaryRow('Total net', totalNet, bold: true),
          ],
        ],
      ),
    );
  }

  Future<void> _showReceiptDialog(FarmerHarvest harvest, int bagCount) {
    final date = DateFormat('MMM d, yyyy HH:mm').format(harvest.receivedAt);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Warehouse Receipt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _receiptRow('Receipt', harvest.receiptNumber),
              _receiptRow('Farmer', harvest.farmerName),
              _receiptRow('Crop', harvest.cropName),
              _receiptRow('Bags', '$bagCount'),
              _receiptRow(
                'Gross',
                '${_formatWeight(harvest.grossWeight)} ${harvest.uomName ?? 'kg'}',
              ),
              _receiptRow(
                'Net',
                '${_formatWeight(harvest.netWeight)} ${harvest.uomName ?? 'kg'}',
                bold: true,
              ),
              _receiptRow('Date', date),
              if (harvest.receivedByName != null)
                _receiptRow('Received by', harvest.receivedByName!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bagRow(int index, HarvestBagInput bag) {
    final weights = bag.calculate();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.ownerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.ownerColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bag.tag,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Gross ${_formatWeight(bag.grossWeight)} kg - Net ${_formatWeight(weights.netWeight)} kg',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove bag',
            onPressed: () => setState(() => _bags.removeAt(index)),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${_formatWeight(value)} kg',
            style: TextStyle(
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cropGradeDropdown(
    AsyncValue<List<CropGrade>> gradesAsync,
    List<CropGrade> grades,
  ) {
    return gradesAsync.when(
      loading: () => const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Crop grade',
          prefixIcon: Icon(Icons.workspace_premium_outlined),
          suffixIcon: Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Crop grade',
          hintText: '$e',
          prefixIcon: const Icon(Icons.workspace_premium_outlined),
        ),
      ),
      data: (_) {
        final hint = _cropId == null
            ? 'Select crop first'
            : grades.isEmpty
                ? 'No grades for selected crop'
                : 'Select grade';
        return DropdownButtonFormField<int>(
          key: ValueKey('grade-$_cropId-${grades.length}'),
          initialValue: _cropGradeId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Crop grade',
            hintText: hint,
            prefixIcon: const Icon(Icons.workspace_premium_outlined),
          ),
          items: grades.map((grade) {
            return DropdownMenuItem(
              value: grade.id,
              child: Text(grade.gradeName, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: grades.isEmpty
              ? null
              : (value) => setState(() => _cropGradeId = value),
        );
      },
    );
  }

  Widget _harvestTile(FarmerHarvest harvest) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.workerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  harvest.receiptNumber,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${harvest.farmerName} - ${_formatWeight(harvest.netWeight)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SyncStatusBadge(status: harvest.syncStatus),
        ],
      ),
    );
  }

  Widget _asyncGate<T>({
    required AsyncValue<List<T>> async,
    required Widget child,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (items) => items.isEmpty
          ? EmptyState(
              icon: Icons.sync_problem_outlined,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          : child,
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
      ],
      validator: validator,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _nonNegative(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return 'Enter a valid weight';
    final gross = ref.read(weightScaleControllerProvider).weight;
    if (gross > 0 && number > gross) return 'Too high';
    return null;
  }

  String? _percentage(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number < 0 || number > 100 ? 'Use 0 to 100' : null;
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  int? _preferredUnitId(List<MeasurementUnit> units) {
    if (units.isEmpty) return null;
    return units
            .where((unit) => unit.name.toUpperCase() == 'KILOGRAM')
            .firstOrNull
            ?.id ??
        units.first.id;
  }

  String _farmerName(Farmer farmer) {
    return [
      farmer.firstName,
      farmer.middleName,
      farmer.lastName,
    ]
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .join(' ');
  }

  String _deviceName(BluetoothDevice device) {
    final advertisedName = device.advName.trim();
    final platformName = device.platformName.trim();
    if (advertisedName.isNotEmpty) return advertisedName;
    if (platformName.isNotEmpty) return platformName;
    return 'Unknown Scale';
  }

  String _formatWeight(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}
