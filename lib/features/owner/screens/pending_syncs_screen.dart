import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

class PendingSyncsScreen extends ConsumerWidget {
  const PendingSyncsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(_pendingSyncsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.ownerDashboard),
          tooltip: 'Back',
        ),
        title: const Text('Pending Syncs'),
      ),
      body: pendingAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.cloud_done_rounded,
              title: 'All synced',
              subtitle: 'There are no local owner changes waiting to upload.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.22),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Use the sync button on the dashboard to upload these changes.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final entry in entries) ...[
                _PendingSyncTile(entry: entry),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: '$error'),
      ),
    );
  }
}

final _pendingSyncsProvider = StreamProvider<List<SyncQueueData>>((ref) {
  return ref.watch(syncQueueDaoProvider).watchPendingEntries().map(
        (entries) => entries
            .where((entry) =>
                entry.entityType == 'warehouses' || entry.entityType == 'users')
            .toList(),
      );
});

class _PendingSyncTile extends StatelessWidget {
  final SyncQueueData entry;

  const _PendingSyncTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final details = _syncDetails(entry);
    final time = DateFormat('MMM d, HH:mm').format(entry.createdAt);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: details.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(details.icon, color: details.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${details.subtitle} - $time',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SyncStatusBadge(status: 'pending'),
        ],
      ),
    );
  }
}

_SyncDetails _syncDetails(SyncQueueData entry) {
  final payload = _payload(entry.payload);
  final operation = _operationLabel(entry.operation);

  return switch (entry.entityType) {
    'warehouses' => _SyncDetails(
        title: '$operation warehouse',
        subtitle: _stringValue(payload, 'name') ?? 'Warehouse record',
        icon: Icons.warehouse_rounded,
        color: AppColors.ownerColor,
      ),
    'users' => _SyncDetails(
        title: '$operation worker',
        subtitle: _stringValue(payload, 'fullName') ?? 'Worker account',
        icon: Icons.person_add_alt_1_rounded,
        color: AppColors.workerColor,
      ),
    _ => _SyncDetails(
        title: '$operation ${entry.entityType}',
        subtitle: entry.entityId,
        icon: Icons.cloud_upload_rounded,
        color: AppColors.warning,
      ),
  };
}

Map<String, dynamic> _payload(String value) {
  try {
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

String _operationLabel(String operation) {
  final text = operation.trim().toLowerCase();
  if (text.isEmpty) return 'Sync';
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

String? _stringValue(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

class _SyncDetails {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SyncDetails({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
