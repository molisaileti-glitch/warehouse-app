// lib/features/worker/presentation/screens/worker_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

// Scoped provider — watches the current worker's User record from local DB.
final _workerProfileProvider = StreamProvider<User?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(workerRepoProvider).watchWorkerById(userId);
});

final _workerPendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncQueueDaoProvider).watchPendingEntries().map(
        (entries) => entries
            .where((entry) =>
                entry.entityType == 'farmers' ||
                entry.entityType == 'farmerDependants' ||
                entry.entityType == 'farmerHarvests')
            .length,
      );
});

final _workerWarehousesByAmcosProvider =
    FutureProvider.family<List<Warehouse>, int>((ref, amcosId) async {
  await ref.read(warehouseRepoProvider).pullFromAmcos(amcosId: amcosId);
  return ref.read(warehouseDaoProvider).getWarehousesByAmcos(amcosId);
});

class WorkerDashboardScreen extends ConsumerWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_workerProfileProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final pendingSyncCount =
        ref.watch(_workerPendingSyncCountProvider).valueOrNull ?? 0;
    final l10n = AppLocalizations.of(context)!;

    ref.listen<SyncState>(syncNotifierProvider, (previous, next) {
      if (previous?.isSyncing != true) return;
      if (next.isDone) {
        showTopToast(
          context,
          l10n.syncedSummary(next.pushed.toString(), next.pulled.toString()),
          AppColors.success,
        );
      } else if (next.hasErrors) {
        showTopToast(
          context,
          next.error!,
          AppColors.error,
          icon: Icons.error_outline_rounded,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myTasks),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final ok = await showConfirmDialog(context,
                  title: l10n.signOutConfirmTitle,
                  message: l10n.signOutConfirmMessageWorker,
                  confirmLabel: l10n.signOut,
                  isDestructive: true);
              if (ok) ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'worker_dashboard_sync',
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
            label: Text(syncState.isSyncing ? l10n.syncing : l10n.sync),
            backgroundColor: AppColors.workerColor,
            foregroundColor: Colors.white,
          ),
          if (pendingSyncCount > 0) ...[
            const SizedBox(height: 8),
            PendingSyncFloatingBanner(
              count: pendingSyncCount,
              onTap: () => context.go(AppRoutes.workerPendingSyncs),
            ),
          ],
        ],
      ),
      body: userAsync.when(
        data: (user) => _WorkerBody(user: user),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
      ),
    );
  }
}

// ── Body — separated so widget tree is clean ──────────────────────────────────

class _WorkerBody extends ConsumerWidget {
  final User? user;
  const _WorkerBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // ── Mock / no profile in local DB yet ────────────────────────────────────
    // During development the mock user doesn't exist in Drift, so user is null.
    // Show a usable demo state instead of a spinner.
    // Once the real backend syncs the user record down, this branch never runs.
    if (user == null) {
      return _NoProfileView(
        onLogout: () => ref.read(authProvider.notifier).logout(),
      );
    }

    // ── Real user but no warehouse assigned yet ───────────────────────────────
    final warehouseId = user!.warehouseId;
    if (warehouseId == null) {
      return _WorkerWarehouseSelector(
        user: user!,
        autoSelectSingleWarehouse: true,
      );
    }

    // ── Normal state — warehouse assigned ─────────────────────────────────────
    final farmersAsync = ref.watch(allFarmersProvider);
    final harvestsAsync = ref.watch(harvestsByWarehouseProvider(warehouseId));
    final whAsync = ref.watch(warehouseByIdProvider(warehouseId));

    return CustomScrollView(
      slivers: [
        // Warehouse banner
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.workerColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Icons.warehouse_rounded,
                  color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.assignedWarehouse,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                    Text(whAsync.valueOrNull?.name ?? '…',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    if (whAsync.valueOrNull?.gpsLocation != null)
                      Text(whAsync.valueOrNull!.gpsLocation!,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.selectWarehouse,
                onPressed: () => _showWarehousePicker(context, user!),
                icon: const Icon(Icons.swap_horiz_rounded),
                color: Colors.white,
              ),
            ]),
          ),
        ),

        // Stats
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              StatCard(
                label: l10n.farmers,
                value: '${farmersAsync.valueOrNull?.length ?? 0}',
                icon: Icons.people_alt_rounded,
                color: AppColors.workerColor,
                onTap: () => context.go(AppRoutes.workerFarmers),
              ),
              StatCard(
                label: l10n.harvest,
                value: '${harvestsAsync.valueOrNull?.length ?? 0}',
                icon: Icons.grass_rounded,
                color: AppColors.success,
                onTap: () =>
                    context.go(AppRoutes.workerHarvestsFor(warehouseId)),
              ),
            ],
          ),
        ),

        // Quick actions
        SliverToBoxAdapter(child: SectionHeader(title: l10n.recordAction)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: l10n.registerFarmerAction,
                subtitle: l10n.createFarmerAtContact,
                color: AppColors.workerColor,
                onTap: () => context.go(AppRoutes.workerFarmerRegistration),
              ),
              _ActionButton(
                icon: Icons.arrow_downward_rounded,
                label: l10n.recordDelivery,
                subtitle: l10n.incomingGoodsSubtitle,
                color: AppColors.success,
                onTap: () => context.go(AppRoutes.workerRecordFor(warehouseId)),
              ),
              _ActionButton(
                icon: Icons.checklist_rounded,
                label: l10n.stockCount,
                subtitle: l10n.countItemsSubtitle,
                color: AppColors.info,
                onTap: () => context.go(AppRoutes.workerRecordFor(warehouseId)),
              ),
              _ActionButton(
                icon: Icons.tune_rounded,
                label: l10n.adjustment,
                subtitle: l10n.correctDiscrepanciesSubtitle,
                color: AppColors.workerColor,
                onTap: () => context.go(AppRoutes.workerRecordFor(warehouseId)),
              ),
            ]),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 150)),
      ],
    );
  }
}

// ── No profile view — shown during mock/dev when user isn't in local DB ───────

void _showWarehousePicker(BuildContext context, User user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WorkerWarehouseSheet(user: user),
  );
}

class _WorkerWarehouseSheet extends StatelessWidget {
  final User user;
  const _WorkerWarehouseSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.selectWarehouse,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.58,
              ),
              child: _WorkerWarehouseSelector(
                user: user,
                popOnSelect: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerWarehouseSelector extends ConsumerStatefulWidget {
  final User user;
  final bool autoSelectSingleWarehouse;
  final bool popOnSelect;

  const _WorkerWarehouseSelector({
    required this.user,
    this.autoSelectSingleWarehouse = false,
    this.popOnSelect = false,
  });

  @override
  ConsumerState<_WorkerWarehouseSelector> createState() =>
      _WorkerWarehouseSelectorState();
}

class _WorkerWarehouseSelectorState
    extends ConsumerState<_WorkerWarehouseSelector> {
  bool _autoSelected = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final amcosId = widget.user.amcos;

    if (amcosId == null || amcosId <= 0) {
      return EmptyState(
        icon: Icons.warehouse_rounded,
        title: l10n.notAssignedWarehouse,
        subtitle: l10n.askAdminAssignment,
      );
    }

    final warehousesAsync =
        ref.watch(_workerWarehousesByAmcosProvider(amcosId));
    return warehousesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => _WarehousePickerMessage(
        title: l10n.noWarehousesFound,
        subtitle: '$e',
        onRefresh: () =>
            ref.invalidate(_workerWarehousesByAmcosProvider(amcosId)),
      ),
      data: (warehouses) {
        if (warehouses.length == 1 &&
            widget.autoSelectSingleWarehouse &&
            widget.user.warehouseId != warehouses.first.id &&
            !_autoSelected) {
          _autoSelected = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _setActiveWarehouse(warehouses.first);
          });
          return const LoadingView();
        }

        if (warehouses.isEmpty) {
          return _WarehousePickerMessage(
            title: l10n.noWarehousesFound,
            subtitle: l10n.createWarehouseBeforeReceiving,
            onRefresh: () =>
                ref.invalidate(_workerWarehousesByAmcosProvider(amcosId)),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            widget.popOnSelect ? 8 : 96,
          ),
          itemCount: warehouses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final warehouse = warehouses[index];
            final selected = widget.user.warehouseId == warehouse.id;
            return AppCard(
              onTap: () => _setActiveWarehouse(warehouse),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.workerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.warehouse_rounded,
                      color: AppColors.workerColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          warehouse.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (warehouse.gpsLocation != null)
                          Text(
                            warehouse.gpsLocation!,
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
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color:
                        selected ? AppColors.workerColor : AppColors.textMuted,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _setActiveWarehouse(Warehouse warehouse) async {
    await ref.read(workerRepoProvider).setActiveWarehouse(
          userId: widget.user.id,
          warehouseId: warehouse.id,
        );
    if (!mounted) return;
    if (widget.popOnSelect) Navigator.of(context).pop();
  }
}

class _WarehousePickerMessage extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  const _WarehousePickerMessage({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: EmptyState(
            icon: Icons.warehouse_rounded,
            title: title,
            subtitle: subtitle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
            onPressed: onRefresh,
          ),
        ),
      ],
    );
  }
}

class _NoProfileView extends StatelessWidget {
  final VoidCallback onLogout;
  const _NoProfileView({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.workerColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.workerColor, size: 48),
            ),
            const SizedBox(height: 20),
            Text(l10n.workerDashboardTitle,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              l10n.workerProfileNoSync,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.signOut),
              onPressed: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action button widget ──────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        )),
        Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
      ]),
    );
  }
}
