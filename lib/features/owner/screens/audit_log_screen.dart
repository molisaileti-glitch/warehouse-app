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
import 'package:warehouse_app/l10n/app_localizations.dart';

final _auditLogsProvider = FutureProvider.autoDispose<List<AuditLog>>((ref) {
  return ref.watch(auditLogDaoProvider).getLogsPage(pageSize: 100);
});

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final logsAsync = ref.watch(_auditLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.ownerDashboard),
        ),
        title: Text(l10n.recentActivity),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_auditLogsProvider),
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return EmptyState(
              icon: Icons.history_rounded,
              title: l10n.noActivityYet,
              subtitle: l10n.activityWillAppear,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AuditTile(log: logs[i]),
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(_auditLogsProvider),
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditLog log;

  const _AuditTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = _activityDetails(log, l10n);
    final date =
        DateFormat('MMM d, y HH:mm', l10n.localeName).format(log.createdAt);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: details.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(details.icon, color: details.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                if (details.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    details.subtitle!,
                    maxLines: 2,
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
    );
  }
}

_ActivityDetails _activityDetails(AuditLog log, AppLocalizations l10n) {
  final metadata = _metadata(log.metadata);
  final subtitle = _firstUsefulValue(metadata);

  if (log.action.contains('create')) {
    return _ActivityDetails(
      title: _titleFromAction(log.action, l10n),
      subtitle: subtitle,
      icon: Icons.add_circle_rounded,
      color: AppColors.success,
    );
  }
  if (log.action.contains('delete')) {
    return _ActivityDetails(
      title: _titleFromAction(log.action, l10n),
      subtitle: subtitle,
      icon: Icons.remove_circle_rounded,
      color: AppColors.error,
    );
  }
  if (log.action.contains('transfer')) {
    return _ActivityDetails(
      title: _titleFromAction(log.action, l10n),
      subtitle: subtitle,
      icon: Icons.swap_horiz_rounded,
      color: AppColors.info,
    );
  }
  if (log.action.contains('stock')) {
    return _ActivityDetails(
      title: _titleFromAction(log.action, l10n),
      subtitle: subtitle,
      icon: Icons.inventory_rounded,
      color: AppColors.warning,
    );
  }

  return _ActivityDetails(
    title: _titleFromAction(log.action, l10n),
    subtitle: subtitle,
    icon: Icons.history_rounded,
    color: AppColors.textSecondary,
  );
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

String? _firstUsefulValue(Map<String, dynamic> metadata) {
  const keys = [
    'name',
    'fullName',
    'receiptNumber',
    'warehouseName',
    'farmerName',
    'email',
  ];
  for (final key in keys) {
    final value = metadata[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String _titleFromAction(String action, AppLocalizations l10n) {
  final known = switch (action.toLowerCase()) {
    'warehouse.create' => l10n.warehouseCreatedActivity,
    'warehouse.update' => l10n.warehouseUpdatedActivity,
    'warehouse.delete' => l10n.warehouseDeletedActivity,
    'worker.create' => l10n.workerCreatedActivity,
    'worker.update' => l10n.workerUpdated,
    'worker.delete' => l10n.workerDeleted,
    'farmer.create' => l10n.farmerRegisteredActivity,
    'harvest.create' => l10n.harvestRecordedActivity,
    _ => null,
  };
  if (known != null) return known;
  return action
      .split('.')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _ActivityDetails {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _ActivityDetails({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
