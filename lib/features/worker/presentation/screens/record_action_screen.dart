// lib/features/worker/presentation/screens/record_action_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class RecordActionScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  const RecordActionScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<RecordActionScreen> createState() => _RecordActionScreenState();
}

class _RecordActionScreenState extends ConsumerState<RecordActionScreen> {
  InventoryItem? _item;
  String _type = 'delivery';
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  bool _success = false;

  @override
  void dispose() { _qtyCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_item == null || _qtyCtrl.text.isEmpty) return;
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid quantity'),
              backgroundColor: AppColors.error));
      return;
    }
    setState(() { _loading = true; _success = false; });
    try {
      final repo = ref.read(inventoryRepoProvider);
      switch (_type) {
        case 'delivery': await repo.recordDelivery(itemId: _item!.id, quantity: qty, notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text);
        case 'count': await repo.recordCount(itemId: _item!.id, actualCount: qty, notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text);
        case 'adjustment': await repo.recordAdjustment(itemId: _item!.id, quantity: qty, notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text);
      }
      if (mounted) {
        setState(() { _success = true; _item = null; _loading = false; });
        _qtyCtrl.clear(); _notesCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsProvider(widget.warehouseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Action'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/worker'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success flash
            if (_success)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success),
                  SizedBox(width: 10),
                  Expanded(child: Text('Action recorded successfully!',
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))),
                ]),
              ),

            // Action type
            const Text('Action Type',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            Row(children: [
              for (final (val, label, icon, color) in [
                ('delivery', 'Delivery', Icons.arrow_downward_rounded, AppColors.success),
                ('count', 'Count', Icons.checklist_rounded, AppColors.info),
                ('adjustment', 'Adjust', Icons.tune_rounded, AppColors.workerColor),
              ])
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _type = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _type == val ? color.withOpacity(0.12) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _type == val ? color : AppColors.divider,
                          width: _type == val ? 2 : 1,
                        ),
                      ),
                      child: Column(children: [
                        Icon(icon, color: _type == val ? color : AppColors.textMuted, size: 24),
                        const SizedBox(height: 6),
                        Text(label, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _type == val ? color : AppColors.textMuted,
                        )),
                      ]),
                    ),
                  ),
                )),
            ]),

            const SizedBox(height: 24),
            const Text('Item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            itemsAsync.when(
              data: (items) => DropdownButtonFormField<InventoryItem>(
                initialValue: _item,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Select item…'),
                items: items.map((i) {
                  final qty = i.quantityOnHand % 1 == 0
                      ? i.quantityOnHand.toInt().toString()
                      : i.quantityOnHand.toStringAsFixed(1);
                  return DropdownMenuItem(
                    value: i,
                    child: Text('${i.name} ($qty ${i.unit})',
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _item = v),
              ),
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: '$e'),
            ),

            // Show selected item's current stock
            if (_item != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Current: ${_item!.quantityOnHand % 1 == 0 ? _item!.quantityOnHand.toInt() : _item!.quantityOnHand.toStringAsFixed(1)} ${_item!.unit}',
                    style: const TextStyle(color: AppColors.primary,
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 20),
            const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: AppColors.textMuted),
                suffix: _item != null ? Text(_item!.unit,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondary)) : null,
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),

            const SizedBox(height: 32),
            _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.workerColor))
                : ElevatedButton.icon(
                    onPressed: (_item != null && _qtyCtrl.text.isNotEmpty) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.workerColor,
                      disabledBackgroundColor: AppColors.divider,
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Submit'),
                  ),
          ],
        ),
      ),
    );
  }
}
