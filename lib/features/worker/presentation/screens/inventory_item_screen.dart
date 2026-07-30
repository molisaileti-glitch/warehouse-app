// lib/features/worker/presentation/screens/inventory_item_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

final _itemDetailProvider = StreamProvider.family<InventoryItem?, String>(
  (ref, itemId) => ref.watch(inventoryRepoProvider).watchItem(itemId),
);

class InventoryItemScreen extends ConsumerWidget {
  final String warehouseId;
  final String itemId;
  const InventoryItemScreen({super.key, required this.warehouseId, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(_itemDetailProvider(itemId));
    final movementsAsync = ref.watch(stockMovementsProvider(itemId));

    return Scaffold(
      appBar: AppBar(
        title: itemAsync.maybeWhen(data: (i) => Text(i?.name ?? ''), orElse: () => const Text('Item')),
        actions: [
          itemAsync.maybeWhen(
            data: (item) => item != null
                ? IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final ok = await showConfirmDialog(context,
                          title: 'Delete Item', message: 'Soft-delete "${item.name}"?',
                          confirmLabel: 'Delete', isDestructive: true);
                      if (ok) {
                        await ref.read(inventoryRepoProvider).deleteItem(itemId);
                        if (context.mounted) context.pop();
                      }
                    },
                  )
                : const SizedBox(),
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordSheet(context),
        backgroundColor: AppColors.workerColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Record', style: TextStyle(color: Colors.white)),
      ),
      body: itemAsync.when(
        data: (item) {
          if (item == null) return const ErrorView(message: 'Item not found');
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.workerColor, Color(0xFF8E24AA)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(item.name,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
                        SyncStatusBadge(status: item.syncStatus),
                      ]),
                      if (item.sku != null) ...[
                        const SizedBox(height: 4),
                        Text('SKU: ${item.sku}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                      const SizedBox(height: 16),
                      Row(children: [
                        _HeaderStat(label: 'On Hand',
                            value: '${item.quantityOnHand % 1 == 0 ? item.quantityOnHand.toInt() : item.quantityOnHand.toStringAsFixed(1)}',
                            unit: item.unit),
                        const SizedBox(width: 20),
                        _HeaderStat(label: 'Reorder At',
                            value: '${item.reorderLevel % 1 == 0 ? item.reorderLevel.toInt() : item.reorderLevel}', unit: item.unit),
                        if (item.category != null) ...[
                          const SizedBox(width: 20),
                          _HeaderStat(label: 'Category', value: item.category!, unit: ''),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SectionHeader(title: 'Movement History')),
              movementsAsync.when(
                data: (movements) {
                  if (movements.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(padding: EdgeInsets.all(16),
                          child: Text('No movements recorded yet.', style: TextStyle(color: AppColors.textSecondary))),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                        (_, i) => _MovementTile(movement: movements[i]), childCount: movements.length)),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: LoadingView()),
                error: (e, _) => SliverToBoxAdapter(child: ErrorView(message: '$e')),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
      ),
    );
  }

  void _showRecordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _RecordMovementSheet(itemId: itemId),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _HeaderStat({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      Text('$value${unit.isNotEmpty ? ' $unit' : ''}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _MovementTile extends StatelessWidget {
  final StockMovement movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final type = movement.movementType;
    final (color, icon, sign) = switch (type) {
      'delivery' => (AppColors.success, Icons.arrow_downward_rounded, '+'),
      'transfer_out' => (AppColors.warning, Icons.arrow_forward_rounded, '-'),
      'transfer_in' => (AppColors.info, Icons.arrow_back_rounded, '+'),
      'adjustment' => (AppColors.workerColor, Icons.tune_rounded, movement.quantity >= 0 ? '+' : ''),
      _ => (AppColors.textSecondary, Icons.swap_vert_rounded, ''),
    };
    final fmt = DateFormat('MMM d • HH:mm');
    final qty = movement.quantity.abs();
    final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
    final before = movement.quantityBefore;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.3)),
            Text(fmt.format(movement.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            if (movement.notes != null)
              Text(movement.notes!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$sign$qtyStr', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          Text('was ${before % 1 == 0 ? before.toInt() : before.toStringAsFixed(1)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _RecordMovementSheet extends ConsumerStatefulWidget {
  final String itemId;
  const _RecordMovementSheet({required this.itemId});
  @override
  ConsumerState<_RecordMovementSheet> createState() => _RecordMovementSheetState();
}

class _RecordMovementSheetState extends ConsumerState<_RecordMovementSheet> {
  String _type = 'delivery';
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;

  final _types = [
    ('delivery', 'Delivery', Icons.arrow_downward_rounded, AppColors.success),
    ('adjustment', 'Adjustment', Icons.tune_rounded, AppColors.workerColor),
    ('count', 'Stock Count', Icons.checklist_rounded, AppColors.info),
  ];

  @override
  void dispose() { _qtyCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(inventoryRepoProvider);
      switch (_type) {
        case 'delivery': await repo.recordDelivery(itemId: widget.itemId, quantity: qty, notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text);
        case 'adjustment': await repo.recordAdjustment(itemId: widget.itemId, quantity: qty, notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text);
        case 'count': await repo.recordCount(itemId: widget.itemId, actualCount: qty, notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Record Movement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: _types.map((t) {
            final selected = _type == t.$1;
            return Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _type = t.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? t.$4.withOpacity(0.1) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? t.$4 : AppColors.divider, width: selected ? 1.5 : 1),
                  ),
                  child: Column(children: [
                    Icon(t.$3, color: selected ? t.$4 : AppColors.textMuted, size: 20),
                    const SizedBox(height: 4),
                    Text(t.$2, style: TextStyle(fontSize: 10, color: selected ? t.$4 : AppColors.textMuted,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
                  ]),
                ),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),
          TextFormField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: _type == 'count' ? 'Actual count' : 'Quantity',
                prefixIcon: const Icon(Icons.numbers_rounded)),
          ),
          const SizedBox(height: 10),
          TextFormField(controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes_rounded))),
          const SizedBox(height: 24),
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.workerColor))
              : ElevatedButton(onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.workerColor),
                  child: const Text('Record')),
        ],
      ),
    );
  }
}
