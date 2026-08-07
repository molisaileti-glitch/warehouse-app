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

final _recentOwnerActivitiesProvider =
    StreamProvider.family<List<AuditLog>, String>((ref, userId) {
  return ref
      .watch(auditLogDaoProvider)
      .watchLogsByUser(userId)
      .map((logs) => logs.take(4).toList());
});

final _ownerPendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncQueueDaoProvider).watchPendingEntries().map(
        (entries) => entries
            .where((entry) =>
                entry.entityType == 'warehouses' || entry.entityType == 'users')
            .length,
      );
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
    final warehousesAsync = userId != null
        ? ref.watch(warehousesByOwnerProvider(userId))
        : const AsyncValue<List<Warehouse>>.data([]);
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

    ref.listen<SyncState>(syncNotifierProvider, (previous, next) {
      if (previous?.isSyncing == true && next.isDone) {
        _showTopToast(
          context,
          l10n.syncedSummary(next.pushed.toString(), next.pulled.toString()),
          AppColors.success,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: pendingSyncCount == 0
                ? null
                : () => context.go(AppRoutes.ownerPendingSyncs),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => context.go(AppRoutes.ownerSettings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: syncState.isSyncing
            ? null
            : () => ref.read(syncNotifierProvider.notifier).runSync(),
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
        label: Text(syncState.isSyncing ? l10n.syncing : 'Sync'),
        backgroundColor: AppColors.ownerColor,
        foregroundColor: Colors.white,
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
                      _greetingFor(DateTime.now()),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.ownerOverview,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _OverviewPanel(
                      warehouses: warehouses.length,
                      workers: workers.length,
                      farmers: farmers.length,
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
                    label: 'Warehouses',
                    value: '${warehouses.length}',
                    subtitle:
                        '${warehouses.where((w) => w.isActive).length} active',
                    icon: Icons.warehouse_rounded,
                    color: AppColors.ownerColor,
                    onTap: () => context.go(AppRoutes.ownerWarehouses),
                  ),
                  _DashboardStatCard(
                    label: 'Workers',
                    value: '${workers.length}',
                    subtitle:
                        '${workers.where((w) => w.isActive).length} active',
                    icon: Icons.groups_rounded,
                    color: AppColors.workerColor,
                    onTap: () => context.go(AppRoutes.ownerUsers),
                  ),
                  _DashboardStatCard(
                    label: 'Farmers',
                    value: '${farmers.length}',
                    subtitle: 'Registered farmers',
                    icon: Icons.agriculture_rounded,
                    color: AppColors.success,
                  ),
                  _DashboardStatCard(
                    label: 'Harvest',
                    value: '$harvestCount',
                    subtitle: 'Records',
                    icon: Icons.grass_rounded,
                    color: AppColors.info,
                    onTap: () => context.go(AppRoutes.ownerHarvests),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Recent Activity',
                actionLabel: 'See all',
                onAction: () => context.go(AppRoutes.ownerAuditLog),
              ),
            ),
            activitiesAsync.when(
              data: (logs) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: logs.isEmpty
                      ? const _EmptyDashboardCard(
                          icon: Icons.history_rounded,
                          title: 'No owner activity yet',
                          subtitle:
                              'Create a warehouse or worker to see activity here.',
                        )
                      : _RecentActivityList(logs: logs),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: LoadingView()),
              error: (error, _) =>
                  SliverToBoxAdapter(child: ErrorView(message: '$error')),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Alerts'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
              sliver: SliverToBoxAdapter(
                child: pendingSyncCount == 0
                    ? const _EmptyDashboardCard(
                        icon: Icons.cloud_done_rounded,
                        title: 'No pending syncs',
                        subtitle: 'All local owner changes are uploaded.',
                      )
                    : _PendingSyncAlert(count: pendingSyncCount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  final int warehouses;
  final int workers;
  final int farmers;

  const _OverviewPanel({
    required this.warehouses,
    required this.workers,
    required this.farmers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.ownerColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Owner operations',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$warehouses warehouses',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$workers workers - $farmers farmers',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}

String _greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

void _showTopToast(BuildContext context, String message, Color color) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 14,
      left: 36,
      right: 36,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), entry.remove);
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
    final details = _activityDetails(log);

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
                  '${details.subtitle} - ${_relativeTime(log.createdAt)}',
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

class _PendingSyncAlert extends StatelessWidget {
  final int count;

  const _PendingSyncAlert({required this.count});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(AppRoutes.ownerPendingSyncs),
      color: AppColors.warning.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count pending sync${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Local warehouse or worker changes need manual sync.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.warning),
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

_ActivityDetails _activityDetails(AuditLog log) {
  final metadata = _metadata(log.metadata);
  final name = _stringValue(metadata, 'name');

  return switch (log.action) {
    'warehouse.create' => _ActivityDetails(
        title: 'Warehouse created',
        subtitle: name ?? 'Warehouse record',
        icon: Icons.warehouse_rounded,
        color: AppColors.ownerColor,
      ),
    'warehouse.update' => _ActivityDetails(
        title: 'Warehouse updated',
        subtitle: name ?? 'Warehouse record',
        icon: Icons.edit_rounded,
        color: AppColors.info,
      ),
    'worker.create' => _ActivityDetails(
        title: 'Worker created',
        subtitle: name ?? 'Worker account',
        icon: Icons.person_add_alt_1_rounded,
        color: AppColors.workerColor,
      ),
    _ => _ActivityDetails(
        title: _titleFromAction(log.action),
        subtitle: name ?? 'Owner activity',
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

String _relativeTime(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays == 1) return 'Yesterday';
  return DateFormat('MMM d').format(time);
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
