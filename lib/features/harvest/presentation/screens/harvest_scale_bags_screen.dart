import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/components/input_field.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/domain/models/harvest_model.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_receiving_controller.dart';
import 'package:warehouse_app/features/moisture/presentation/screens/moisture_reading_screen.dart';
import 'package:warehouse_app/features/scale/presentation/providers/weight_scale_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

enum _HarvestWeighingMode { single, bulk }

class HarvestScaleBagsScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  final bool ownerFlow;

  const HarvestScaleBagsScreen({
    super.key,
    required this.warehouseId,
    required this.ownerFlow,
  });

  @override
  ConsumerState<HarvestScaleBagsScreen> createState() =>
      _HarvestScaleBagsScreenState();
}

class _HarvestScaleBagsScreenState
    extends ConsumerState<HarvestScaleBagsScreen> {
  final _bagFormKey = GlobalKey<FormState>();
  final _tagCtrl = TextEditingController();
  _HarvestWeighingMode _weighingMode = _HarvestWeighingMode.single;
  String _bulkBatchRef = '';
  bool _submitting = false;

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(
      harvestReceivingControllerProvider(widget.warehouseId),
    );
    final scaleState = ref.watch(weightScaleControllerProvider);
    final warehouseAsync = ref.watch(warehouseByIdProvider(widget.warehouseId));
    final farmersAsync = ref.watch(allFarmersProvider);
    final cropsAsync = ref.watch(allCropsProvider);
    final unitsAsync = ref.watch(measurementUnitsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.scale)),
      body: warehouseAsync.when(
        loading: () => LoadingView(message: l10n.loadingScale),
        error: (e, _) => ErrorView(message: '$e'),
        data: (warehouse) {
          if (warehouse == null) {
            return EmptyState(
              icon: Icons.warehouse_outlined,
              title: l10n.warehouseNotFound,
            );
          }

          return _buildContent(
            session: session,
            scaleState: scaleState,
            warehouse: warehouse,
            farmersAsync: farmersAsync,
            cropsAsync: cropsAsync,
            unitsAsync: unitsAsync,
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required HarvestReceivingState session,
    required WeightScaleState scaleState,
    required Warehouse warehouse,
    required AsyncValue<List<Farmer>> farmersAsync,
    required AsyncValue<List<Crop>> cropsAsync,
    required AsyncValue<List<MeasurementUnit>> unitsAsync,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (!session.hasDetails) {
      return _missingDetails();
    }

    final farmer = (farmersAsync.valueOrNull ?? const <Farmer>[])
        .where((item) => item.id == session.farmerId)
        .firstOrNull;
    final crop = (cropsAsync.valueOrNull ?? const <Crop>[])
        .where((item) => item.id == session.cropId)
        .firstOrNull;
    final unit =
        _selectedUnit(unitsAsync.valueOrNull ?? const [], session.uomId);
    final packagingWeight = _cropPackagingWeight(crop);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailsSummary(
            farmer: farmer,
            crop: crop,
            warehouse: warehouse,
          ),
          const SizedBox(height: 16),
          _weighingModeSelector(session),
          const SizedBox(height: 16),
          _scaleCard(scaleState),
          const SizedBox(height: 18),
          _bagEntrySection(
            session: session,
            scaleState: scaleState,
            packagingWeight: packagingWeight,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _canAddBag(scaleState)
                          ? () => _addBag(scaleState, crop)
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.workerColor,
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(
                    _weighingMode == _HarvestWeighingMode.bulk
                        ? l10n.addBulkBag
                        : l10n.addBag,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                width: 58,
                child: IconButton.filledTonal(
                  tooltip: l10n.viewBags,
                  onPressed: () => _showBagsSheet(
                    session: session,
                    warehouse: warehouse,
                    farmer: farmer,
                    crop: crop,
                    unit: unit,
                  ),
                  icon: Badge(
                    label: Text('${session.bags.length}'),
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _weighingMode == _HarvestWeighingMode.bulk
                ? l10n.bulkMoistureReadingRequestedOnAddBag
                : l10n.moistureReadingRequestedOnAddBag,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingDetails() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: EmptyState(
        icon: Icons.assignment_outlined,
        title: l10n.farmerDetailsNeeded,
        subtitle: l10n.farmerDetailsNeededMessage,
        actionLabel: l10n.goToDetails,
        onAction: () => context.go(
          widget.ownerFlow
              ? AppRoutes.ownerFarmerDetailsFor(widget.warehouseId)
              : AppRoutes.workerFarmerDetailsFor(widget.warehouseId),
        ),
      ),
    );
  }

  Widget _detailsSummary({
    required Farmer? farmer,
    required Crop? crop,
    required Warehouse warehouse,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.assignment_turned_in_outlined,
            color: AppColors.ownerColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmer == null ? l10n.selectedFarmer : _farmerName(farmer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  [crop?.name, warehouse.name].whereType<String>().join(' - '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.editDetails,
            onPressed: () => context.push(
              widget.ownerFlow
                  ? AppRoutes.ownerFarmerDetailsFor(widget.warehouseId)
                  : AppRoutes.workerFarmerDetailsFor(widget.warehouseId),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  Widget _scaleCard(WeightScaleState scaleState) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = scaleState.isConnected && scaleState.isStable
        ? AppColors.success
        : scaleState.isConnected
            ? AppColors.warning
            : AppColors.textMuted;
    final statusText = scaleState.isConnected
        ? scaleState.isStable
            ? l10n.stable
            : l10n.unstable
        : l10n.notConnected;

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
                    Text(
                      l10n.scaleReading,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      scaleState.isConnected
                          ? scaleState.deviceName
                          : l10n.connectScaleBeforeWeighing,
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
                  fontSize: 48,
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
          if (!scaleState.isConnected) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => context.push(
                widget.ownerFlow
                    ? AppRoutes.ownerConnectScaleFor(widget.warehouseId)
                    : AppRoutes.workerConnectScaleFor(widget.warehouseId),
              ),
              icon: const Icon(Icons.bluetooth_searching_rounded),
              label: Text(l10n.connectScale),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weighingModeSelector(HarvestReceivingState session) {
    final l10n = AppLocalizations.of(context)!;
    final locked = session.bags.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _modeButton(
                  label: l10n.singleBag,
                  icon: Icons.inventory_2_outlined,
                  selected: _weighingMode == _HarvestWeighingMode.single,
                  enabled: !locked,
                  onTap: () => _setWeighingMode(_HarvestWeighingMode.single),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeButton(
                  label: l10n.bulkHarvest,
                  icon: Icons.inventory_outlined,
                  selected: _weighingMode == _HarvestWeighingMode.bulk,
                  enabled: !locked,
                  onTap: () => _setWeighingMode(_HarvestWeighingMode.bulk),
                ),
              ),
            ],
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Text(
              l10n.weighingModeLockedUntilBagsCleared,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.ownerColor.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.ownerColor
                : AppColors.divider.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.ownerColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      selected ? AppColors.ownerColor : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bagEntrySection({
    required HarvestReceivingState session,
    required WeightScaleState scaleState,
    required double packagingWeight,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (_weighingMode == _HarvestWeighingMode.bulk) {
      final previousTotal = _previousCumulativeGross(session);
      final nextGross = scaleState.weight - previousTotal;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l10n.bulkHarvest),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.bulkHarvestStackingInstruction,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _summaryRow(l10n.batchReference, _bulkBatchRef),
                const SizedBox(height: 8),
                _summaryRow(
                  l10n.nextBagTag,
                  _bulkBagTag(session.bags.length + 1),
                ),
                const Divider(height: 22),
                _summaryRow(
                  l10n.previousCumulativeGross,
                  '${_formatWeight(previousTotal)} ${scaleState.uom}',
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  l10n.nextBagGross,
                  '${_formatWeight(nextGross > 0 ? nextGross : 0)} ${scaleState.uom}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _packagingWeightSummary(
            label: l10n.packagingWeightKg,
            value: packagingWeight,
            unit: scaleState.uom,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.bag),
        Form(
          key: _bagFormKey,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppLabeledField(
                      labelText: l10n.bagTag,
                      child: TextFormField(
                        controller: _tagCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.qr_code_2_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          const _BagTagInputFormatter(),
                        ],
                        validator: _bagTagValidator,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 23),
                    child: IconButton.filledTonal(
                      tooltip: l10n.generateBagTag,
                      onPressed: _generateBagTag,
                      icon: const Icon(Icons.casino_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _packagingWeightSummary(
                label: l10n.packagingWeightKg,
                value: packagingWeight,
                unit: scaleState.uom,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  void _generateBagTag() {
    final now = DateTime.now();
    final random = Random().nextInt(9000) + 1000;
    _tagCtrl.text =
        'BAG-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
    _tagCtrl.selection = TextSelection.collapsed(offset: _tagCtrl.text.length);
  }

  Future<void> _addBag(WeightScaleState scaleState, Crop? crop) async {
    final isBulk = _weighingMode == _HarvestWeighingMode.bulk;
    final session = ref.read(
      harvestReceivingControllerProvider(widget.warehouseId),
    );
    if (!isBulk && !(_bagFormKey.currentState?.validate() ?? false)) return;
    if (!scaleState.isConnected || !scaleState.isStreaming) {
      _showError(AppLocalizations.of(context)!.connectScaleBeforeBag);
      return;
    }
    if (!scaleState.isStable) {
      _showError(AppLocalizations.of(context)!.waitForStableScale);
      return;
    }
    if (scaleState.weight <= 0) {
      _showError(AppLocalizations.of(context)!.weightGreaterThanZero);
      return;
    }

    final grossWeight = isBulk
        ? scaleState.weight - _previousCumulativeGross(session)
        : scaleState.weight;
    if (isBulk && grossWeight <= 0) {
      _showError(
        AppLocalizations.of(context)!.bulkScaleMustIncrease(
          _formatWeight(scaleState.weight),
          _formatWeight(_previousCumulativeGross(session)),
        ),
      );
      return;
    }

    final packagingWeight = _cropPackagingWeight(crop);
    if (packagingWeight >= grossWeight) {
      _showError(AppLocalizations.of(context)!.packagingLessThanGross);
      return;
    }
    final moistureContent = isBulk
        ? 0.0
        : await askAndMeasureMoisture(
            context: context,
            cropName: crop?.name ?? AppLocalizations.of(context)!.crop,
            maxMoistureContent: crop?.maxMoisureContent,
          );
    if (!mounted || moistureContent == null) return;

    ref
        .read(harvestReceivingControllerProvider(widget.warehouseId).notifier)
        .addBag(
          HarvestBagInput(
            tag: isBulk
                ? _bulkBagTag(session.bags.length + 1)
                : _tagCtrl.text.trim(),
            tagType: isBulk ? 'BATCH_GENERATED' : 'GENERATED',
            grossWeight: grossWeight,
            packagingWeight: packagingWeight,
            moistureContent: moistureContent,
          ),
        );

    _tagCtrl.clear();
    ref.read(weightScaleControllerProvider.notifier).requestCurrentWeight();
  }

  Future<void> _showBagsSheet({
    required HarvestReceivingState session,
    required Warehouse warehouse,
    required Farmer? farmer,
    required Crop? crop,
    required MeasurementUnit? unit,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final currentSession = ref.watch(
              harvestReceivingControllerProvider(widget.warehouseId),
            );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.receiptBags,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _statusPill(
                          '${currentSession.bags.length}',
                          AppColors.ownerColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (currentSession.bags.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: l10n.noBagsAdded,
                        ),
                      )
                    else ...[
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: currentSession.bags.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final bag = currentSession.bags[index];
                            return _BagTile(
                              index: index,
                              bag: bag,
                              onRemove: () => ref
                                  .read(
                                    harvestReceivingControllerProvider(
                                      widget.warehouseId,
                                    ).notifier,
                                  )
                                  .removeBag(index),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _submitting
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: farmer == null || crop == null
                                  ? null
                                  : () => _submit(
                                        sheetContext: sheetContext,
                                        session: currentSession,
                                        warehouse: warehouse,
                                        farmer: farmer,
                                        crop: crop,
                                        unit: unit,
                                      ),
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: Text(l10n.completeHarvest),
                            ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit({
    required BuildContext sheetContext,
    required HarvestReceivingState session,
    required Warehouse warehouse,
    required Farmer farmer,
    required Crop crop,
    required MeasurementUnit? unit,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (session.bags.isEmpty) {
      _showError(l10n.addBagBeforeComplete);
      return;
    }

    final confirmed = await showCreationConfirmDialog(
      context,
      title: l10n.completeHarvest,
      description: l10n.completeHarvestConfirm(session.bags.length),
      confirmLabel: l10n.saveButton,
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _submitting = true);
    showCenteredLoadingDialog(
      context,
      title: l10n.savingHarvest,
      description: l10n.savingHarvestLocally,
    );
    final result = await ref.read(harvestRepositoryProvider).recordHarvest(
          HarvestCreateInput(
            farmer: farmer,
            warehouse: warehouse,
            crop: crop,
            cropGrade: null,
            uom: unit,
            packaging: session.packaging,
            batchRef:
                _weighingMode == _HarvestWeighingMode.bulk ? _bulkBatchRef : '',
            isBatchMode: _weighingMode == _HarvestWeighingMode.bulk,
            bags: List.unmodifiable(session.bags),
          ),
        );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _submitting = false);

    if (!result.success) {
      _showError(_localizedHarvestError(result.error, l10n));
      return;
    }

    ref.invalidate(harvestsByWarehouseProvider(widget.warehouseId));
    ref.invalidate(warehouseInventoryProvider(widget.warehouseId));

    ref
        .read(harvestReceivingControllerProvider(widget.warehouseId).notifier)
        .markSaved(result.harvest!);
    if (_weighingMode == _HarvestWeighingMode.bulk) {
      setState(() {
        _bulkBatchRef = _generateBatchRef();
      });
    }

    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }

    await showCreationSuccessDialog(
      context,
      title: l10n.harvestSaved,
      description: l10n.harvestSavedMessage,
    );
    if (!mounted) return;

    context.go(
      widget.ownerFlow
          ? AppRoutes.ownerReceiptFor(widget.warehouseId)
          : AppRoutes.workerReceiptFor(widget.warehouseId),
    );
  }

  String _localizedHarvestError(String? error, AppLocalizations l10n) {
    return switch (error) {
      'Harvest was not saved locally.' => l10n.saveHarvestFailed,
      'Add at least one bag.' => l10n.addBagBeforeComplete,
      'Gross weight must be greater than zero.' => l10n.weightGreaterThanZero,
      'Packaging weight cannot be negative.' => l10n.enterValidWeight,
      'Packaging weight cannot be greater than gross weight.' =>
        l10n.packagingLessThanGross,
      'Moisture content must be between 0 and 100.' => l10n.enterValidNumber,
      null => l10n.saveHarvestFailed,
      _ => l10n.errorWithDetails(error),
    };
  }

  bool _canAddBag(WeightScaleState scaleState) {
    return scaleState.isConnected &&
        scaleState.isStreaming &&
        scaleState.isStable &&
        scaleState.weight > 0;
  }

  MeasurementUnit? _selectedUnit(List<MeasurementUnit> units, int? unitId) {
    if (units.isEmpty) return null;
    if (unitId != null) {
      final selected = units.where((unit) => unit.id == unitId).firstOrNull;
      if (selected != null) return selected;
    }
    return units
            .where((unit) => unit.name.toUpperCase() == 'KILOGRAM')
            .firstOrNull ??
        units.first;
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }

  String? _bagTagValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) return l10n.requiredField;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 8 ? null : l10n.bagTagMustHaveEightDigits;
  }

  void _setWeighingMode(_HarvestWeighingMode mode) {
    setState(() {
      _weighingMode = mode;
      if (mode == _HarvestWeighingMode.bulk && _bulkBatchRef.isEmpty) {
        _bulkBatchRef = _generateBatchRef();
      }
    });
  }

  String _generateBatchRef() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random().nextInt(9000) + 1000;
    return 'BATCH-$date-$random';
  }

  String _bulkBagTag(int bagNumber) {
    final batchRef = _bulkBatchRef.isEmpty ? _generateBatchRef() : _bulkBatchRef;
    return '$batchRef-$bagNumber';
  }

  double _previousCumulativeGross(HarvestReceivingState session) {
    return session.bags.fold<double>(
      0,
      (sum, bag) => sum + bag.grossWeight,
    );
  }

  double _cropPackagingWeight(Crop? crop) {
    return crop?.packagingWeight ?? 0;
  }

  String _farmerName(Farmer farmer) {
    final name = [
      farmer.firstName,
      farmer.middleName,
      farmer.lastName,
    ]
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .join(' ');
    return name.isEmpty
        ? AppLocalizations.of(context)!.farmerNumber(farmer.id)
        : name;
  }

  String _formatWeight(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  Widget _packagingWeightSummary({
    required String label,
    required double value,
    required String unit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.ownerColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.ownerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.ownerColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${_formatWeight(value)} $unit',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}

class _BagTagInputFormatter extends TextInputFormatter {
  const _BagTagInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
    final text = clipped.length <= 4
        ? 'BAG-$clipped'
        : 'BAG-${clipped.substring(0, 4)}-${clipped.substring(4)}';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _BagTile extends StatelessWidget {
  final int index;
  final HarvestBagInput bag;
  final VoidCallback onRemove;

  const _BagTile({
    required this.index,
    required this.bag,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.workerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.workerColor,
                fontWeight: FontWeight.w900,
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.bagWeightSummary(
                    _formatWeight(bag.grossWeight),
                    _formatWeight(bag.packagingWeight),
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.removeBag,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  String _formatWeight(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }
}
