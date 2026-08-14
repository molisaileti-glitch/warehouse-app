import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/domain/models/harvest_model.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_receiving_controller.dart';
import 'package:warehouse_app/features/scale/presentation/providers/weight_scale_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

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
  final _packagingCtrl = TextEditingController(text: '1');
  bool _submitting = false;

  static const _moisturePercent = 1.0;

  @override
  void dispose() {
    _tagCtrl.dispose();
    _packagingCtrl.dispose();
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
          _scaleCard(scaleState),
          const SizedBox(height: 18),
          _sectionTitle(l10n.bag),
          Form(
            key: _bagFormKey,
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.bagTag,
                          prefixIcon: Icon(Icons.qr_code_2_outlined),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9-]'),
                          ),
                        ],
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: l10n.generateBagTag,
                      onPressed: _generateBagTag,
                      icon: const Icon(Icons.casino_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _packagingCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.packagingWeightKg,
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: _packagingValidator,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _canAddBag(scaleState) ? () => _addBag(scaleState) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.workerColor,
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(l10n.addBag),
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
            l10n.moistureReceiptMessage(_formatWeight(_moisturePercent)),
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

  void _generateBagTag() {
    final now = DateTime.now();
    final random = Random().nextInt(9000) + 1000;
    _tagCtrl.text =
        'BAG-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  void _addBag(WeightScaleState scaleState) {
    if (!(_bagFormKey.currentState?.validate() ?? false)) return;
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

    final packagingWeight = _packagingWeightValue();
    if (packagingWeight >= scaleState.weight) {
      _showError(AppLocalizations.of(context)!.packagingLessThanGross);
      return;
    }

    ref
        .read(harvestReceivingControllerProvider(widget.warehouseId).notifier)
        .addBag(
          HarvestBagInput(
            tag: _tagCtrl.text.trim(),
            grossWeight: scaleState.weight,
            packagingWeight: packagingWeight,
            moistureContent: _moisturePercent,
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

    ref
        .read(harvestReceivingControllerProvider(widget.warehouseId).notifier)
        .markSaved(result.harvest!);

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

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? AppLocalizations.of(context)!.requiredField
        : null;
  }

  String? _packagingValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) return l10n.requiredField;
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return l10n.enterValidWeight;
    if (parsed < 0) return l10n.cannotBeNegative;
    return null;
  }

  double _packagingWeightValue() {
    return double.tryParse(_packagingCtrl.text.trim()) ?? 1;
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
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
