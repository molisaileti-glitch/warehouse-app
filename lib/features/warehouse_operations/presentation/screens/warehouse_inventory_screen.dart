import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/features/warehouse_operations/domain/models/warehouse_operation_models.dart';

enum _WarehouseAction { dispatch, count, adjustment }

class WarehouseInventoryScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  final bool ownerFlow;

  const WarehouseInventoryScreen({
    super.key,
    required this.warehouseId,
    this.ownerFlow = true,
  });

  @override
  ConsumerState<WarehouseInventoryScreen> createState() =>
      _WarehouseInventoryScreenState();
}

class _WarehouseInventoryScreenState
    extends ConsumerState<WarehouseInventoryScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warehouseAsync = ref.watch(warehouseByIdProvider(widget.warehouseId));
    final inventoryAsync =
        ref.watch(warehouseInventoryProvider(widget.warehouseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Stock'),
        actions: const [SyncIndicator()],
      ),
      body: warehouseAsync.when(
        data: (warehouse) {
          if (warehouse == null) {
            return const ErrorView(message: 'Warehouse not found');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warehouse.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose a crop to manage its stock.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Search crops',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: inventoryAsync.when(
                  data: (items) {
                    final filtered = _filterInventory(items, _query);
                    if (filtered.isEmpty) {
                      return const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No crop stock yet',
                        subtitle:
                            'Sync inventory or record an increase adjustment.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final item = filtered[index];
                        return _InventoryCard(
                          item: item,
                          onTap: () => context.push(
                            widget.ownerFlow
                                ? AppRoutes.ownerCropStockFor(
                                    widget.warehouseId,
                                    item.crop.toString(),
                                  )
                                : AppRoutes.workerCropStockFor(
                                    widget.warehouseId,
                                    item.crop.toString(),
                                  ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingView(),
                  error: (error, _) => ErrorView(message: '$error'),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: '$error'),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final WarehouseInventory item;
  final VoidCallback? onTap;

  const _InventoryCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.workerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.grass_outlined,
                    color: AppColors.workerColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.cropName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.totalBags} bags',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _Metric(label: 'Gross', value: item.totalGrossWeight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                    label: 'Packaging', value: item.totalPackagingWeight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(label: 'Net', value: item.totalNetWeight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentStockCard extends StatelessWidget {
  final WarehouseInventory item;

  const _CurrentStockCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Stock',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.totalBags} bags',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                child: _Metric(label: 'Gross', value: item.totalGrossWeight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Packaging',
                  value: item.totalPackagingWeight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(label: 'Net', value: item.totalNetWeight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OperationGrid extends StatelessWidget {
  final VoidCallback onDispatch;
  final VoidCallback onCount;
  final VoidCallback onAdjustment;

  const _OperationGrid({
    required this.onDispatch,
    required this.onCount,
    required this.onAdjustment,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _OperationButton(
              width: width,
              icon: Icons.local_shipping_outlined,
              label: 'Dispatch',
              onTap: onDispatch,
            ),
            _OperationButton(
              width: width,
              icon: Icons.fact_check_outlined,
              label: 'Stock Count',
              onTap: onCount,
            ),
            _OperationButton(
              width: width,
              icon: Icons.tune_rounded,
              label: 'Adjustment',
              onTap: onAdjustment,
            ),
          ],
        );
      },
    );
  }
}

class _OperationButton extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OperationButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.workerColor,
          side: BorderSide(
            color: AppColors.workerColor.withValues(alpha: 0.45),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _OperationContextCard extends StatelessWidget {
  final Warehouse warehouse;
  final WarehouseInventory inventory;

  const _OperationContextCard({
    required this.warehouse,
    required this.inventory,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.grass_outlined, color: AppColors.workerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inventory.cropName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  warehouse.name,
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
          Text(
            '${inventory.totalBags} bags',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityCard(this.item);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(item.icon, color: AppColors.workerColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    item.subtitle,
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
            Text(
              item.when,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final String when;
  final DateTime date;
  final IconData icon;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.when,
    required this.date,
    required this.icon,
  });
}

class CropStockDetailsScreen extends ConsumerWidget {
  final String warehouseId;
  final int cropId;
  final bool ownerFlow;

  const CropStockDetailsScreen({
    super.key,
    required this.warehouseId,
    required this.cropId,
    this.ownerFlow = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouseAsync = ref.watch(warehouseByIdProvider(warehouseId));
    final inventoryAsync = ref.watch(warehouseInventoryProvider(warehouseId));
    final dispatchesAsync = ref.watch(warehouseDispatchesProvider(warehouseId));
    final countsAsync = ref.watch(warehouseStockCountsProvider(warehouseId));
    final adjustmentsAsync =
        ref.watch(warehouseStockAdjustmentsProvider(warehouseId));
    final item = _findInventory(
      inventoryAsync.valueOrNull ?? const <WarehouseInventory>[],
      cropId,
    );
    final activities = _recentActivities(
      cropId: cropId,
      dispatches: dispatchesAsync.valueOrNull ?? const [],
      counts: countsAsync.valueOrNull ?? const [],
      adjustments: adjustmentsAsync.valueOrNull ?? const [],
    );

    return Scaffold(
      appBar: AppBar(title: Text(item?.cropName ?? 'Crop stock')),
      body: warehouseAsync.when(
        data: (warehouse) {
          if (warehouse == null) {
            return const ErrorView(message: 'Warehouse not found');
          }
          if (item == null) {
            return const ErrorView(message: 'Crop stock not found');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Text(
                warehouse.name,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.cropName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _CurrentStockCard(item: item),
              const SizedBox(height: 18),
              const Text(
                'Manage Stock',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _OperationGrid(
                onDispatch: () => context.push(
                  _operationPath(
                    ownerFlow: ownerFlow,
                    warehouseId: warehouseId,
                    cropId: cropId,
                    operation: 'dispatch',
                  ),
                ),
                onCount: () => context.push(
                  _operationPath(
                    ownerFlow: ownerFlow,
                    warehouseId: warehouseId,
                    cropId: cropId,
                    operation: 'count',
                  ),
                ),
                onAdjustment: () => context.push(
                  _operationPath(
                    ownerFlow: ownerFlow,
                    warehouseId: warehouseId,
                    cropId: cropId,
                    operation: 'adjustment',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Activity',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (activities.length > 3)
                    TextButton(
                      onPressed: () => _showActivitySheet(context, activities),
                      child: const Text('View all'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (activities.isEmpty)
                const AppCard(
                  child: Text(
                    'No activity recorded for this crop yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...activities.take(3).map(_ActivityCard.new),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: '$error'),
      ),
    );
  }
}

class WarehouseOperationFormScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  final int cropId;
  final String operation;
  final bool ownerFlow;

  const WarehouseOperationFormScreen({
    super.key,
    required this.warehouseId,
    required this.cropId,
    required this.operation,
    this.ownerFlow = true,
  });

  @override
  ConsumerState<WarehouseOperationFormScreen> createState() =>
      _WarehouseOperationFormScreenState();
}

class _WarehouseOperationFormScreenState
    extends ConsumerState<WarehouseOperationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _bags = TextEditingController();
  final _grossWeight = TextEditingController();
  final _moisture = TextEditingController(text: '0');
  String _recipientType = WarehouseRecipientType.buyer;
  String _adjustmentType = StockAdjustmentType.increase;
  String _reason = StockAdjustmentReason.correction;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bags.addListener(_refreshComputed);
    _grossWeight.addListener(_refreshComputed);
    _moisture.addListener(_refreshComputed);
  }

  @override
  void dispose() {
    _bags.removeListener(_refreshComputed);
    _grossWeight.removeListener(_refreshComputed);
    _moisture.removeListener(_refreshComputed);
    _recipientName.dispose();
    _recipientPhone.dispose();
    _bags.dispose();
    _grossWeight.dispose();
    _moisture.dispose();
    super.dispose();
  }

  void _refreshComputed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final action = _actionFromPath(widget.operation);
    final warehouseAsync = ref.watch(warehouseByIdProvider(widget.warehouseId));
    final cropsAsync = ref.watch(allCropsProvider);
    final inventoryAsync =
        ref.watch(warehouseInventoryProvider(widget.warehouseId));
    final inventory =
        _findInventory(inventoryAsync.valueOrNull ?? const [], widget.cropId);
    final crop = _findCrop(cropsAsync.valueOrNull ?? const [], widget.cropId) ??
        (inventory == null ? null : _cropFromInventory(inventory));

    return Scaffold(
      appBar: AppBar(title: Text(_titleForAction(action))),
      body: warehouseAsync.when(
        data: (warehouse) {
          if (warehouse == null) {
            return const ErrorView(message: 'Warehouse not found');
          }
          if (crop == null || inventory == null) {
            return const ErrorView(message: 'Crop stock not found');
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _OperationContextCard(
                  warehouse: warehouse,
                  inventory: inventory,
                ),
                const SizedBox(height: 14),
                if (action == _WarehouseAction.dispatch) _dispatchFields(),
                if (action == _WarehouseAction.adjustment) _adjustmentFields(),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bags,
                        decoration: const InputDecoration(
                          labelText: 'Bags',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _positiveInt,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _grossWeight,
                        decoration: const InputDecoration(
                          labelText: 'Gross weight',
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        validator: _positiveNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_requiresMoisture(crop)) ...[
                  TextFormField(
                    controller: _moisture,
                    decoration: const InputDecoration(
                      labelText: 'Moisture content',
                      suffixText: '%',
                      prefixIcon: Icon(Icons.water_drop_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: _percent,
                  ),
                  const SizedBox(height: 14),
                ],
                _ComputedTotals(
                  crop: crop,
                  packagingWeight: _packagingWeight(crop),
                  netWeight: _netWeight(crop),
                ),
                const SizedBox(height: 22),
                _saving
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.workerColor,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _save(
                          action: action,
                          warehouse: warehouse,
                          crop: crop,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.workerColor,
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
              ],
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: '$error'),
      ),
    );
  }

  Widget _dispatchFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _recipientType,
          decoration: const InputDecoration(
            labelText: 'Recipient type',
            prefixIcon: Icon(Icons.person_pin_outlined),
          ),
          items: WarehouseRecipientType.values
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(
            () => _recipientType = value ?? WarehouseRecipientType.buyer,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _recipientName,
          decoration: const InputDecoration(
            labelText: 'Recipient name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: _required,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _recipientPhone,
          decoration: const InputDecoration(
            labelText: 'Recipient phone (Optional)',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _adjustmentFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _adjustmentType,
          decoration: const InputDecoration(
            labelText: 'Adjustment type',
            prefixIcon: Icon(Icons.swap_vert_rounded),
          ),
          items: StockAdjustmentType.values
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(
            () => _adjustmentType = value ?? StockAdjustmentType.increase,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _reason,
          decoration: const InputDecoration(
            labelText: 'Reason',
            prefixIcon: Icon(Icons.info_outline),
          ),
          items: StockAdjustmentReason.values
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _reason = value ?? StockAdjustmentReason.other),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  int get _bagsValue => int.tryParse(_bags.text.trim()) ?? 0;
  double get _grossValue => double.tryParse(_grossWeight.text.trim()) ?? 0;

  double _moistureValue(Crop crop) =>
      _requiresMoisture(crop) ? double.tryParse(_moisture.text.trim()) ?? 0 : 0;

  double _packagingWeight(Crop crop) {
    final cropWeight = crop.packagingWeight ?? 0;
    return cropWeight * _bagsValue;
  }

  double _netWeight(Crop crop) {
    final net = _grossValue - _packagingWeight(crop);
    return net < 0 ? 0 : net;
  }

  Future<void> _save({
    required _WarehouseAction action,
    required Warehouse warehouse,
    required Crop crop,
  }) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(warehouseOperationsRepoProvider);
      switch (action) {
        case _WarehouseAction.dispatch:
          await repo.recordDispatch(
            warehouse: warehouse,
            crop: crop,
            recipientType: _recipientType,
            recipientName: _recipientName.text.trim(),
            recipientPhone: _recipientPhone.text.trim().isEmpty
                ? null
                : _recipientPhone.text.trim(),
            totalBags: _bagsValue,
            totalGrossWeight: _grossValue,
            totalPackagingWeight: _packagingWeight(crop),
            totalNetWeight: _netWeight(crop),
            moistureContent: _moistureValue(crop),
          );
        case _WarehouseAction.count:
          await repo.recordStockCount(
            warehouse: warehouse,
            crop: crop,
            countedBags: _bagsValue,
            countedGrossWeight: _grossValue,
            countedPackagingWeight: _packagingWeight(crop),
            countedNetWeight: _netWeight(crop),
            moistureContent: _moistureValue(crop),
          );
        case _WarehouseAction.adjustment:
          await repo.recordStockAdjustment(
            warehouse: warehouse,
            crop: crop,
            adjustmentType: _adjustmentType,
            reason: _reason,
            bags: _bagsValue,
            grossWeight: _grossValue,
            packagingWeight: _packagingWeight(crop),
            netWeight: _netWeight(crop),
            moistureContent: _moistureValue(crop),
          );
      }
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record saved for sync.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _positiveInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed <= 0 ? 'Enter a positive number' : null;
  }

  String? _positiveNumber(String? value) {
    final parsed = double.tryParse(value ?? '');
    return parsed == null || parsed <= 0 ? 'Enter a positive number' : null;
  }

  String? _percent(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0 || parsed > 100) return 'Enter 0 to 100';
    return null;
  }
}

class _ComputedTotals extends StatelessWidget {
  final Crop? crop;
  final double packagingWeight;
  final double netWeight;

  const _ComputedTotals({
    required this.crop,
    required this.packagingWeight,
    required this.netWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.workerColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.workerColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          _TotalRow(
            label: 'Crop packaging weight',
            value: '${_formatNumber(crop?.packagingWeight ?? 0)} per bag',
          ),
          _TotalRow(
            label: 'Total packaging weight',
            value: _formatNumber(packagingWeight),
          ),
          _TotalRow(label: 'Net weight', value: _formatNumber(netWeight)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final num value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${_formatNumber(value)} kg',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;

  const _TotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

List<WarehouseInventory> _filterInventory(
  List<WarehouseInventory> items,
  String query,
) {
  if (query.isEmpty) return items;
  return items
      .where((item) =>
          item.cropName.toLowerCase().contains(query) ||
          (item.collectionCenterName ?? '').toLowerCase().contains(query))
      .toList();
}

WarehouseInventory? _findInventory(List<WarehouseInventory> items, int cropId) {
  for (final item in items) {
    if (item.crop == cropId) return item;
  }
  return null;
}

Crop? _findCrop(List<Crop> crops, int cropId) {
  for (final crop in crops) {
    if (crop.id == cropId) return crop;
  }
  return null;
}

Crop _cropFromInventory(WarehouseInventory item) {
  final packagingWeight =
      item.totalBags <= 0 ? 0.0 : item.totalPackagingWeight / item.totalBags;
  return Crop(
    id: item.crop,
    name: item.cropName,
    moistureContentComputation: false,
    packagingWeight: packagingWeight,
  );
}

bool _requiresMoisture(Crop crop) => crop.moistureContentComputation;

_WarehouseAction _actionFromPath(String value) {
  return switch (value) {
    'dispatch' => _WarehouseAction.dispatch,
    'count' || 'stock-count' => _WarehouseAction.count,
    'adjustment' => _WarehouseAction.adjustment,
    _ => _WarehouseAction.dispatch,
  };
}

String _titleForAction(_WarehouseAction action) {
  return switch (action) {
    _WarehouseAction.dispatch => 'Dispatch stock',
    _WarehouseAction.count => 'Stock count',
    _WarehouseAction.adjustment => 'Stock adjustment',
  };
}

String _operationPath({
  required bool ownerFlow,
  required String warehouseId,
  required int cropId,
  required String operation,
}) {
  return ownerFlow
      ? AppRoutes.ownerWarehouseOperationFormFor(
          warehouseId,
          cropId.toString(),
          operation,
        )
      : AppRoutes.workerWarehouseOperationFormFor(
          warehouseId,
          cropId.toString(),
          operation,
        );
}

List<_ActivityItem> _recentActivities({
  required int cropId,
  required List<WarehouseDispatch> dispatches,
  required List<WarehouseStockCount> counts,
  required List<WarehouseStockAdjustment> adjustments,
}) {
  final activities = <_ActivityItem>[
    for (final item in dispatches.where((item) => item.crop == cropId))
      _ActivityItem(
        title: 'Dispatch',
        subtitle:
            '-${item.totalBags} bags - ${_formatNumber(item.totalNetWeight)} kg',
        when: _shortDate(item.dispatchedAt),
        date: item.dispatchedAt,
        icon: Icons.local_shipping_outlined,
      ),
    for (final item in counts.where((item) => item.crop == cropId))
      _ActivityItem(
        title: 'Stock Count',
        subtitle:
            '${item.countedBags} bags counted - ${_formatNumber(item.countedNetWeight)} kg',
        when: _shortDate(item.countedAt),
        date: item.countedAt,
        icon: Icons.fact_check_outlined,
      ),
    for (final item in adjustments.where((item) => item.crop == cropId))
      _ActivityItem(
        title: 'Adjustment',
        subtitle: '${item.adjustmentType} - ${item.reason}',
        when: _shortDate(item.adjustedAt),
        date: item.adjustedAt,
        icon: Icons.tune_rounded,
      ),
  ];
  activities.sort((a, b) => b.date.compareTo(a.date));
  return activities;
}

void _showActivitySheet(BuildContext context, List<_ActivityItem> activities) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: activities.map(_ActivityCard.new).toList(),
      ),
    ),
  );
}

String _shortDate(DateTime value) {
  final now = DateTime.now();
  final local = value.toLocal();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday';
  }
  return '${local.day}/${local.month}/${local.year}';
}

String _formatNumber(num value) {
  if (value.isNaN || value.isInfinite) return '0';
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
