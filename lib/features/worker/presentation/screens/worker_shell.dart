// lib/features/worker/presentation/screens/worker_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../shared/widgets/reference_data_preparation_gate.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../../l10n/app_localizations.dart';

class WorkerShell extends ConsumerWidget {
  final Widget child;
  const WorkerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final userId = ref.watch(currentUserIdProvider);
    final userAsync = userId != null
        ? ref.watch(workerByIdProvider(userId))
        : const AsyncValue.data(null);
    final warehouseId = userAsync.valueOrNull?.warehouseId;

    int currentIndex = 0;
    if (location.contains('/inventory')) currentIndex = 1;
    if (location.contains('/harvests')) currentIndex = 2;
    if (location.contains('/farmers')) currentIndex = 3;

    return ReferenceDataPreparationGate(
      child: Scaffold(
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            if (i == 0) context.go(AppRoutes.workerDashboard);
            if (i == 1) {
              showTopToast(
                context,
                l10n.featureWillBeImplementedSoon,
                AppColors.info,
                icon: Icons.info_outline_rounded,
              );
              return;
            }
            if (i == 2 && warehouseId != null) {
              context.go(AppRoutes.workerHarvestsFor(warehouseId));
            }
            if (i == 3) context.go(AppRoutes.workerFarmers);
          },
          items: [
            BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded), label: l10n.home),
            BottomNavigationBarItem(
                icon: const Icon(Icons.inventory_2_rounded),
                label: l10n.inventory),
            BottomNavigationBarItem(
                icon: const Icon(Icons.grass_rounded), label: l10n.harvest),
            BottomNavigationBarItem(
                icon: const Icon(Icons.people_alt_rounded),
                label: l10n.farmers),
          ],
        ),
      ),
    );
  }
}
