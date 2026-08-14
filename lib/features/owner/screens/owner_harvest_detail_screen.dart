import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

final _ownerHarvestByUuidProvider =
    StreamProvider.family<FarmerHarvest?, String>((ref, uuid) {
  return ref.watch(harvestDaoProvider).watchAllHarvests().map(
        (harvests) =>
            harvests.where((harvest) => harvest.uuid == uuid).firstOrNull,
      );
});

class OwnerHarvestDetailScreen extends ConsumerWidget {
  final String harvestUuid;

  const OwnerHarvestDetailScreen({super.key, required this.harvestUuid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final harvestAsync = ref.watch(_ownerHarvestByUuidProvider(harvestUuid));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.harvestDetails),
      ),
      body: harvestAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (harvest) {
          if (harvest == null) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.harvestNotFound,
            );
          }

          final date = DateFormat('MMM d, yyyy HH:mm', l10n.localeName).format(
            harvest.receivedAt,
          );
          final uom = harvest.uomName ?? 'kg';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.ownerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.grass_rounded,
                          color: AppColors.ownerColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              harvest.receiptNumber,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SyncStatusBadge(status: harvest.syncStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      _DetailRow(
                        label: l10n.receiptFarmer,
                        value: harvest.farmerName,
                      ),
                      _DetailRow(
                          label: l10n.phone, value: harvest.farmerPhoneNumber),
                      _DetailRow(label: l10n.crop, value: harvest.cropName),
                      if (_showGrade(harvest))
                        _DetailRow(
                          label: l10n.grade,
                          value: harvest.cropGradeName!,
                        ),
                      _DetailRow(
                        label: l10n.warehouse,
                        value: harvest.collectionCenterName,
                      ),
                      _DetailRow(
                        label: l10n.receiptGross,
                        value: '${_weight(harvest.grossWeight)} $uom',
                      ),
                      _DetailRow(
                        label: l10n.receiptTare,
                        value: '${_weight(harvest.packagingWeight)} $uom',
                      ),
                      _DetailRow(
                        label: l10n.moisture,
                        value: '${_weight(harvest.moistureContent)}%',
                      ),
                      _DetailRow(
                        label: l10n.receiptNet,
                        value: '${_weight(harvest.netWeight)} $uom',
                        strong: true,
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

  String _weight(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  bool _showGrade(FarmerHarvest harvest) {
    final grade = harvest.cropGradeName?.trim();
    if (grade == null || grade.isEmpty) return false;
    return grade.toLowerCase() != harvest.cropName.trim().toLowerCase();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _DetailRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

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
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
