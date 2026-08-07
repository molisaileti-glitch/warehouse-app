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
      appBar: AppBar(title: const Text('Scale')),
      body: warehouseAsync.when(
        loading: () => const LoadingView(message: 'Loading scale...'),
        error: (e, _) => ErrorView(message: '$e'),
        data: (warehouse) {
          if (warehouse == null) {
            return const EmptyState(
              icon: Icons.warehouse_outlined,
              title: 'Warehouse not found',
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
          _sectionTitle('Bag'),
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
                        decoration: const InputDecoration(
                          labelText: 'Bag tag',
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
                      tooltip: 'Generate bag tag',
                      onPressed: _generateBagTag,
                      icon: const Icon(Icons.casino_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _packagingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Packaging weight (kg)',
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
                  label: const Text('Add Bag'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                width: 58,
                child: IconButton.filledTonal(
                  tooltip: 'View bags',
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
            'Moisture is set to ${_formatWeight(_moisturePercent)}%. Net weight will appear on the receipt.',
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Farmer details needed',
        subtitle: 'Select farmer and crop details before weighing bags.',
        actionLabel: 'Go to Details',
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
                  farmer == null ? 'Selected farmer' : _farmerName(farmer),
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
            tooltip: 'Edit details',
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
              label: const Text('Connect Scale'),
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

    final packagingWeight = _packagingWeightValue();
    if (packagingWeight >= scaleState.weight) {
      _showError('Packaging weight must be less than gross weight.');
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
                        const Expanded(
                          child: Text(
                            'Bags',
                            style: TextStyle(
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No bags added yet',
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
                              label: const Text('Complete Harvest'),
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
    if (session.bags.isEmpty) {
      _showError('Add at least one bag before completing harvest.');
      return;
    }

    final confirmed = await showCreationConfirmDialog(
      context,
      title: 'Complete Harvest',
      description:
          'Save ${session.bags.length} bag(s) and generate one receipt?',
      confirmLabel: 'Save',
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _submitting = true);
    showCenteredLoadingDialog(
      context,
      title: 'Saving Harvest',
      description: 'Saving this harvest locally.',
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
      _showError(result.error ?? 'Failed to save harvest.');
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
      title: 'Harvest Saved',
      description: 'Harvest successfully saved. Receipt is ready.',
    );
    if (!mounted) return;

    context.go(
      widget.ownerFlow
          ? AppRoutes.ownerReceiptFor(widget.warehouseId)
          : AppRoutes.workerReceiptFor(widget.warehouseId),
    );
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
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _packagingValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid weight';
    if (parsed < 0) return 'Cannot be negative';
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
    return name.isEmpty ? 'Farmer ${farmer.id}' : name;
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
                  'Gross ${_formatWeight(bag.grossWeight)} kg - Packaging ${_formatWeight(bag.packagingWeight)} kg',
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
