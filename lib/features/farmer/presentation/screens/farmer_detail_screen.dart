import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_dependant_model.dart';
import 'package:warehouse_app/features/farmer/presentation/widgets/dependant_form.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

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
    final farmerAsync = ref.watch(farmerByIdProvider(widget.farmerId));
    final dependantsAsync =
        ref.watch(farmerDependantsProvider(widget.farmerId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Farmer Details'),
      ),
      body: farmerAsync.when(
        data: (farmer) {
          if (farmer == null) {
            return const ErrorView(message: 'Farmer not found');
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
                        _DetailRow(label: 'Sex', value: farmer.sex),
                        _DetailRow(label: 'Date of birth', value: farmer.dob),
                        _DetailRow(
                          label: 'AMCOS',
                          value: farmer.amcosName ?? farmer.amcos.toString(),
                        ),
                        _DetailRow(
                          label: 'Member type',
                          value: farmer.memberType,
                        ),
                        _DetailRow(
                          label: 'Marital status',
                          value: farmer.maritalStatus,
                        ),
                        _DetailRow(
                          label: 'Main crop',
                          value: farmer.mainCrop.toString(),
                        ),
                        _DetailRow(
                          label: 'Secondary crop',
                          value: farmer.secondaryCrop.toString(),
                        ),
                        _DetailRow(
                          label: 'Shares',
                          value: farmer.noOfShares?.toString() ?? '-',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Dependants',
                  actionLabel: 'Add',
                  onAction: _adding ? null : _showAddDependantSheet,
                ),
              ),
              dependantsAsync.when(
                data: (dependants) {
                  if (dependants.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No dependants have been added for this farmer.',
                          style: TextStyle(color: AppColors.textSecondary),
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
    setState(() => _adding = true);
    final result = await ref.read(farmerRepoProvider).addDependant(
          farmerId: widget.farmerId,
          dependant: dependant,
        );
    if (!mounted) return;
    setState(() => _adding = false);
    if (result.success) {
      ref.invalidate(farmerDependantsProvider(widget.farmerId));
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Dependant added.'
              : result.error ?? 'Failed to add dependant.',
        ),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );
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
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add Dependant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            if (loading)
              const LoadingView(message: 'Adding dependant...')
            else
              DependantForm(onSubmit: onSubmit),
          ],
        ),
      ),
    );
  }
}

class _DependantRow extends StatelessWidget {
  final FarmerDependant dependant;

  const _DependantRow({required this.dependant});

  @override
  Widget build(BuildContext context) {
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
                  '${dependant.relationship} · ${dependant.gender}',
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
