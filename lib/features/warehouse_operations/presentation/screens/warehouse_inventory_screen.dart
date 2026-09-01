import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/features/warehouse_operations/domain/models/warehouse_operation_models.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

enum _WarehouseAction { dispatch, count, adjustment }

class WarehouseInventoryScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  const WarehouseInventoryScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<WarehouseInventoryScreen> createState() =>
      _WarehouseInventoryScreenState();
}

class _WarehouseInventoryScreenState
    extends ConsumerState<WarehouseInventoryScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final TabController _tabs;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final warehouseAsync = ref.watch(warehouseByIdProvider(widget.warehouseId));
    final inventoryAsync =
        ref.watch(warehouseInventoryProvider(widget.warehouseId));
    final dispatchesAsync =
        ref.watch(warehouseDispatchesProvider(widget.warehouseId));
    final countsAsync =
        ref.watch(warehouseStockCountsProvider(widget.warehouseId));
    final adjustmentsAsync =
        ref.watch(warehouseStockAdjustmentsProvider(widget.warehouseId));
    final cropsAsync = ref.watch(allCropsProvider);
    final warehouseName = warehouseAsync.valueOrNull?.name ?? l10n.inventory;

    return Scaffold(
      appBar: AppBar(
        title: Text(warehouseName),
        actions: const [SyncIndicator()],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Inventory'),
            Tab(text: 'Dispatches'),
            Tab(text: 'Counts'),
            Tab(text: 'Adjustments'),
          ],
        ),
      ),
      floatingActionButton: warehouseAsync.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showActionSheet(
                warehouse: warehouseAsync.valueOrNull!,
                inventory: inventoryAsync.valueOrNull ?? const [],
                crops: cropsAsync.valueOrNull ?? const [],
              ),
              backgroundColor: AppColors.workerColor,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label:
                  const Text('Record', style: TextStyle(color: Colors.white)),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search crops or warehouses',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _InventoryTab(
                  inventoryAsync: inventoryAsync,
                  query: _query,
                  onAction: (item, action) {
                    final warehouse = warehouseAsync.valueOrNull;
                    if (warehouse == null) return;
                    _openOperationSheet(
                      action: action,
                      warehouse: warehouse,
                      inventory: inventoryAsync.valueOrNull ?? const [],
                      crops: cropsAsync.valueOrNull ?? const [],
                      initialInventory: item,
                    );
                  },
                ),
                _DispatchesTab(async: dispatchesAsync, query: _query),
                _StockCountsTab(async: countsAsync, query: _query),
                _AdjustmentsTab(async: adjustmentsAsync, query: _query),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActionSheet({
    required Warehouse warehouse,
    required List<WarehouseInventory> inventory,
    required List<Crop> crops,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.local_shipping_outlined,
                title: 'Dispatch stock',
                subtitle: 'Record crops leaving this warehouse',
                onTap: () {
                  Navigator.pop(context);
                  _openOperationSheet(
                    action: _WarehouseAction.dispatch,
                    warehouse: warehouse,
                    inventory: inventory,
                    crops: crops,
                  );
                },
              ),
              _ActionTile(
                icon: Icons.fact_check_outlined,
                title: 'Stock count',
                subtitle: 'Record the physical count without changing stock',
                onTap: () {
                  Navigator.pop(context);
                  _openOperationSheet(
                    action: _WarehouseAction.count,
                    warehouse: warehouse,
                    inventory: inventory,
                    crops: crops,
                  );
                },
              ),
              _ActionTile(
                icon: Icons.tune_rounded,
                title: 'Stock adjustment',
                subtitle: 'Increase or decrease stock with a reason',
                onTap: () {
                  Navigator.pop(context);
                  _openOperationSheet(
                    action: _WarehouseAction.adjustment,
                    warehouse: warehouse,
                    inventory: inventory,
                    crops: crops,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openOperationSheet({
    required _WarehouseAction action,
    required Warehouse warehouse,
    required List<WarehouseInventory> inventory,
    required List<Crop> crops,
    WarehouseInventory? initialInventory,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarehouseOperationSheet(
        action: action,
        warehouse: warehouse,
        inventory: inventory,
        crops: crops,
        initialInventory: initialInventory,
      ),
    );
  }
}

class _InventoryTab extends StatelessWidget {
  final AsyncValue<List<WarehouseInventory>> inventoryAsync;
  final String query;
  final void Function(WarehouseInventory item, _WarehouseAction action)
      onAction;

  const _InventoryTab({
    required this.inventoryAsync,
    required this.query,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return inventoryAsync.when(
      data: (items) {
        final filtered = _filterInventory(items, query);
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No inventory yet',
            subtitle: 'Sync or record an increase adjustment to see stock.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) => _InventoryCard(
            item: filtered[index],
            onAction: (action) => onAction(filtered[index], action),
          ),
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: '$error'),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final WarehouseInventory item;
  final void Function(_WarehouseAction action) onAction;

  const _InventoryCard({required this.item, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((item.collectionCenterName ?? '').isNotEmpty)
                      Text(
                        item.collectionCenterName!,
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
                '${item.totalBags} bags',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                  child: _Metric(label: 'Gross', value: item.totalGrossWeight)),
              Expanded(
                child: _Metric(
                    label: 'Packaging', value: item.totalPackagingWeight),
              ),
              Expanded(
                  child: _Metric(label: 'Net', value: item.totalNetWeight)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAction(_WarehouseAction.dispatch),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Dispatch'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Stock count',
                onPressed: () => onAction(_WarehouseAction.count),
                icon: const Icon(Icons.fact_check_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Adjust stock',
                onPressed: () => onAction(_WarehouseAction.adjustment),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarehouseOperationSheet extends ConsumerStatefulWidget {
  final _WarehouseAction action;
  final Warehouse warehouse;
  final List<WarehouseInventory> inventory;
  final List<Crop> crops;
  final WarehouseInventory? initialInventory;

  const _WarehouseOperationSheet({
    required this.action,
    required this.warehouse,
    required this.inventory,
    required this.crops,
    this.initialInventory,
  });

  @override
  ConsumerState<_WarehouseOperationSheet> createState() =>
      _WarehouseOperationSheetState();
}

class _WarehouseOperationSheetState
    extends ConsumerState<_WarehouseOperationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _bags = TextEditingController();
  final _grossWeight = TextEditingController();
  final _moisture = TextEditingController(text: '0');
  String _recipientType = WarehouseRecipientType.buyer;
  String _adjustmentType = StockAdjustmentType.increase;
  String _reason = StockAdjustmentReason.correction;
  int? _cropId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cropId = widget.initialInventory?.crop ??
        (widget.crops.isNotEmpty ? widget.crops.first.id : null);
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
    final title = switch (widget.action) {
      _WarehouseAction.dispatch => 'Dispatch stock',
      _WarehouseAction.count => 'Stock count',
      _WarehouseAction.adjustment => 'Stock adjustment',
    };

    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 36,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _cropId,
                decoration: const InputDecoration(
                  labelText: 'Crop',
                  prefixIcon: Icon(Icons.grass_outlined),
                ),
                items: widget.crops
                    .map(
                      (crop) => DropdownMenuItem(
                        value: crop.id,
                        child: Text(crop.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _cropId = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              if (widget.action == _WarehouseAction.dispatch) _dispatchFields(),
              if (widget.action == _WarehouseAction.adjustment)
                _adjustmentFields(),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: _positiveNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _moisture,
                decoration: const InputDecoration(
                  labelText: 'Moisture content',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: _percent,
              ),
              const SizedBox(height: 14),
              _ComputedTotals(
                crop: _selectedCrop,
                packagingWeight: _packagingWeight,
                netWeight: _netWeight,
              ),
              const SizedBox(height: 22),
              _saving
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.workerColor,
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.workerColor,
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
            ],
          ),
        ),
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
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) => setState(
              () => _recipientType = value ?? WarehouseRecipientType.buyer),
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
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) => setState(
              () => _adjustmentType = value ?? StockAdjustmentType.increase),
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
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) =>
              setState(() => _reason = value ?? StockAdjustmentReason.other),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Crop? get _selectedCrop {
    final id = _cropId;
    if (id == null) return null;
    return widget.crops.where((crop) => crop.id == id).firstOrNull;
  }

  int get _bagsValue => int.tryParse(_bags.text.trim()) ?? 0;
  double get _grossValue => double.tryParse(_grossWeight.text.trim()) ?? 0;
  double get _moistureValue => double.tryParse(_moisture.text.trim()) ?? 0;

  double get _packagingWeight {
    final cropWeight = _selectedCrop?.packagingWeight ?? 0;
    return cropWeight * _bagsValue;
  }

  double get _netWeight {
    final net = _grossValue - _packagingWeight;
    return net < 0 ? 0 : net;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final crop = _selectedCrop;
    if (crop == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(warehouseOperationsRepoProvider);
      switch (widget.action) {
        case _WarehouseAction.dispatch:
          await repo.recordDispatch(
            warehouse: widget.warehouse,
            crop: crop,
            recipientType: _recipientType,
            recipientName: _recipientName.text.trim(),
            recipientPhone: _recipientPhone.text.trim().isEmpty
                ? null
                : _recipientPhone.text.trim(),
            totalBags: _bagsValue,
            totalGrossWeight: _grossValue,
            totalPackagingWeight: _packagingWeight,
            totalNetWeight: _netWeight,
            moistureContent: _moistureValue,
          );
        case _WarehouseAction.count:
          await repo.recordStockCount(
            warehouse: widget.warehouse,
            crop: crop,
            countedBags: _bagsValue,
            countedGrossWeight: _grossValue,
            countedPackagingWeight: _packagingWeight,
            countedNetWeight: _netWeight,
            moistureContent: _moistureValue,
          );
        case _WarehouseAction.adjustment:
          await repo.recordStockAdjustment(
            warehouse: widget.warehouse,
            crop: crop,
            adjustmentType: _adjustmentType,
            reason: _reason,
            bags: _bagsValue,
            grossWeight: _grossValue,
            packagingWeight: _packagingWeight,
            netWeight: _netWeight,
            moistureContent: _moistureValue,
          );
      }
      if (!mounted) return;
      Navigator.pop(context);
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

class _DispatchesTab extends StatelessWidget {
  final AsyncValue<List<WarehouseDispatch>> async;
  final String query;

  const _DispatchesTab({required this.async, required this.query});

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: (items) {
        final filtered = items
            .where((item) =>
                query.isEmpty ||
                item.cropName.toLowerCase().contains(query) ||
                item.recipientName.toLowerCase().contains(query))
            .toList();
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'No dispatches yet',
          );
        }
        return _operationList(
          filtered
              .map(
                (item) => _OperationCard(
                  title: item.cropName,
                  subtitle: item.recipientName,
                  amount: '${item.totalBags} bags',
                  syncStatus: item.syncStatus,
                  icon: Icons.local_shipping_outlined,
                ),
              )
              .toList(),
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: '$error'),
    );
  }
}

class _StockCountsTab extends StatelessWidget {
  final AsyncValue<List<WarehouseStockCount>> async;
  final String query;

  const _StockCountsTab({required this.async, required this.query});

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: (items) {
        final filtered = items
            .where((item) =>
                query.isEmpty || item.cropName.toLowerCase().contains(query))
            .toList();
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No stock counts yet',
          );
        }
        return _operationList(
          filtered
              .map(
                (item) => _OperationCard(
                  title: item.cropName,
                  subtitle:
                      'Expected ${item.expectedBags}, counted ${item.countedBags}',
                  amount: _formatNumber(item.countedNetWeight),
                  syncStatus: item.syncStatus,
                  icon: Icons.fact_check_outlined,
                ),
              )
              .toList(),
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: '$error'),
    );
  }
}

class _AdjustmentsTab extends StatelessWidget {
  final AsyncValue<List<WarehouseStockAdjustment>> async;
  final String query;

  const _AdjustmentsTab({required this.async, required this.query});

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: (items) {
        final filtered = items
            .where((item) =>
                query.isEmpty ||
                item.cropName.toLowerCase().contains(query) ||
                item.reason.toLowerCase().contains(query))
            .toList();
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.tune_rounded,
            title: 'No adjustments yet',
          );
        }
        return _operationList(
          filtered
              .map(
                (item) => _OperationCard(
                  title: item.cropName,
                  subtitle: '${item.adjustmentType} - ${item.reason}',
                  amount: '${item.bags} bags',
                  syncStatus: item.syncStatus,
                  icon: Icons.tune_rounded,
                ),
              )
              .toList(),
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: '$error'),
    );
  }
}

Widget _operationList(List<Widget> children) {
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: children.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, index) => children[index],
  );
}

class _OperationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String syncStatus;
  final IconData icon;

  const _OperationCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.syncStatus,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.workerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  subtitle,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
              SyncStatusBadge(status: syncStatus),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.workerColor),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        Text(
          _formatNumber(value),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ],
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

String _formatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}
