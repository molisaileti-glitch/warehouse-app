// lib/features/worker/presentation/screens/worker_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../../core/database/app_database.dart';

// Scoped provider — watches the current worker's User record from local DB.
final _workerProfileProvider = StreamProvider<User?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(workerRepoProvider).watchWorkerById(userId);
});

class WorkerDashboardScreen extends ConsumerWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_workerProfileProvider);
    final l10n = AppLocalizations.of(context)!;

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
      return Column(
        children: [
          Expanded(
            child: EmptyState(
              icon: Icons.warehouse_rounded,
              title: l10n.notAssignedWarehouse,
              subtitle: l10n.askAdminAssignment,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.signOut),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
        ],
      );
    }

    // ── Normal state — warehouse assigned ─────────────────────────────────────
    final itemsAsync = ref.watch(inventoryItemsProvider(warehouseId));
    final whAsync = ref.watch(warehouseByIdProvider(warehouseId));
    final lowAsync = ref.watch(lowStockProvider(warehouseId));

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
                label: l10n.totalItems,
                value: '${itemsAsync.valueOrNull?.length ?? 0}',
                icon: Icons.inventory_2_rounded,
                color: AppColors.workerColor,
                onTap: () =>
                    context.go(AppRoutes.workerInventoryFor(warehouseId)),
              ),
              StatCard(
                label: l10n.lowStock,
                value: '${lowAsync.valueOrNull?.length ?? 0}',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
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
                label: 'Register Farmer',
                subtitle: 'Create farmer records at point of contact',
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

        // Low stock alerts
        if ((lowAsync.valueOrNull?.length ?? 0) > 0) ...[
          SliverToBoxAdapter(child: SectionHeader(title: l10n.lowStockAlerts)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final item = lowAsync.valueOrNull![i];
                  return AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    color: AppColors.warning.withValues(alpha: 0.04),
                    child: Row(children: [
                      const Icon(Icons.warning_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500))),
                      Text(
                          '${item.quantityOnHand % 1 == 0 ? item.quantityOnHand.toInt() : item.quantityOnHand} ${item.unit}',
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700)),
                    ]),
                  );
                },
                childCount: lowAsync.valueOrNull!.length,
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ── No profile view — shown during mock/dev when user isn't in local DB ───────

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
