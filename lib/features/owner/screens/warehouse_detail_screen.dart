// lib/features/owner/screens/warehouse_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../l10n/app_localizations.dart';

final _warehouseWorkersProvider =
    StreamProvider.family((ref, String warehouseId) {
  return ref.watch(workerRepoProvider).watchWorkersByWarehouse(warehouseId);
});

class WarehouseDetailScreen extends ConsumerWidget {
  final String warehouseId;
  const WarehouseDetailScreen({super.key, required this.warehouseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final warehouseAsync = ref.watch(warehouseByIdProvider(warehouseId));
    final inventoryAsync = ref.watch(warehouseInventoryProvider(warehouseId));
    final workersAsync = ref.watch(_warehouseWorkersProvider(warehouseId));

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: GestureDetector(
          child: const Icon(Icons.arrow_back),
          onTap: () => context.pop(),
        ),
        title: const SizedBox.shrink(),
        actions: [
          warehouseAsync.maybeWhen(
            data: (w) => w != null
                ? IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _showEditSheet(context, w))
                : const SizedBox(),
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: warehouseAsync.when(
        data: (warehouse) {
          if (warehouse == null) {
            return ErrorView(message: l10n.warehouseNotFound);
          }
          final inventoryItems =
              inventoryAsync.valueOrNull ?? const <WarehouseInventory>[];
          final totalBags = inventoryItems.fold<num>(
            0,
            (sum, item) => sum + item.totalBags,
          );
          final totalPackagingWeight = inventoryItems.fold<num>(
            0,
            (sum, item) => sum + item.totalPackagingWeight,
          );
          final totalNetWeight = inventoryItems.fold<num>(
            0,
            (sum, item) => sum + item.totalNetWeight,
          );
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.inventory_2_rounded,
                            color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text('Inventory summary',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700))),
                      ]),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryMetric(
                              label: l10n.crops,
                              value: '${inventoryItems.length}',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _SummaryMetric(
                              label: 'Bags',
                              value: _formatNumber(totalBags),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryMetric(
                              label: l10n.packagingWeightKg,
                              value:
                                  '${_formatNumber(totalPackagingWeight)} kg',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _SummaryMetric(
                              label: l10n.netWeight,
                              value: '${_formatNumber(totalNetWeight)} kg',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      AppRoutes.ownerWarehouseOperationsFor(warehouse.id),
                    ),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Manage stock'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.inventory,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.ownerWarehouseOperationsFor(warehouse.id),
                        ),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('View all'),
                      ),
                    ],
                  ),
                ),
              ),
              inventoryAsync.when(
                data: (items) {
                  final preview = items.take(3).toList();
                  if (preview.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.noInventoryItems,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _InventoryTotalRow(item: preview[i]),
                        childCount: preview.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: LoadingView()),
                error: (e, _) =>
                    SliverToBoxAdapter(child: ErrorView(message: '$e')),
              ),
              inventoryAsync.maybeWhen(
                data: (items) {
                  final remaining = items.length - 3;
                  if (remaining <= 0) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: Text(
                        '$remaining more crops',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
                orElse: () =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
              SliverToBoxAdapter(
                  child: SectionHeader(title: l10n.assignedWorkers)),
              workersAsync.when(
                data: (workers) {
                  if (workers.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(l10n.noAssignedWorkers,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final w = workers[i];
                          return AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: [
                              CircleAvatar(
                                backgroundColor: AppColors.workerColor
                                    .withValues(alpha: 0.12),
                                child: const Icon(Icons.person_rounded,
                                    color: AppColors.workerColor, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text(w.email,
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                                ],
                              )),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: w.isActive
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.textMuted
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                    w.isActive ? l10n.active : l10n.inactive,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: w.isActive
                                            ? AppColors.success
                                            : AppColors.textMuted)),
                              ),
                            ]),
                          );
                        },
                        childCount: workers.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: LoadingView()),
                error: (e, _) =>
                    SliverToBoxAdapter(child: ErrorView(message: '$e')),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error)),
                    icon: const Icon(Icons.delete_rounded),
                    label: Text(l10n.deleteWarehouse),
                    onPressed: () async {
                      final ok = await showConfirmDialog(context,
                          title: l10n.deleteWarehouse,
                          message: l10n.deleteWarehouseConfirm(warehouse.name),
                          confirmLabel: l10n.delete,
                          isDestructive: true);
                      if (ok) {
                        await ref
                            .read(warehouseRepoProvider)
                            .deleteWarehouse(warehouseId);
                        if (context.mounted) {
                          context.go(AppRoutes.ownerWarehouses);
                        }
                      }
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
      ),
    );
  }

  void _showEditSheet(BuildContext context, Warehouse warehouse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditWarehouseSheet(warehouse: warehouse),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _InventoryTotalRow extends StatelessWidget {
  final WarehouseInventory item;
  const _InventoryTotalRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.cropName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                '${_formatNumber(item.totalBags)} bags',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _MiniMetric(
                label: l10n.grossWeight,
                value: '${_formatNumber(item.totalGrossWeight)} kg',
              ),
              _MiniMetric(
                label: l10n.packagingWeightKg,
                value: '${_formatNumber(item.totalPackagingWeight)} kg',
              ),
              _MiniMetric(
                label: l10n.netWeight,
                value: '${_formatNumber(item.totalNetWeight)} kg',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}

String _formatNumber(num value) {
  if (value % 1 == 0) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

class _EditWarehouseSheet extends ConsumerStatefulWidget {
  final Warehouse warehouse;
  const _EditWarehouseSheet({required this.warehouse});
  @override
  ConsumerState<_EditWarehouseSheet> createState() =>
      _EditWarehouseSheetState();
}

class _EditWarehouseSheetState extends ConsumerState<_EditWarehouseSheet> {
  late final _nameCtrl = TextEditingController(text: widget.warehouse.name);
  late final _gpsCtrl =
      TextEditingController(text: widget.warehouse.gpsLocation ?? '');
  late final _amcosCtrl =
      TextEditingController(text: widget.warehouse.amcos?.toString() ?? '');
  late final _amcosNameCtrl =
      TextEditingController(text: widget.warehouse.amcosName ?? '');
  late final _villageCtrl =
      TextEditingController(text: widget.warehouse.village?.toString() ?? '');
  late final _villageNameCtrl =
      TextEditingController(text: widget.warehouse.villageName ?? '');
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gpsCtrl.dispose();
    _amcosCtrl.dispose();
    _amcosNameCtrl.dispose();
    _villageCtrl.dispose();
    _villageNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await ref.read(warehouseRepoProvider).updateWarehouse(
          id: widget.warehouse.id,
          name: _nameCtrl.text.trim(),
          gpsLocation:
              _gpsCtrl.text.trim().isEmpty ? null : _gpsCtrl.text.trim(),
          amcos: _amcosCtrl.text.trim().isEmpty
              ? null
              : int.tryParse(_amcosCtrl.text.trim()),
          amcosName: _amcosNameCtrl.text.trim().isEmpty
              ? null
              : _amcosNameCtrl.text.trim(),
          village: _villageCtrl.text.trim().isEmpty
              ? null
              : int.tryParse(_villageCtrl.text.trim()),
          villageName: _villageNameCtrl.text.trim().isEmpty
              ? null
              : _villageNameCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
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
          Text(l10n.editWarehouse,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.warehouseName)),
          const SizedBox(height: 12),
          TextFormField(
              controller: _gpsCtrl,
              decoration: InputDecoration(labelText: l10n.gpsLocationAddress)),
          const SizedBox(height: 12),
          TextFormField(
              controller: _amcosCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.amcosId)),
          const SizedBox(height: 12),
          TextFormField(
              controller: _amcosNameCtrl,
              decoration: InputDecoration(labelText: l10n.amcosName)),
          const SizedBox(height: 12),
          TextFormField(
              controller: _villageCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.villageId)),
          const SizedBox(height: 12),
          TextFormField(
              controller: _villageNameCtrl,
              decoration: InputDecoration(labelText: l10n.villageName)),
          const SizedBox(height: 24),
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : ElevatedButton(onPressed: _save, child: Text(l10n.saveChanges)),
        ],
      ),
    );
  }
}
