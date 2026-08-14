import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_providers.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

final _workerHarvestByUuidProvider = StreamProvider.family
    .autoDispose<FarmerHarvest?, ({String warehouseId, String harvestUuid})>(
  (ref, args) {
    return ref
        .watch(harvestRepositoryProvider)
        .watchRecentHarvests(
          args.warehouseId,
        )
        .map(
          (harvests) => _findHarvest(harvests, args.harvestUuid),
        );
  },
);

class WorkerHarvestDetailScreen extends ConsumerWidget {
  final String warehouseId;
  final String harvestUuid;

  const WorkerHarvestDetailScreen({
    super.key,
    required this.warehouseId,
    required this.harvestUuid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final harvestAsync = ref.watch(
      _workerHarvestByUuidProvider(
        (warehouseId: warehouseId, harvestUuid: harvestUuid),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.harvestDetails)),
      body: harvestAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: '$error'),
        data: (harvest) {
          if (harvest == null) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.harvestNotFound,
              subtitle: l10n.harvestRemovedLocally,
            );
          }

          final date = DateFormat('MMM d, yyyy HH:mm', l10n.localeName).format(
            harvest.receivedAt,
          );
          final uom = harvest.uomName ?? 'kg';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.workerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      harvest.receiptNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      date,
                      style: const TextStyle(color: Colors.white70),
                    ),
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
                      label: l10n.phone,
                      value: harvest.farmerPhoneNumber,
                    ),
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
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

FarmerHarvest? _findHarvest(List<FarmerHarvest> harvests, String uuid) {
  for (final harvest in harvests) {
    if (harvest.uuid == uuid) return harvest;
  }
  return null;
}

String _weight(double value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 2);

bool _showGrade(FarmerHarvest harvest) {
  final grade = harvest.cropGradeName?.trim();
  if (grade == null || grade.isEmpty) return false;
  return grade.toLowerCase() != harvest.cropName.trim().toLowerCase();
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
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
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
