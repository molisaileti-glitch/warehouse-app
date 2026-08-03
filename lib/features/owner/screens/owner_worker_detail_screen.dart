import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

class OwnerWorkerDetailScreen extends ConsumerWidget {
  final String workerId;

  const OwnerWorkerDetailScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(allWorkersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Worker Details'),
      ),
      body: workersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (workers) {
          final worker =
              workers.where((item) => item.id == workerId).firstOrNull;
          if (worker == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Worker not found',
            );
          }

          final warehouseAsync = worker.warehouseId == null
              ? const AsyncValue<Warehouse?>.data(null)
              : ref.watch(warehouseByIdProvider(worker.warehouseId!));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppColors.workerColor.withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.workerColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              worker.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              worker.email,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SyncStatusBadge(status: worker.syncStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      _DetailRow(label: 'Phone', value: worker.phoneNumber),
                      _DetailRow(label: 'Role', value: worker.role),
                      _DetailRow(
                        label: 'Status',
                        value: worker.isActive ? 'Active' : 'Inactive',
                      ),
                      _DetailRow(
                        label: 'AMCOS',
                        value: worker.amcos?.toString() ?? '-',
                      ),
                      _DetailRow(
                        label: 'MCU',
                        value: worker.mcu?.toString() ?? '-',
                      ),
                      warehouseAsync.maybeWhen(
                        data: (warehouse) => _DetailRow(
                          label: 'Warehouse',
                          value: warehouse?.name ?? '-',
                        ),
                        orElse: () => const _DetailRow(
                          label: 'Warehouse',
                          value: 'Loading...',
                        ),
                      ),
                      _DetailRow(
                        label: 'Created',
                        value: DateFormat('MMM d, yyyy HH:mm')
                            .format(worker.createdAt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
