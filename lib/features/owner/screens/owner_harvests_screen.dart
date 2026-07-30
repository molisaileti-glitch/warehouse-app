import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/warehouse/presentation/providers/warehouse_providers.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

final _ownerHarvestsProvider = StreamProvider<List<FarmerHarvest>>((ref) {
  return ref.watch(harvestDaoProvider).watchAllHarvests();
});

class OwnerHarvestsScreen extends ConsumerStatefulWidget {
  const OwnerHarvestsScreen({super.key});

  @override
  ConsumerState<OwnerHarvestsScreen> createState() =>
      _OwnerHarvestsScreenState();
}

class _OwnerHarvestsScreenState extends ConsumerState<OwnerHarvestsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final harvestsAsync = ref.watch(_ownerHarvestsProvider);
    final ownerId = ref.watch(currentUserIdProvider);
    final warehousesAsync = ownerId == null
        ? const AsyncValue<List<Warehouse>>.data([])
        : ref.watch(warehousesByOwnerProvider(ownerId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harvests',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    harvestsAsync.maybeWhen(
                      data: (harvests) => Text(
                        '${harvests.length} records total',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      orElse: () => const Text(
                        'Harvest records',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search harvests...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            harvestsAsync.when(
              data: (harvests) {
                final filtered = _query.isEmpty
                    ? harvests
                    : harvests.where((harvest) {
                        final text = [
                          harvest.farmerName,
                          harvest.cropName,
                          harvest.collectionCenterName,
                          harvest.receiptNumber,
                        ].join(' ').toLowerCase();
                        return text.contains(_query);
                      }).toList();

                if (filtered.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No harvests found',
                      subtitle: 'Worker harvest records will appear here.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, index) {
                        if (index.isOdd) return const SizedBox(height: 10);
                        return _HarvestTile(harvest: filtered[index ~/ 2]);
                      },
                      childCount: filtered.length * 2 - 1,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(child: LoadingView()),
              error: (error, _) =>
                  SliverFillRemaining(child: ErrorView(message: '$error')),
            ),
          ],
        ),
      ),
      floatingActionButton: warehousesAsync.maybeWhen(
        data: (warehouses) => FloatingActionButton.extended(
          heroTag: 'owner_harvest_receive_fab',
          backgroundColor: AppColors.ownerColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Receive Crop'),
          onPressed: () => _startHarvestReceiving(warehouses),
        ),
        orElse: () => FloatingActionButton.extended(
          heroTag: 'owner_harvest_receive_loading_fab',
          backgroundColor: AppColors.ownerColor.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Loading'),
          onPressed: null,
        ),
      ),
    );
  }

  Future<void> _startHarvestReceiving(List<Warehouse> warehouses) async {
    final activeWarehouses = warehouses.where((item) => item.isActive).toList();
    if (activeWarehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an active warehouse before receiving crops.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (activeWarehouses.length == 1) {
      await context.push(
        AppRoutes.ownerHarvestRecordFor(activeWarehouses.first.id),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Warehouse',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select where this crop receiving session will be recorded.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeWarehouses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final warehouse = activeWarehouses[index];
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(
                            Icons.warehouse_rounded,
                            color: AppColors.ownerColor,
                          ),
                          title: Text(
                            warehouse.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            [
                              warehouse.amcosName,
                              warehouse.villageName,
                            ]
                                .whereType<String>()
                                .where((value) => value.trim().isNotEmpty)
                                .join(' - '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            context.push(
                              AppRoutes.ownerHarvestRecordFor(warehouse.id),
                            );
                          },
                        ),
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
  }
}

class _HarvestTile extends StatelessWidget {
  final FarmerHarvest harvest;

  const _HarvestTile({required this.harvest});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, HH:mm').format(harvest.receivedAt);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.ownerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppColors.ownerColor,
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
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${harvest.cropName} - ${harvest.netWeight.toStringAsFixed(1)} ${harvest.uomName ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
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
          SyncStatusBadge(status: harvest.syncStatus),
        ],
      ),
    );
  }
}
