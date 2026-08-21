import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/additional.data/amcos/presentation/providers/amcos_providers.dart';
import 'package:warehouse_app/features/owner/widgets/owner_drawer.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class AmcosListScreen extends ConsumerWidget {
  const AmcosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mcuAsync = ref.watch(currentUserMcuProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      drawer: const OwnerDrawer(),
      appBar: AppBar(
        title: Text(l10n.amcosManagement),
        actions: [
          IconButton(
            tooltip: l10n.addAmcos,
            onPressed: () => context.push(AppRoutes.ownerAmcosCreate),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: mcuAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(message: '$error'),
          data: (mcuId) {
            if (mcuId == null) {
              return ErrorView(message: l10n.errorMissingMcuAssignment);
            }

            return ref.watch(amcosByMcuProvider(mcuId)).when(
                  loading: () => const LoadingView(),
                  error: (error, _) => ErrorView(message: '$error'),
                  data: (items) => items.isEmpty
                      ? EmptyState(
                          icon: Icons.groups_2_outlined,
                          title: l10n.noAmcosFound,
                          subtitle: l10n.createFirstAmcos,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _AmcosTile(amcos: items[index]),
                        ),
                );
          },
        ),
      ),
    );
  }
}

class _AmcosTile extends StatelessWidget {
  final Amcos amcos;

  const _AmcosTile({required this.amcos});

  @override
  Widget build(BuildContext context) {
    final location = [amcos.regionName, amcos.districtName, amcos.villageName]
        .where((value) => value.trim().isNotEmpty)
        .join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_2_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amcos.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amcos.memberCategory.replaceAll('_', ' '),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
