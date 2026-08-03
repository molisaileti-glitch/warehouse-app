import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

class FarmerListScreen extends ConsumerStatefulWidget {
  const FarmerListScreen({super.key});

  @override
  ConsumerState<FarmerListScreen> createState() => _FarmerListScreenState();
}

class _FarmerListScreenState extends ConsumerState<FarmerListScreen> {
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
      appBar: AppBar(
        title: const Text('Farmers'),
        actions: [
          IconButton(
            tooltip: 'Add farmer',
            onPressed: () => context.push(AppRoutes.workerFarmerRegistration),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search farmers...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() {
                _query = value.trim().toLowerCase();
              }),
            ),
          ),
          Expanded(
            child: farmersAsync.when(
              data: (farmers) {
                final filtered = _query.isEmpty
                    ? farmers
                    : farmers.where((farmer) {
                        final name =
                            '${farmer.firstName} ${farmer.middleName ?? ''} ${farmer.lastName}'
                                .toLowerCase();
                        return name.contains(_query) ||
                            farmer.idNumber.toLowerCase().contains(_query) ||
                            farmer.phoneNumber.toLowerCase().contains(_query);
                      }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_alt_outlined,
                    title: 'No farmers yet',
                    subtitle: 'Register a farmer at point of contact.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, index) {
                    final farmer = filtered[index];
                    final name = [
                      farmer.firstName,
                      farmer.middleName,
                      farmer.lastName,
                    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
                    return AppCard(
                      onTap: () => context.push(
                        AppRoutes.workerFarmerDetailFor(farmer.id),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.workerColor.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.workerColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${farmer.idType}: ${farmer.idNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (farmer.amcosName != null)
                                  Text(
                                    farmer.amcosName!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
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
                  },
                );
              },
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(message: '$error'),
            ),
          ),
        ],
      ),
    );
  }
}
