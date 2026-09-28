import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_receiving_controller.dart';
import 'package:warehouse_app/features/harvest/presentation/widgets/harvest_print_button.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class HarvestReceiptScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  final bool ownerFlow;

  const HarvestReceiptScreen({
    super.key,
    required this.warehouseId,
    required this.ownerFlow,
  });

  @override
  ConsumerState<HarvestReceiptScreen> createState() =>
      _HarvestReceiptScreenState();
}

class _HarvestReceiptScreenState extends ConsumerState<HarvestReceiptScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(
      harvestReceivingControllerProvider(widget.warehouseId),
    );
    final harvest = session.savedHarvest;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(l10n.receiptTitle),
        automaticallyImplyLeading: false,
      ),
      body: harvest == null
          ? _missingReceipt(context, l10n)
          : _receipt(context, l10n, harvest, session.savedBagCount),
    );
  }

  Widget _missingReceipt(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.noReceiptYet,
        subtitle: l10n.completeReceivingBeforeReceipt,
        actionLabel: l10n.startReceiving,
        onAction: () => context.go(
          widget.ownerFlow
              ? AppRoutes.ownerConnectScaleFor(widget.warehouseId)
              : AppRoutes.workerConnectScaleFor(widget.warehouseId),
        ),
      ),
    );
  }

  Widget _receipt(
    BuildContext context,
    AppLocalizations l10n,
    FarmerHarvest harvest,
    int bagCount,
  ) {
    final date = DateFormat('MMM d, yyyy HH:mm', l10n.localeName)
        .format(harvest.receivedAt);
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
                          Text(
                            l10n.warehouseReceipt,
                            style: const TextStyle(
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
                  ],
                ),
                const Divider(height: 28),
                _receiptRow(l10n.receiptFarmer, harvest.farmerName),
                _receiptRow(l10n.receiptCrop, harvest.cropName),
                _receiptRow(
                    l10n.receiptWarehouse, harvest.collectionCenterName),
                _receiptRow(l10n.receiptBags, '$bagCount'),
                _receiptRow(
                  l10n.receiptGross,
                  '${_formatWeight(harvest.grossWeight)} $uom',
                ),
                _receiptRow(
                  l10n.receiptTare,
                  '${_formatWeight(harvest.packagingWeight)} $uom',
                ),
                _receiptRow(
                  l10n.receiptMoisturePercent,
                  '${_formatWeight(harvest.moistureContent)}%',
                ),
                _receiptRow(
                  l10n.receiptNet,
                  '${_formatWeight(harvest.netWeight)} $uom',
                  bold: true,
                ),
                _receiptRow(l10n.receiptDate, date),
                if (harvest.receivedByName != null)
                  _receiptRow(l10n.receiptReceivedBy, harvest.receivedByName!),
              ],
            ),
          ),
          const SizedBox(height: 18),
          HarvestPrintButton(
            harvest: harvest,
            filled: true,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              ref
                  .read(harvestReceivingControllerProvider(
                    widget.warehouseId,
                  ).notifier)
                  .reset();
              context.go(
                widget.ownerFlow
                    ? AppRoutes.ownerConnectScaleFor(widget.warehouseId)
                    : AppRoutes.workerConnectScaleFor(widget.warehouseId),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.workerColor,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.newReceiving),
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
            width: 120,
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
