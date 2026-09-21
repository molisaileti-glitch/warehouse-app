import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/sync/sync_engine.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import 'package:warehouse_app/features/owner/widgets/owner_drawer.dart';

final _recentOwnerActivitiesProvider =
    StreamProvider.family<List<AuditLog>, String>((ref, userId) {
  return ref
      .watch(auditLogDaoProvider)
      .watchLogsByUser(userId)
      .map((logs) => logs.take(4).toList());
});

final _ownerPendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncQueueDaoProvider).watchPendingCount();
});

final _ownerHarvestCountProvider = StreamProvider<int>((ref) {
  return ref.watch(harvestDaoProvider).watchAllHarvests().map(
        (harvests) => harvests.length,
      );
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  Future<void> _refreshDashboard() async {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final warehousesAsync = ref.watch(currentOwnerWarehousesProvider);
    final workersAsync = ref.watch(allWorkersProvider);
    final farmersAsync = ref.watch(allFarmersProvider);
    final activitiesAsync = userId != null
        ? ref.watch(_recentOwnerActivitiesProvider(userId))
        : const AsyncValue<List<AuditLog>>.data([]);
    final pendingSyncCount =
        ref.watch(_ownerPendingSyncCountProvider).valueOrNull ?? 0;
    final harvestCount = ref.watch(_ownerHarvestCountProvider).valueOrNull ?? 0;
    final syncState = ref.watch(syncNotifierProvider);
    final l10n = AppLocalizations.of(context)!;

    final warehouses = warehousesAsync.valueOrNull ?? const <Warehouse>[];
    final workers = workersAsync.valueOrNull ?? const <User>[];
    final farmers = farmersAsync.valueOrNull ?? const <Farmer>[];
    final inventoryItems = <WarehouseInventory>[];
    for (final warehouse in warehouses) {
      inventoryItems.addAll(
        ref.watch(warehouseInventoryProvider(warehouse.id)).valueOrNull ??
            const <WarehouseInventory>[],
      );
    }
    final stockOverviewItems = _stockOverviewItems(inventoryItems);

    return Scaffold(
      backgroundColor: AppColors.surface,
      drawer: const OwnerDrawer(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: l10n.notifications,
            onPressed: pendingSyncCount == 0
                ? null
                : () => context.go(AppRoutes.ownerPendingSyncs),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'owner_dashboard_sync',
            onPressed: syncState.isSyncing
                ? null
                : () => runSyncWithProgressDialog(context, ref),
            icon: syncState.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(syncState.isSyncing ? l10n.syncing : l10n.sync),
            backgroundColor: AppColors.ownerColor,
            foregroundColor: Colors.white,
          ),
          if (pendingSyncCount > 0) ...[
            const SizedBox(height: 8),
            PendingSyncFloatingBanner(
              count: pendingSyncCount,
              onTap: () => context.go(AppRoutes.ownerPendingSyncs),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (syncState.isSyncing || syncState.hasErrors)
              SliverToBoxAdapter(child: _SyncBanner(state: syncState)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ownerOverview,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _OverviewPanel(
                      items: stockOverviewItems,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 150,
                ),
                delegate: SliverChildListDelegate([
                  _DashboardStatCard(
                    label: l10n.warehouses,
                    value: '${warehouses.length}',
                    subtitle: l10n.activeCount(
                      warehouses.where((w) => w.isActive).length,
                    ),
                    icon: Icons.warehouse_rounded,
                    color: AppColors.ownerColor,
                    onTap: () => context.go(AppRoutes.ownerWarehouses),
                  ),
                  _DashboardStatCard(
                    label: l10n.workers,
                    value: '${workers.length}',
                    subtitle: l10n.activeCount(
                      workers.where((w) => w.isActive).length,
                    ),
                    icon: Icons.groups_rounded,
                    color: AppColors.workerColor,
                    onTap: () => context.go(AppRoutes.ownerUsers),
                  ),
                  _DashboardStatCard(
                    label: l10n.farmers,
                    value: '${farmers.length}',
                    subtitle: l10n.registeredFarmers,
                    icon: Icons.agriculture_rounded,
                    color: AppColors.success,
                  ),
                  _DashboardStatCard(
                    label: l10n.harvest,
                    value: '$harvestCount',
                    subtitle: l10n.records,
                    icon: Icons.grass_rounded,
                    color: AppColors.info,
                    onTap: () => context.go(AppRoutes.ownerHarvests),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.recentActivity,
                actionLabel: l10n.seeAll,
                onAction: () => context.go(AppRoutes.ownerAuditLog),
              ),
            ),
            activitiesAsync.when(
              data: (logs) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: logs.isEmpty
                      ? _EmptyDashboardCard(
                          icon: Icons.history_rounded,
                          title: l10n.noOwnerActivity,
                          subtitle: l10n.createWarehouseWorkerActivity,
                        )
                      : _RecentActivityList(logs: logs),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: LoadingView()),
              error: (error, _) =>
                  SliverToBoxAdapter(child: ErrorView(message: '$error')),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ],
        ),
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  final List<_StockOverviewItem> items;

  const _OverviewPanel({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleItems = items.take(3).toList();
    final moreCount = items.length - visibleItems.length;
    final totalStock = items.fold<double>(
      0,
      (sum, item) => sum + item.netWeight,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.ownerColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.stockOverview.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_formatStockWeight(totalStock)} kg',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.totalStock,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          if (visibleItems.isEmpty)
            Text(
              l10n.noStockAvailable,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            )
          else ...[
            for (final item in visibleItems) _StockOverviewRow(item: item),
            if (moreCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                l10n.moreCrops(moreCount),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StockOverviewRow extends StatelessWidget {
  final _StockOverviewItem item;

  const _StockOverviewRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            _cropIcon(item.cropName),
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.cropName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_formatStockWeight(item.netWeight)} kg',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockOverviewItem {
  final String cropName;
  final double netWeight;

  const _StockOverviewItem({
    required this.cropName,
    required this.netWeight,
  });
}

List<_StockOverviewItem> _stockOverviewItems(
  Iterable<WarehouseInventory> inventoryItems,
) {
  final totals = <String, double>{};
  for (final item in inventoryItems) {
    if (!_hasVisibleStock(item)) continue;
    totals.update(
      item.cropName,
      (value) => value + item.totalNetWeight,
      ifAbsent: () => item.totalNetWeight,
    );
  }

  final items = totals.entries
      .map(
        (entry) => _StockOverviewItem(
          cropName: entry.key,
          netWeight: entry.value,
        ),
      )
      .toList()
    ..sort((a, b) => b.netWeight.compareTo(a.netWeight));
  return items;
}

bool _hasVisibleStock(WarehouseInventory item) {
  return item.totalBags > 0 &&
      (item.totalGrossWeight > 0 ||
          item.totalPackagingWeight > 0 ||
          item.totalNetWeight > 0);
}

String _formatStockWeight(num value) {
  return NumberFormat('#,##0.##').format(value);
}

IconData _cropIcon(String cropName) {
  final normalized = cropName.toLowerCase();
  if (normalized.contains('maize') || normalized.contains('corn')) {
    return Icons.agriculture_rounded;
  }
  if (normalized.contains('rice')) return Icons.grass_rounded;
  if (normalized.contains('potato')) return Icons.eco_rounded;
  return Icons.inventory_2_rounded;
}

class _DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FittedBox(
              alignment: Alignment.bottomLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Flexible(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<AuditLog> logs;

  const _RecentActivityList({required this.logs});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++) ...[
            _ActivityTile(log: logs[i]),
            if (i != logs.length - 1)
              const Divider(height: 1, indent: 72, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final AuditLog log;

  const _ActivityTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = _activityDetails(log, l10n);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: details.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(details.icon, color: details.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${details.subtitle} - ${_relativeTime(log.createdAt, l10n)}',
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyDashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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

class _SyncBanner extends StatelessWidget {
  final SyncState state;
  const _SyncBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (state.isSyncing) {
      return Container(
        color: AppColors.info.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.syncing,
            style: const TextStyle(color: AppColors.info, fontSize: 13),
          ),
        ]),
      );
    }
    if (state.error != null) {
      return Container(
        color: AppColors.error.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.warning_rounded, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ]),
      );
    }
    if (state.isDone) {
      return Container(
        color: AppColors.success.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(
            Icons.cloud_done_rounded,
            color: AppColors.success,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.syncedSummary(
                state.pushed.toString(), state.pulled.toString()),
            style: const TextStyle(color: AppColors.success, fontSize: 13),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}

_ActivityDetails _activityDetails(AuditLog log, AppLocalizations l10n) {
  final metadata = _metadata(log.metadata);
  final name = _stringValue(metadata, 'name');

  return switch (log.action) {
    'warehouse.create' => _ActivityDetails(
        title: l10n.warehouseCreatedActivity,
        subtitle: name ?? l10n.warehouseRecord,
        icon: Icons.warehouse_rounded,
        color: AppColors.ownerColor,
      ),
    'warehouse.update' => _ActivityDetails(
        title: l10n.warehouseUpdatedActivity,
        subtitle: name ?? l10n.warehouseRecord,
        icon: Icons.edit_rounded,
        color: AppColors.info,
      ),
    'worker.create' => _ActivityDetails(
        title: l10n.workerCreatedActivity,
        subtitle: name ?? l10n.workerAccount,
        icon: Icons.person_add_alt_1_rounded,
        color: AppColors.workerColor,
      ),
    _ => _ActivityDetails(
        title: _titleFromAction(log.action),
        subtitle: name ?? l10n.ownerActivity,
        icon: Icons.history_rounded,
        color: AppColors.textSecondary,
      ),
  };
}

Map<String, dynamic> _metadata(String? value) {
  if (value == null || value.trim().isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

String? _stringValue(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _titleFromAction(String action) {
  return action
      .split('.')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _relativeTime(DateTime time, AppLocalizations l10n) {
  final difference = DateTime.now().difference(time);
  if (difference.inMinutes < 1) return l10n.justNow;
  if (difference.inMinutes < 60) {
    return l10n.minutesAgo(difference.inMinutes);
  }
  if (difference.inHours < 24) return l10n.hoursAgo(difference.inHours);
  if (difference.inDays == 1) return l10n.yesterday;
  return DateFormat('MMM d', l10n.localeName).format(time);
}

class _ActivityDetails {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ActivityDetails({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
