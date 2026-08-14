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
import 'package:warehouse_app/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final harvestsAsync = ref.watch(_ownerHarvestsProvider);
    final ownerId = ref.watch(currentUserIdProvider);
    final warehousesAsync = ownerId == null
        ? const AsyncValue<List<Warehouse>>.data([])
        : ref.watch(warehousesByOwnerProvider(ownerId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(l10n.harvests),
        actions: [
          warehousesAsync.maybeWhen(
            loading: () => const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            orElse: () => IconButton(
              tooltip: l10n.receiveCrop,
              onPressed: () =>
                  _startHarvestReceiving(warehousesAsync.valueOrNull ?? []),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.searchHarvests,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 14),
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
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.noHarvestsFound,
                      subtitle: l10n.workerHarvestsSubtitle,
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
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
    );
  }

  Future<void> _startHarvestReceiving(List<Warehouse> warehouses) async {
    final l10n = AppLocalizations.of(context)!;
    final activeWarehouses = warehouses.where((item) => item.isActive).toList();
    if (activeWarehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createWarehouseBeforeReceiving),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (activeWarehouses.length == 1) {
      await context.push(
        AppRoutes.ownerConnectScaleFor(activeWarehouses.first.id),
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
                Text(
                  l10n.chooseWarehouse,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.chooseWarehouseMessage,
                  style: const TextStyle(color: AppColors.textSecondary),
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
                              AppRoutes.ownerConnectScaleFor(warehouse.id),
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
    final l10n = AppLocalizations.of(context)!;
    final date =
        DateFormat('MMM d, HH:mm', l10n.localeName).format(harvest.receivedAt);

    return AppCard(
      onTap: () => context.push(AppRoutes.ownerHarvestDetailFor(harvest.uuid)),
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
