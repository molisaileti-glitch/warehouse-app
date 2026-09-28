import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_providers.dart';
import 'package:warehouse_app/features/harvest/presentation/widgets/harvest_print_button.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class RecentHarvestReceipts extends ConsumerWidget {
  final String warehouseId;
  final bool ownerFlow;
  final int limit;

  const RecentHarvestReceipts({
    super.key,
    required this.warehouseId,
    required this.ownerFlow,
    this.limit = 3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final harvestsAsync = ref.watch(harvestsByWarehouseProvider(warehouseId));
    final harvests = harvestsAsync.valueOrNull ?? const <FarmerHarvest>[];
    final recent = harvests.take(limit).toList();

    if (harvestsAsync.isLoading && harvests.isEmpty) {
      return const SizedBox.shrink();
    }
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.recentReceipts,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(
                ownerFlow
                    ? AppRoutes.ownerHarvests
                    : AppRoutes.workerHarvestsFor(warehouseId),
              ),
              child: Text(l10n.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recent.map(
          (harvest) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecentReceiptTile(
              harvest: harvest,
              warehouseId: warehouseId,
              ownerFlow: ownerFlow,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentReceiptTile extends StatelessWidget {
  final FarmerHarvest harvest;
  final String warehouseId;
  final bool ownerFlow;

  const _RecentReceiptTile({
    required this.harvest,
    required this.warehouseId,
    required this.ownerFlow,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date =
        DateFormat('MMM d, HH:mm', l10n.localeName).format(harvest.receivedAt);

    return AppCard(
      onTap: () => context.push(
        ownerFlow
            ? AppRoutes.ownerHarvestDetailFor(harvest.uuid)
            : AppRoutes.workerHarvestDetailFor(warehouseId, harvest.uuid),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.ownerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.ownerColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  harvest.receiptNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${harvest.cropName} - ${harvest.farmerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HarvestPrintButton(
            harvest: harvest,
            label: l10n.printReceipt,
            compact: true,
          ),
        ],
      ),
    );
  }
}
