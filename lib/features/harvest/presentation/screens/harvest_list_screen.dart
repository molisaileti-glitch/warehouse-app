import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_receiving_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

class HarvestListScreen extends ConsumerWidget {
  final String warehouseId;

  const HarvestListScreen({super.key, required this.warehouseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final harvestsAsync = ref.watch(harvestsByWarehouseProvider(warehouseId));
    final harvests = harvestsAsync.valueOrNull ?? const <FarmerHarvest>[];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Harvest'),
        actions: [
          IconButton(
            tooltip: 'New harvest',
            onPressed: () {
              ref
                  .read(
                    harvestReceivingControllerProvider(warehouseId).notifier,
                  )
                  .reset();
              context.push(AppRoutes.workerConnectScaleFor(warehouseId));
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: harvestsAsync.hasError && harvests.isEmpty
          ? ErrorView(message: '${harvestsAsync.error}')
          : harvests.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No harvests yet',
                  subtitle: 'Tap + to connect a scale and receive crops.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  itemCount: harvests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _HarvestTile(
                    warehouseId: warehouseId,
                    harvest: harvests[index],
                  ),
                ),
    );
  }
}

class _HarvestTile extends StatelessWidget {
  final String warehouseId;
  final FarmerHarvest harvest;

  const _HarvestTile({
    required this.warehouseId,
    required this.harvest,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, HH:mm').format(harvest.receivedAt);

    return AppCard(
      onTap: () => context.push(
        AppRoutes.workerHarvestDetailFor(warehouseId, harvest.uuid),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.workerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.grass_outlined,
              color: AppColors.workerColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  harvest.farmerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${harvest.cropName} - ${harvest.netWeight.toStringAsFixed(1)} ${harvest.uomName ?? 'kg'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${harvest.receiptNumber} - $date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
