import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/scale/presentation/providers/weight_scale_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/features/warehouse_operations/domain/models/warehouse_operation_models.dart';

enum _WarehouseAction { dispatch, count, adjustment }

enum _OperationStep { weighing, details, review }

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
              subtitle: 'Reduces stock',
              onTap: onDispatch,
            ),
            _OperationButton(
              width: width,
              icon: Icons.fact_check_outlined,
              label: 'Stock Count',
              subtitle: 'Does not change stock',
              onTap: onCount,
            ),
            _OperationButton(
              width: width,
              icon: Icons.tune_rounded,
              label: 'Adjustment',
              subtitle: 'Changes stock',
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
  final String subtitle;
  final VoidCallback onTap;

  const _OperationButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 70,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.workerColor,
          side: BorderSide(
            color: AppColors.workerColor.withValues(alpha: 0.45),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationInfoCard extends StatelessWidget {
  final _WarehouseAction action;

  const _OperationInfoCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final icon = switch (action) {
      _WarehouseAction.dispatch => Icons.remove_circle_outline,
      _WarehouseAction.count => Icons.fact_check_outlined,
      _WarehouseAction.adjustment => Icons.swap_vert_rounded,
    };
    final title = switch (action) {
      _WarehouseAction.dispatch => 'Inventory will decrease',
      _WarehouseAction.count => 'Inventory will not change',
      _WarehouseAction.adjustment => 'Inventory will be adjusted',
    };
    final message = switch (action) {
      _WarehouseAction.dispatch =>
        'Saving a dispatch records stock leaving this warehouse.',
      _WarehouseAction.count =>
        'Saving a stock count records the physical count only.',
      _WarehouseAction.adjustment =>
        'Saving an adjustment increases or decreases the current stock.',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _StockCountDetailsCard extends StatelessWidget {
  const _StockCountDetailsCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, color: AppColors.workerColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stock count saves what was physically counted. It does not increase or decrease inventory.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  final _WarehouseAction action;
  final Warehouse warehouse;
  final WarehouseInventory inventory;
  final String recipientType;
  final String recipientName;
  final String recipientPhone;
  final String adjustmentType;
  final String reason;

  const _ReviewSummaryCard({
    required this.action,
    required this.warehouse,
    required this.inventory,
    required this.recipientType,
    required this.recipientName,
    required this.recipientPhone,
    required this.adjustmentType,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _ReviewRow(label: 'Operation', value: _titleForAction(action)),
          _ReviewRow(label: 'Warehouse', value: warehouse.name),
          _ReviewRow(label: 'Crop', value: inventory.cropName),
          if (action == _WarehouseAction.dispatch) ...[
            _ReviewRow(label: 'Recipient type', value: recipientType),
            _ReviewRow(label: 'Recipient name', value: recipientName),
            if (recipientPhone.trim().isNotEmpty)
              _ReviewRow(label: 'Recipient phone', value: recipientPhone),
          ],
          if (action == _WarehouseAction.adjustment) ...[
            _ReviewRow(label: 'Adjustment type', value: adjustmentType),
            _ReviewRow(label: 'Reason', value: reason),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleReadingCard extends StatelessWidget {
  final WeightScaleState scaleState;
  final VoidCallback? onConnect;

  const _ScaleReadingCard({
    required this.scaleState,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
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
    final subtitle = scaleState.isConnected
        ? scaleState.deviceName
        : 'Connect scale before weighing.';
    final isBusy = scaleState.isScanning || scaleState.isConnecting;

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
                  color: AppColors.workerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppColors.workerColor,
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
              _StatusPill(label: statusText, color: statusColor),
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
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
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
          if (scaleState.isConnected)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Place one bag on the scale, wait for a stable reading, then tap Add bag.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            )
          else ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onConnect,
                icon: isBusy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching_rounded),
                label: Text(isBusy ? 'Searching...' : 'Connect scale'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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
}

class _ScaleDeviceTile extends StatelessWidget {
  final ScanResult result;
  final Future<void> Function() onConnect;

  const _ScaleDeviceTile({
    required this.result,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final device = result.device;
    final name = _deviceName(device);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.workerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              color: AppColors.workerColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${device.remoteId} - ${result.rssi} dBm',
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
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onConnect,
            child: const Text('Connect'),
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
  final _moisture = TextEditingController(text: '0');
  final List<_OperationBag> _bags = [];
  _OperationStep _step = _OperationStep.weighing;
  String _recipientType = WarehouseRecipientType.buyer;
  String _adjustmentType = StockAdjustmentType.increase;
  String _reason = StockAdjustmentReason.correction;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _moisture.addListener(_refreshComputed);
  }

  @override
  void dispose() {
    _moisture.removeListener(_refreshComputed);
    _recipientName.dispose();
    _recipientPhone.dispose();
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
    final scaleState = ref.watch(weightScaleControllerProvider);
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
                _OperationInfoCard(action: action),
                const SizedBox(height: 14),
                ...switch (_step) {
                  _OperationStep.weighing => _weighingStep(crop, scaleState),
                  _OperationStep.details => _detailsStep(action),
                  _OperationStep.review =>
                    _reviewStep(action, warehouse, inventory, crop),
                },
                const SizedBox(height: 22),
                _wizardActions(
                  action: action,
                  warehouse: warehouse,
                  inventory: inventory,
                  crop: crop,
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

  List<Widget> _weighingStep(Crop crop, WeightScaleState scaleState) {
    return [
      const _SectionHeader(
        title: 'Weigh bags',
        subtitle: 'Add one bag at a time for this crop.',
      ),
      const SizedBox(height: 10),
      _ScaleReadingCard(
        scaleState: scaleState,
        onConnect: _showScalePicker,
      ),
      const SizedBox(height: 18),
      const _SectionHeader(
        title: 'Bag',
        subtitle: 'Confirm crop packaging and add each weighed bag.',
      ),
      const SizedBox(height: 10),
      _PackagingWeightSummary(
        value: _nextPackagingWeight(crop),
        unit: scaleState.uom,
      ),
      if (_requiresMoisture(crop)) ...[
        const SizedBox(height: 14),
        TextFormField(
          controller: _moisture,
          decoration: const InputDecoration(
            labelText: 'Moisture content',
            suffixText: '%',
            prefixIcon: Icon(Icons.water_drop_outlined),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _canAddBag(scaleState)
                  ? () => _addBagFromScale(crop, scaleState)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.workerColor,
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Add bag'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 52,
            width: 58,
            child: IconButton.filledTonal(
              tooltip: 'View bags',
              onPressed: _showBagsSheet,
              icon: Badge(
                label: Text('${_bags.length}'),
                child: const Icon(Icons.inventory_2_outlined),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _detailsStep(_WarehouseAction action) {
    return [
      _SectionHeader(
        title: _detailsTitle(action),
        subtitle: _detailsSubtitle(action),
      ),
      const SizedBox(height: 10),
      if (action == _WarehouseAction.dispatch) _dispatchFields(),
      if (action == _WarehouseAction.count) const _StockCountDetailsCard(),
      if (action == _WarehouseAction.adjustment) _adjustmentFields(),
    ];
  }

  List<Widget> _reviewStep(
    _WarehouseAction action,
    Warehouse warehouse,
    WarehouseInventory inventory,
    Crop crop,
  ) {
    return [
      const _SectionHeader(
        title: 'Review',
        subtitle: 'Confirm the stock record before saving it for sync.',
      ),
      const SizedBox(height: 10),
      _ReviewSummaryCard(
        action: action,
        warehouse: warehouse,
        inventory: inventory,
        recipientType: _recipientType,
        recipientName: _recipientName.text.trim(),
        recipientPhone: _recipientPhone.text.trim(),
        adjustmentType: _adjustmentType,
        reason: _reason,
      ),
      const SizedBox(height: 12),
      _ComputedTotals(
        crop: crop,
        bags: _bags.length,
        grossWeight: _totalGrossWeight,
        packagingWeight: _totalPackagingWeight,
        netWeight: _totalNetWeight,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _showBagsSheet,
        icon: const Icon(Icons.inventory_2_outlined),
        label: Text('Review ${_bags.length} bags'),
      ),
    ];
  }

  Widget _wizardActions({
    required _WarehouseAction action,
    required Warehouse warehouse,
    required WarehouseInventory inventory,
    required Crop crop,
  }) {
    if (_saving) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.workerColor),
      );
    }

    final isFirstStep = _step == _OperationStep.weighing;
    final isReviewStep = _step == _OperationStep.review;

    return Row(
      children: [
        if (!isFirstStep) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: isReviewStep
                ? () => _save(
                      action: action,
                      warehouse: warehouse,
                      inventory: inventory,
                      crop: crop,
                    )
                : () => _nextStep(action: action, inventory: inventory),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.workerColor,
            ),
            child: Text(isReviewStep ? 'Confirm save' : 'Continue'),
          ),
        ),
      ],
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

  void _nextStep({
    required _WarehouseAction action,
    required WarehouseInventory inventory,
  }) {
    switch (_step) {
      case _OperationStep.weighing:
        if (_bags.isEmpty) {
          _showError('Add at least one bag before continuing.');
          return;
        }
        final stockError = _validateStockOperation(
          action: action,
          inventory: inventory,
        );
        if (stockError != null) {
          _showError(stockError);
          return;
        }
        setState(() => _step = _OperationStep.details);
        return;
      case _OperationStep.details:
        if (!(_formKey.currentState?.validate() ?? false)) return;
        setState(() => _step = _OperationStep.review);
        return;
      case _OperationStep.review:
        return;
    }
  }

  void _previousStep() {
    setState(() {
      _step = switch (_step) {
        _OperationStep.weighing => _OperationStep.weighing,
        _OperationStep.details => _OperationStep.weighing,
        _OperationStep.review => _OperationStep.details,
      };
    });
  }

  String _detailsTitle(_WarehouseAction action) {
    return switch (action) {
      _WarehouseAction.dispatch => 'Dispatch details',
      _WarehouseAction.count => 'Stock count details',
      _WarehouseAction.adjustment => 'Adjustment details',
    };
  }

  String _detailsSubtitle(_WarehouseAction action) {
    return switch (action) {
      _WarehouseAction.dispatch =>
        'Add recipient information for this dispatch.',
      _WarehouseAction.count =>
        'The counted bag totals are ready. This will not change inventory.',
      _WarehouseAction.adjustment =>
        'Choose whether inventory should increase or decrease.',
    };
  }

  Future<void> _showScalePicker() async {
    final controller = ref.read(weightScaleControllerProvider.notifier);
    var devices = await controller.scanForScales();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var refreshing = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refresh() async {
              setSheetState(() => refreshing = true);
              final nextDevices = await controller.scanForScales();
              if (sheetContext.mounted) {
                setSheetState(() {
                  devices = nextDevices;
                  refreshing = false;
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Connect scale',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: refreshing ? null : refresh,
                          icon: refreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (devices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: EmptyState(
                          icon: Icons.bluetooth_disabled_rounded,
                          title: 'No scales found',
                          subtitle:
                              'Check Bluetooth and location, then refresh.',
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: devices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final result = devices[index];
                            return _ScaleDeviceTile(
                              result: result,
                              onConnect: () async {
                                await controller.connectToDevice(result.device);
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
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
      },
    );
  }

  double _moistureValue(Crop crop) =>
      _requiresMoisture(crop) ? double.tryParse(_moisture.text.trim()) ?? 0 : 0;

  double _nextPackagingWeight(Crop crop) {
    final cropWeight = crop.packagingWeight ?? 0;
    return cropWeight;
  }

  double get _totalGrossWeight =>
      _bags.fold<double>(0, (sum, bag) => sum + bag.grossWeight);

  double get _totalPackagingWeight =>
      _bags.fold<double>(0, (sum, bag) => sum + bag.packagingWeight);

  double get _totalNetWeight =>
      _bags.fold<double>(0, (sum, bag) => sum + bag.netWeight);

  double get _averageMoistureContent {
    if (_bags.isEmpty) return 0;
    final total = _bags.fold(0.0, (sum, bag) => sum + bag.moistureContent);
    return total / _bags.length;
  }

  String? _validateStockOperation({
    required _WarehouseAction action,
    required WarehouseInventory inventory,
  }) {
    final decreasesStock = action == _WarehouseAction.dispatch ||
        (action == _WarehouseAction.adjustment &&
            _adjustmentType == StockAdjustmentType.decrease);
    if (!decreasesStock) return null;

    if (inventory.totalBags <= 0) {
      return 'No stock available for this crop.';
    }
    if (_bags.length > inventory.totalBags) {
      return 'You cannot remove ${_bags.length} bags. Only ${inventory.totalBags} bags are available.';
    }
    if (_greaterThan(_totalGrossWeight, inventory.totalGrossWeight)) {
      return 'Gross weight cannot exceed available stock.';
    }
    if (_greaterThan(_totalPackagingWeight, inventory.totalPackagingWeight)) {
      return 'Packaging weight cannot exceed available stock.';
    }
    if (_greaterThan(_totalNetWeight, inventory.totalNetWeight)) {
      return 'Net weight cannot exceed available stock.';
    }

    final removesAllBags = _bags.length == inventory.totalBags;
    if (!removesAllBags) return null;

    if (!_nearlyEqual(_totalGrossWeight, inventory.totalGrossWeight) ||
        !_nearlyEqual(
          _totalPackagingWeight,
          inventory.totalPackagingWeight,
        ) ||
        !_nearlyEqual(_totalNetWeight, inventory.totalNetWeight)) {
      return action == _WarehouseAction.dispatch
          ? 'Dispatch uses full bags. If stock weight has changed, perform a stock adjustment first, then dispatch.'
          : 'Removing all bags must remove the full recorded stock for this crop.';
    }
    return null;
  }

  bool _canAddBag(WeightScaleState scaleState) {
    return scaleState.isConnected &&
        scaleState.isStreaming &&
        scaleState.isStable &&
        scaleState.weight > 0;
  }

  void _addBagFromScale(Crop crop, WeightScaleState scaleState) {
    if (!scaleState.isConnected || !scaleState.isStreaming) {
      _showError('Connect scale before adding a bag.');
      return;
    }
    if (!scaleState.isStable) {
      _showError('Wait for a stable scale reading.');
      return;
    }
    if (scaleState.weight <= 0) {
      _showError('Scale weight must be greater than zero.');
      return;
    }

    final added = _addBag(crop, scaleState.weight);
    if (added) {
      ref.read(weightScaleControllerProvider.notifier).requestCurrentWeight();
    }
  }

  bool _addBag(Crop crop, double grossWeight) {
    final moistureContent = _moistureValue(crop);
    final packagingWeight = _nextPackagingWeight(crop);

    if (grossWeight <= 0) {
      _showError('Enter a positive gross weight before adding a bag.');
      return false;
    }
    if (_requiresMoisture(crop) &&
        (moistureContent < 0 || moistureContent > 100)) {
      _showError('Enter moisture content from 0 to 100.');
      return false;
    }
    if (packagingWeight >= grossWeight) {
      _showError('Packaging weight must be less than gross weight.');
      return false;
    }

    setState(() {
      _bags.add(
        _OperationBag(
          grossWeight: grossWeight,
          packagingWeight: packagingWeight,
          netWeight: grossWeight - packagingWeight,
          moistureContent: moistureContent,
        ),
      );
      if (!_requiresMoisture(crop)) {
        _moisture.text = '0';
      }
    });
    return true;
  }

  void _removeBag(int index) {
    setState(() => _bags.removeAt(index));
  }

  void _showBagsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bags (${_bags.length})',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${_formatNumber(_totalNetWeight)} kg net',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_bags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No bags added',
                          subtitle:
                              'Add at least one weighed bag before saving.',
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.62,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _bags.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) => _OperationBagTile(
                            index: index,
                            bag: _bags[index],
                            onRemove: () {
                              _removeBag(index);
                              setSheetState(() {});
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save({
    required _WarehouseAction action,
    required Warehouse warehouse,
    required WarehouseInventory inventory,
    required Crop crop,
  }) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_bags.isEmpty) {
      _showError('Add at least one bag before saving.');
      return;
    }
    final stockError = _validateStockOperation(
      action: action,
      inventory: inventory,
    );
    if (stockError != null) {
      _showError(stockError);
      return;
    }

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
            totalBags: _bags.length,
            totalGrossWeight: _totalGrossWeight,
            totalPackagingWeight: _totalPackagingWeight,
            totalNetWeight: _totalNetWeight,
            moistureContent: _averageMoistureContent,
          );
        case _WarehouseAction.count:
          await repo.recordStockCount(
            warehouse: warehouse,
            crop: crop,
            countedBags: _bags.length,
            countedGrossWeight: _totalGrossWeight,
            countedPackagingWeight: _totalPackagingWeight,
            countedNetWeight: _totalNetWeight,
            moistureContent: _averageMoistureContent,
          );
        case _WarehouseAction.adjustment:
          await repo.recordStockAdjustment(
            warehouse: warehouse,
            crop: crop,
            adjustmentType: _adjustmentType,
            reason: _reason,
            bags: _bags.length,
            grossWeight: _totalGrossWeight,
            packagingWeight: _totalPackagingWeight,
            netWeight: _totalNetWeight,
            moistureContent: _averageMoistureContent,
          );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      await showSuccessDialog(
        context,
        title: 'Record saved',
        description: 'Saved locally and added to pending syncs.',
      );
      if (!mounted) return;
      context.pop();
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}

class _PackagingWeightSummary extends StatelessWidget {
  final double value;
  final String unit;

  const _PackagingWeightSummary({
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.workerColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.workerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.workerColor,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Packaging weight',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${_formatNumber(value)} $unit',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationBagTile extends StatelessWidget {
  final int index;
  final _OperationBag bag;
  final VoidCallback onRemove;

  const _OperationBagTile({
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
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.workerColor.withValues(alpha: 0.12),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.workerColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _SmallBagMetric(
                  label: 'Gross',
                  value: '${_formatNumber(bag.grossWeight)} kg',
                ),
                _SmallBagMetric(
                  label: 'Packaging',
                  value: '${_formatNumber(bag.packagingWeight)} kg',
                ),
                _SmallBagMetric(
                  label: 'Net',
                  value: '${_formatNumber(bag.netWeight)} kg',
                ),
                if (bag.moistureContent > 0)
                  _SmallBagMetric(
                    label: 'Moisture',
                    value: '${_formatNumber(bag.moistureContent)}%',
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
}

class _SmallBagMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SmallBagMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _OperationBag {
  final double grossWeight;
  final double packagingWeight;
  final double netWeight;
  final double moistureContent;

  const _OperationBag({
    required this.grossWeight,
    required this.packagingWeight,
    required this.netWeight,
    required this.moistureContent,
  });
}

class _ComputedTotals extends StatelessWidget {
  final Crop crop;
  final int bags;
  final double grossWeight;
  final double packagingWeight;
  final double netWeight;

  const _ComputedTotals({
    required this.crop,
    required this.bags,
    required this.grossWeight,
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
            value: '${_formatNumber(crop.packagingWeight ?? 0)} kg per bag',
          ),
          _TotalRow(
            label: 'Bags added',
            value: '$bags',
          ),
          _TotalRow(
            label: 'Total gross weight',
            value: '${_formatNumber(grossWeight)} kg',
          ),
          _TotalRow(
            label: 'Total packaging weight',
            value: '${_formatNumber(packagingWeight)} kg',
          ),
          _TotalRow(
            label: 'Total net weight',
            value: '${_formatNumber(netWeight)} kg',
          ),
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

String _deviceName(BluetoothDevice device) {
  final advertisedName = device.advName.trim();
  final platformName = device.platformName.trim();
  if (advertisedName.isNotEmpty) return advertisedName;
  if (platformName.isNotEmpty) return platformName;
  return 'Unknown scale';
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

const double _weightToleranceKg = 0.01;

bool _greaterThan(num value, num limit) {
  return value > limit + _weightToleranceKg;
}

bool _nearlyEqual(num left, num right) {
  return (left - right).abs() <= _weightToleranceKg;
}
