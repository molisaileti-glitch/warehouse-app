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

class PendingSyncsScreen extends ConsumerWidget {
  final bool workerFlow;

  const PendingSyncsScreen({
    super.key,
    this.workerFlow = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pendingAsync = ref.watch(_pendingSyncsProvider(workerFlow));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(
            workerFlow ? AppRoutes.workerDashboard : AppRoutes.ownerDashboard,
          ),
          tooltip: l10n.back,
        ),
        title: Text(l10n.pendingSyncs),
      ),
      body: pendingAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.cloud_done_rounded,
              title: l10n.allSynced,
              subtitle: l10n.noPendingChanges,
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.useDashboardSync,
                        style: const TextStyle(
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

final _pendingSyncsProvider =
    StreamProvider.family<List<SyncQueueData>, bool>((ref, workerFlow) {
  return ref.watch(syncQueueDaoProvider).watchPendingEntries().map(
        (entries) => entries.where((entry) {
          if (workerFlow) {
            return entry.entityType == 'farmers' ||
                entry.entityType == 'farmerDependants' ||
                entry.entityType == 'farmerHarvests' ||
                entry.entityType == 'dispatches' ||
                entry.entityType == 'stockCounts' ||
                entry.entityType == 'stockAdjustments';
          }
          return entry.entityType == 'warehouses' ||
              entry.entityType == 'users' ||
              entry.entityType == 'farmers' ||
              entry.entityType == 'farmerDependants' ||
              entry.entityType == 'farmerHarvests' ||
              entry.entityType == 'dispatches' ||
              entry.entityType == 'stockCounts' ||
              entry.entityType == 'stockAdjustments';
        }).toList(),
      );
});

class _PendingSyncTile extends StatelessWidget {
  final SyncQueueData entry;

  const _PendingSyncTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = _syncDetails(entry, l10n);
    final time =
        DateFormat('MMM d, HH:mm', l10n.localeName).format(entry.createdAt);

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

_SyncDetails _syncDetails(SyncQueueData entry, AppLocalizations l10n) {
  final payload = _payload(entry.payload);
  final operation = _operationLabel(entry.operation, l10n);

  return switch (entry.entityType) {
    'warehouses' => _SyncDetails(
        title: l10n.operationWarehouse(operation),
        subtitle: _stringValue(payload, 'name') ?? l10n.warehouseRecord,
        icon: Icons.warehouse_rounded,
        color: AppColors.ownerColor,
      ),
    'users' => _SyncDetails(
        title: l10n.operationWorker(operation),
        subtitle: _stringValue(payload, 'fullName') ?? l10n.workerAccount,
        icon: Icons.person_add_alt_1_rounded,
        color: AppColors.workerColor,
      ),
    'farmers' => _SyncDetails(
        title: l10n.operationFarmer(operation),
        subtitle: [
          _stringValue(payload, 'firstName'),
          _stringValue(payload, 'middleName'),
          _stringValue(payload, 'lastName'),
        ].whereType<String>().join(' '),
        icon: Icons.person_outline_rounded,
        color: AppColors.success,
      ),
    'farmerDependants' => _SyncDetails(
        title: l10n.operationDependant(operation),
        subtitle: [
          _stringValue(payload, 'firstName'),
          _stringValue(payload, 'middleName'),
          _stringValue(payload, 'lastName'),
        ].whereType<String>().join(' '),
        icon: Icons.family_restroom_rounded,
        color: AppColors.info,
      ),
    'farmerHarvests' => _SyncDetails(
        title: l10n.operationHarvest(operation),
        subtitle: _stringValue(payload, 'farmerName') ??
            _stringValue(payload, 'receiptNumber') ??
            l10n.harvestRecord,
        icon: Icons.grass_rounded,
        color: AppColors.success,
      ),
    'dispatches' => _SyncDetails(
        title: '$operation Dispatch',
        subtitle: _stringValue(payload, 'recipientName') ?? entry.entityId,
        icon: Icons.local_shipping_outlined,
        color: AppColors.warning,
      ),
    'stockCounts' => _SyncDetails(
        title: '$operation Stock Count',
        subtitle: _stringValue(payload, 'countedAt') ?? entry.entityId,
        icon: Icons.fact_check_outlined,
        color: AppColors.info,
      ),
    'stockAdjustments' => _SyncDetails(
        title: '$operation Stock Adjustment',
        subtitle: _stringValue(payload, 'reason') ?? entry.entityId,
        icon: Icons.tune_rounded,
        color: AppColors.warning,
      ),
    _ => _SyncDetails(
        title: l10n.operationRecord(operation, entry.entityType),
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

String _operationLabel(String operation, AppLocalizations l10n) {
  final text = operation.trim().toLowerCase();
  if (text.isEmpty) return l10n.sync;
  if (text == 'create' || text == 'created') return l10n.create;
  if (text == 'update' || text == 'updated') return l10n.update;
  if (text == 'delete' || text == 'deleted') return l10n.delete;
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
