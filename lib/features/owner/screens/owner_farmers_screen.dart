import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

class OwnerFarmersScreen extends ConsumerStatefulWidget {
  const OwnerFarmersScreen({super.key});

  @override
  ConsumerState<OwnerFarmersScreen> createState() => _OwnerFarmersScreenState();
}

class _OwnerFarmersScreenState extends ConsumerState<OwnerFarmersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmersAsync = ref.watch(allFarmersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Farmers'),
        actions: [
          IconButton(
            tooltip: 'Add farmer',
            onPressed: () => context.push(AppRoutes.ownerFarmerRegistration),
            icon: const Icon(Icons.add_rounded),
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
                      decoration: const InputDecoration(
                        hintText: 'Search farmers...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            farmersAsync.when(
              data: (farmers) {
                final filtered = _query.isEmpty
                    ? farmers
                    : farmers.where((farmer) {
                        final text = [
                          farmer.firstName,
                          farmer.middleName ?? '',
                          farmer.lastName,
                          farmer.idNumber,
                          farmer.phoneNumber,
                          farmer.amcosName ?? '',
                        ].join(' ').toLowerCase();
                        return text.contains(_query);
                      }).toList();

                if (filtered.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.people_alt_outlined,
                      title: 'No farmers found',
                      subtitle: 'Worker-registered farmers will appear here.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, index) {
                        if (index.isOdd) return const SizedBox(height: 10);
                        return _FarmerTile(farmer: filtered[index ~/ 2]);
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
}

class _FarmerTile extends StatelessWidget {
  final Farmer farmer;

  const _FarmerTile({required this.farmer});

  @override
  Widget build(BuildContext context) {
    final name = [
      farmer.firstName,
      farmer.middleName,
      farmer.lastName,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');

    return AppCard(
      onTap: () => context.push(AppRoutes.ownerFarmerDetailFor(farmer.id)),
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
              Icons.agriculture_rounded,
              color: AppColors.ownerColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
                  '${farmer.idType}: ${farmer.idNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (farmer.amcosName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    farmer.amcosName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _FarmerStatusBadge(status: farmer.status),
        ],
      ),
    );
  }
}

class _FarmerStatusBadge extends StatelessWidget {
  final String status;

  const _FarmerStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status.trim().toLowerCase() == 'active';
    final color = active ? AppColors.success : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        active ? 'Active' : status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
