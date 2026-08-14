// lib/features/worker/presentation/screens/inventory_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../../l10n/app_localizations.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  const InventoryListScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  String _query = '';
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
    final itemsAsync = ref.watch(inventoryItemsProvider(widget.warehouseId));
    final lowAsync = ref.watch(lowStockProvider(widget.warehouseId));
    final whAsync = ref.watch(warehouseByIdProvider(widget.warehouseId));
    final whName = whAsync.valueOrNull?.name ?? l10n.inventory;

    return Scaffold(
      appBar: AppBar(
        title: Text(whName),
        actions: const [SyncIndicator()],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: l10n.allItems(itemsAsync.valueOrNull?.length ?? 0)),
            Tab(text: l10n.lowStockItems(lowAsync.valueOrNull?.length ?? 0)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemSheet(context),
        backgroundColor: AppColors.workerColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(l10n.addItem, style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                  hintText: l10n.searchItems,
                  prefixIcon: const Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ItemList(
                    itemsAsync: itemsAsync,
                    query: _query,
                    warehouseId: widget.warehouseId),
                _ItemList(
                    itemsAsync: lowAsync,
                    query: _query,
                    warehouseId: widget.warehouseId,
                    emptyIcon: Icons.check_circle_rounded,
                    emptyTitle: l10n.noLowStockItems,
                    emptySubtitle: l10n.allAboveReorder),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(warehouseId: widget.warehouseId),
    );
  }
}

class _ItemList extends ConsumerWidget {
  final AsyncValue<List<InventoryItem>> itemsAsync;
  final String query;
  final String warehouseId;
  final IconData emptyIcon;
  final String? emptyTitle;
  final String? emptySubtitle;

  const _ItemList({
    required this.itemsAsync,
    required this.query,
    required this.warehouseId,
    this.emptyIcon = Icons.inventory_2_rounded,
    this.emptyTitle,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return itemsAsync.when(
      data: (list) {
        final filtered = query.isEmpty
            ? list
            : list
                .where((i) =>
                    i.name.toLowerCase().contains(query) ||
                    (i.category?.toLowerCase().contains(query) ?? false))
                .toList();

        if (filtered.isEmpty) {
          return EmptyState(
              icon: emptyIcon,
              title: emptyTitle ?? l10n.noItemsYet,
              subtitle: emptySubtitle ?? l10n.addItemToStart);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) =>
              _InventoryItemCard(item: filtered[i], warehouseId: warehouseId),
        );
      },
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e'),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final String warehouseId;
  const _InventoryItemCard({required this.item, required this.warehouseId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLow = item.quantityOnHand <= item.reorderLevel;
    final pct = item.reorderLevel > 0
        ? (item.quantityOnHand / (item.reorderLevel * 2)).clamp(0.0, 1.0)
        : 1.0;

    return AppCard(
      onTap: () => context.go(
        AppRoutes.workerInventoryItemFor(warehouseId, item.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                if (item.category != null)
                  Text(item.category!,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
              ],
            )),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    '${item.quantityOnHand % 1 == 0 ? item.quantityOnHand.toInt() : item.quantityOnHand.toStringAsFixed(1)} ${item.unit}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color:
                            isLow ? AppColors.error : AppColors.textPrimary)),
                SyncStatusBadge(status: item.syncStatus),
              ],
            ),
          ]),
          if (item.reorderLevel > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(
                      isLow ? AppColors.error : AppColors.success),
                ),
              )),
              const SizedBox(width: 8),
              if (isLow)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(l10n.reorder,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _AddItemSheet extends ConsumerStatefulWidget {
  final String warehouseId;
  const _AddItemSheet({required this.warehouseId});
  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pcs');
  final _reorderCtrl = TextEditingController(text: '0');
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _catCtrl.dispose();
    _unitCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(inventoryRepoProvider).createItem(
            warehouseId: widget.warehouseId,
            name: _nameCtrl.text.trim(),
            sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
            category:
                _catCtrl.text.trim().isEmpty ? null : _catCtrl.text.trim(),
            unit: _unitCtrl.text.trim(),
            reorderLevel: double.tryParse(_reorderCtrl.text) ?? 0,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.errorWithDetails('$e')),
            backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(l10n.addInventoryItem,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l10n.itemName),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? l10n.requiredField : null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _skuCtrl,
                        decoration: InputDecoration(labelText: l10n.sku))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextFormField(
                        controller: _catCtrl,
                        decoration: InputDecoration(labelText: l10n.category))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _unitCtrl,
                        decoration: InputDecoration(labelText: l10n.unit))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextFormField(
                        controller: _reorderCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: l10n.reorderLevel))),
              ]),
              const SizedBox(height: 24),
              _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.workerColor))
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.workerColor),
                      child: Text(l10n.addItem)),
            ],
          ),
        ),
      ),
    );
  }
}
