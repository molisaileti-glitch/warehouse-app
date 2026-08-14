import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_dependant_model.dart';
import 'package:warehouse_app/features/farmer/presentation/widgets/dependant_form.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import 'package:warehouse_app/l10n/localized_values.dart';

class FarmerDetailScreen extends ConsumerStatefulWidget {
  final int farmerId;

  const FarmerDetailScreen({
    super.key,
    required this.farmerId,
  });

  @override
  ConsumerState<FarmerDetailScreen> createState() => _FarmerDetailScreenState();
}

class _FarmerDetailScreenState extends ConsumerState<FarmerDetailScreen> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final farmerAsync = ref.watch(farmerByIdProvider(widget.farmerId));
    final dependantsAsync =
        ref.watch(farmerDependantsProvider(widget.farmerId));
    final cropsAsync = ref.watch(allCropsProvider);
    final crops = cropsAsync.valueOrNull ?? const <Crop>[];
    final cropsLoading = cropsAsync.isLoading && crops.isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.farmerDetails),
      ),
      body: farmerAsync.when(
        data: (farmer) {
          if (farmer == null) {
            return ErrorView(message: l10n.farmerNotFound);
          }
          final name = [
            farmer.firstName,
            farmer.middleName,
            farmer.lastName,
          ].whereType<String>().where((v) => v.isNotEmpty).join(' ');

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.workerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${farmer.idType}: ${farmer.idNumber}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        farmer.phoneNumber,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppCard(
                    child: Column(
                      children: [
                        _DetailRow(
                          label: l10n.sex,
                          value: localizedReferenceValue(l10n, farmer.sex),
                        ),
                        _DetailRow(label: l10n.dateOfBirth, value: farmer.dob),
                        _DetailRow(
                          label: l10n.amcos,
                          value: farmer.amcosName ?? farmer.amcos.toString(),
                        ),
                        _DetailRow(
                          label: l10n.memberType,
                          value:
                              localizedReferenceValue(l10n, farmer.memberType),
                        ),
                        _DetailRow(
                          label: l10n.maritalStatus,
                          value: localizedReferenceValue(
                              l10n, farmer.maritalStatus),
                        ),
                        _DetailRow(
                          label: l10n.mainCrop,
                          value: _cropName(
                            farmer.mainCrop,
                            crops,
                            cropsLoading,
                            l10n,
                          ),
                        ),
                        _DetailRow(
                          label: l10n.secondaryCrop,
                          value: _cropName(
                            farmer.secondaryCrop,
                            crops,
                            cropsLoading,
                            l10n,
                          ),
                        ),
                        _DetailRow(
                          label: l10n.shares,
                          value: farmer.noOfShares?.toString() ?? '-',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: l10n.dependants,
                  actionLabel: l10n.add,
                  onAction: _adding ? null : _showAddDependantSheet,
                ),
              ),
              dependantsAsync.when(
                data: (dependants) {
                  if (dependants.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.noDependantsForFarmer,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => _DependantRow(
                          dependant: dependants[index],
                        ),
                        childCount: dependants.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: LoadingView()),
                error: (error, _) =>
                    SliverToBoxAdapter(child: ErrorView(message: '$error')),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: '$error'),
      ),
    );
  }

  String _cropName(
    int cropId,
    List<Crop> crops,
    bool loading,
    AppLocalizations l10n,
  ) {
    for (final crop in crops) {
      if (crop.id == cropId) return crop.name;
    }
    return loading ? l10n.loadingCrop : l10n.unknownCrop(cropId);
  }

  void _showAddDependantSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDependantSheet(
        loading: _adding,
        onSubmit: _addDependant,
      ),
    );
  }

  Future<void> _addDependant(FarmerDependantInput dependant) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showCreationConfirmDialog(
      context,
      title: l10n.addDependant,
      description: l10n.addDependantConfirm,
      confirmLabel: l10n.add,
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _adding = true);
    showCenteredLoadingDialog(
      context,
      title: l10n.addingDependant,
      description: l10n.savingDependantLocally,
    );
    final result = await ref.read(farmerRepoProvider).addDependant(
          farmerId: widget.farmerId,
          dependant: dependant,
        );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _adding = false);
    if (result.success) {
      ref.invalidate(farmerDependantsProvider(widget.farmerId));
    }
    Navigator.pop(context);
    if (result.success) {
      await showCreationSuccessDialog(
        context,
        title: l10n.dependantAdded,
        description: l10n.dependantAddedSuccess,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? l10n.dependantAddFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _AddDependantSheet extends StatelessWidget {
  final bool loading;
  final ValueChanged<FarmerDependantInput> onSubmit;

  const _AddDependantSheet({
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
      margin: EdgeInsets.only(
        top: mediaQuery.padding.top + 12,
        bottom: mediaQuery.viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: kToolbarHeight,
            child: AppBar(
              primary: false,
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: l10n.back,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(l10n.addDependant),
              elevation: 0,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    LoadingView(message: l10n.addingDependantProgress)
                  else
                    DependantForm(onSubmit: onSubmit),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DependantRow extends StatelessWidget {
  final FarmerDependant dependant;

  const _DependantRow({required this.dependant});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = [
      dependant.firstName,
      dependant.middleName,
      dependant.lastName,
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.workerColor.withValues(alpha: 0.1),
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
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${localizedReferenceValue(l10n, dependant.relationship)} - '
                  '${localizedReferenceValue(l10n, dependant.gender)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (dependant.phoneNumber != null)
                  Text(
                    dependant.phoneNumber!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
