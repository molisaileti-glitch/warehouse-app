import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_receiving_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

class HarvestReceiptScreen extends ConsumerWidget {
  final String warehouseId;
  final bool ownerFlow;

  const HarvestReceiptScreen({
    super.key,
    required this.warehouseId,
    required this.ownerFlow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(harvestReceivingControllerProvider(warehouseId));
    final harvest = session.savedHarvest;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Receipt'),
        automaticallyImplyLeading: false,
      ),
      body: harvest == null
          ? _missingReceipt(context)
          : _receipt(context, ref, harvest, session.savedBagCount),
    );
  }

  Widget _missingReceipt(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No receipt yet',
        subtitle: 'Complete a receiving session before viewing the receipt.',
        actionLabel: 'Start Receiving',
        onAction: () => context.go(
          ownerFlow
              ? AppRoutes.ownerConnectScaleFor(warehouseId)
              : AppRoutes.workerConnectScaleFor(warehouseId),
        ),
      ),
    );
  }

  Widget _receipt(
    BuildContext context,
    WidgetRef ref,
    FarmerHarvest harvest,
    int bagCount,
  ) {
    final date = DateFormat('MMM d, yyyy HH:mm').format(harvest.receivedAt);
    final uom = harvest.uomName ?? 'kg';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepHeader(),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Warehouse Receipt',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            harvest.receiptNumber,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SyncStatusBadge(status: harvest.syncStatus),
                  ],
                ),
                const Divider(height: 28),
                _receiptRow('Farmer', harvest.farmerName),
                _receiptRow('Crop', harvest.cropName),
                if (harvest.cropGradeName != null)
                  _receiptRow('Grade', harvest.cropGradeName!),
                _receiptRow('Warehouse', harvest.collectionCenterName),
                _receiptRow('Bags', '$bagCount'),
                _receiptRow(
                  'Gross',
                  '${_formatWeight(harvest.grossWeight)} $uom',
                ),
                _receiptRow(
                  'Tare',
                  '${_formatWeight(harvest.packagingWeight)} $uom',
                ),
                _receiptRow(
                  'Net',
                  '${_formatWeight(harvest.netWeight)} $uom',
                  bold: true,
                ),
                _receiptRow('Date', date),
                if (harvest.receivedByName != null)
                  _receiptRow('Received by', harvest.receivedByName!),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              ref
                  .read(
                      harvestReceivingControllerProvider(warehouseId).notifier)
                  .reset();
              context.go(
                ownerFlow
                    ? AppRoutes.ownerConnectScaleFor(warehouseId)
                    : AppRoutes.workerConnectScaleFor(warehouseId),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ownerColor,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Receiving'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              ref
                  .read(
                      harvestReceivingControllerProvider(warehouseId).notifier)
                  .reset();
              context.go(ownerFlow
                  ? AppRoutes.ownerHarvests
                  : AppRoutes.workerHarvestsFor(warehouseId));
            },
            icon: const Icon(Icons.done_rounded),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _stepHeader() {
    return AppCard(
      child: Row(
        children: [
          _stepBubble('1'),
          _stepLine(),
          _stepBubble('2'),
          _stepLine(),
          _stepBubble('3'),
        ],
      ),
    );
  }

  Widget _stepBubble(String label) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.ownerColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _stepLine() {
    return const Expanded(
      child: Divider(
        thickness: 2,
        color: AppColors.ownerColor,
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
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
