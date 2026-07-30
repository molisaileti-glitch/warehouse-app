// lib/features/owner/screens/audit_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import 'package:intl/intl.dart';

final _auditLogsProvider = FutureProvider.autoDispose<List<AuditLog>>((ref) {
  final dao = ref.watch(auditLogDaoProvider);
  return dao.getLogsPage(pageSize: 100);
});

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
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
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No audit events',
              subtitle: 'Actions performed in the app will appear here',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) => _AuditTile(log: logs[i]),
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(_auditLogsProvider)),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditLog log;
  const _AuditTile({required this.log});

  (Color, IconData) _meta() {
    if (log.action.contains('create')) return (AppColors.success, Icons.add_circle_rounded);
    if (log.action.contains('delete')) return (AppColors.error, Icons.remove_circle_rounded);
    if (log.action.contains('transfer')) return (AppColors.info, Icons.swap_horiz_rounded);
    if (log.action.contains('stock')) return (AppColors.warning, Icons.inventory_rounded);
    return (AppColors.textSecondary, Icons.edit_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _meta();
    final fmt = DateFormat('MMM d, y • HH:mm');

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.action,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(fmt.format(log.createdAt),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                if (log.metadata != null) ...[
                  const SizedBox(height: 4),
                  Text(log.metadata!,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: log.origin == 'offline'
                  ? AppColors.warning.withOpacity(0.1)
                  : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(log.origin,
                style: TextStyle(
                    fontSize: 10,
                    color: log.origin == 'offline' ? AppColors.warning : AppColors.success)),
          ),
        ],
      ),
    );
  }
}