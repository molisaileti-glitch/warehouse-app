import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_receiving_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

class HarvestFarmerDetailsScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  final bool ownerFlow;

  const HarvestFarmerDetailsScreen({
    super.key,
    required this.warehouseId,
    required this.ownerFlow,
  });

  @override
  ConsumerState<HarvestFarmerDetailsScreen> createState() =>
      _HarvestFarmerDetailsScreenState();
}

class _HarvestFarmerDetailsScreenState
    extends ConsumerState<HarvestFarmerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmerSearchCtrl = TextEditingController();

  int? _farmerId;
  int? _cropId;
  int? _cropGradeId;

  @override
  void initState() {
    super.initState();
    final session = ref.read(
      harvestReceivingControllerProvider(widget.warehouseId),
    );
    _farmerId = session.farmerId;
    _cropId = session.cropId;
    _cropGradeId = session.cropGradeId;
    Future.microtask(_pullReferenceData);
  }

  @override
  void dispose() {
    _farmerSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pullReferenceData() async {
    await ref.read(harvestRepositoryProvider).pullReferenceData();
    if (!mounted) return;
    ref.invalidate(measurementUnitsProvider);
    if (_cropId != null) {
      ref.invalidate(cropGradesForCropProvider(_cropId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouseAsync = ref.watch(warehouseByIdProvider(widget.warehouseId));
    final farmersAsync = ref.watch(allFarmersProvider);
    final cropsAsync = ref.watch(allCropsProvider);
    final unitsAsync = ref.watch(measurementUnitsProvider);
    final gradesAsync = _cropId == null
        ? const AsyncValue.data(<CropGrade>[])
        : ref.watch(cropGradesForCropProvider(_cropId!));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Farmer Details')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'farmer_details_next_${widget.warehouseId}',
        backgroundColor: AppColors.ownerColor,
        foregroundColor: Colors.white,
        onPressed: () => _continue(unitsAsync.valueOrNull ?? const []),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Next'),
      ),
      body: warehouseAsync.when(
        loading: () => const LoadingView(message: 'Loading warehouse...'),
        error: (e, _) => ErrorView(message: '$e'),
        data: (warehouse) {
          if (warehouse == null) {
            return const EmptyState(
              icon: Icons.warehouse_outlined,
              title: 'Warehouse not found',
            );
          }

          return _buildContent(
            warehouse: warehouse,
            farmersAsync: farmersAsync,
            cropsAsync: cropsAsync,
            gradesAsync: gradesAsync,
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required Warehouse warehouse,
    required AsyncValue<List<Farmer>> farmersAsync,
    required AsyncValue<List<Crop>> cropsAsync,
    required AsyncValue<List<CropGrade>> gradesAsync,
  }) {
    final farmers = farmersAsync.valueOrNull ?? const <Farmer>[];
    final crops = cropsAsync.valueOrNull ?? const <Crop>[];
    final grades = gradesAsync.valueOrNull ?? const <CropGrade>[];
    final selectedFarmer =
        farmers.where((farmer) => farmer.id == _farmerId).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.warehouse_rounded,
                    color: AppColors.ownerColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Collection center',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          warehouse.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle('Farmer'),
            TextField(
              controller: _farmerSearchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search farmer',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            _farmerPicker(farmersAsync, farmers),
            if (selectedFarmer != null) ...[
              const SizedBox(height: 10),
              AppCard(
                color: AppColors.ownerColor.withValues(alpha: 0.04),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.ownerColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Guarantor: farmer ID ${selectedFarmer.id}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            _sectionTitle('Crop'),
            _asyncGate(
              async: cropsAsync,
              emptyTitle: 'No crops available',
              emptySubtitle: 'Sync crop reference data first.',
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _cropId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Crop',
                      prefixIcon: Icon(Icons.grass_outlined),
                    ),
                    items: crops.map((crop) {
                      return DropdownMenuItem(
                        value: crop.id,
                        child: Text(
                          crop.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _cropId = value;
                        _cropGradeId = null;
                      });
                    },
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _cropGradeDropdown(gradesAsync, grades),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _farmerPicker(
    AsyncValue<List<Farmer>> farmersAsync,
    List<Farmer> farmers,
  ) {
    final query = _farmerSearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? farmers
        : farmers.where((farmer) {
            final text = [
              _farmerName(farmer),
              farmer.phoneNumber,
              farmer.id.toString(),
            ].join(' ').toLowerCase();
            return text.contains(query);
          }).toList();

    return _asyncGate(
      async: farmersAsync,
      emptyTitle: 'No farmers available',
      emptySubtitle: 'Sync or register farmers before receiving crops.',
      child: filtered.isEmpty
          ? const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No matching farmers',
            )
          : Column(
              children: filtered.take(6).map((farmer) {
                final selected = farmer.id == _farmerId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    color: selected
                        ? AppColors.ownerColor.withValues(alpha: 0.06)
                        : null,
                    onTap: () => setState(() => _farmerId = farmer.id),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? AppColors.ownerColor
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _farmerName(farmer),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${farmer.phoneNumber} - ID ${farmer.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _cropGradeDropdown(
    AsyncValue<List<CropGrade>> gradesAsync,
    List<CropGrade> grades,
  ) {
    return gradesAsync.when(
      loading: () => const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Crop grade',
          prefixIcon: Icon(Icons.workspace_premium_outlined),
          suffixIcon: Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Crop grade',
          hintText: '$e',
          prefixIcon: const Icon(Icons.workspace_premium_outlined),
        ),
      ),
      data: (_) {
        final hint = _cropId == null
            ? 'Select crop first'
            : grades.isEmpty
                ? 'No grades for selected crop'
                : 'Select grade';
        return DropdownButtonFormField<int>(
          key: ValueKey('grade-$_cropId-${grades.length}'),
          initialValue: _cropGradeId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Crop grade',
            hintText: hint,
            prefixIcon: const Icon(Icons.workspace_premium_outlined),
          ),
          items: grades.map((grade) {
            return DropdownMenuItem(
              value: grade.id,
              child: Text(grade.gradeName, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: grades.isEmpty
              ? null
              : (value) => setState(() => _cropGradeId = value),
        );
      },
    );
  }

  Widget _asyncGate<T>({
    required AsyncValue<List<T>> async,
    required Widget child,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (items) => items.isEmpty
          ? EmptyState(
              icon: Icons.sync_problem_outlined,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          : child,
    );
  }

  void _continue(List<MeasurementUnit> units) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_farmerId == null) {
      _showError('Select a farmer.');
      return;
    }
    if (_cropId == null) {
      _showError('Select a crop.');
      return;
    }

    ref
        .read(harvestReceivingControllerProvider(widget.warehouseId).notifier)
        .setDetails(
          farmerId: _farmerId!,
          cropId: _cropId!,
          cropGradeId: _cropGradeId,
          uomId: _preferredUnitId(units),
          packaging: 'BAGS',
        );

    context.push(
      widget.ownerFlow
          ? AppRoutes.ownerScaleBagsFor(widget.warehouseId)
          : AppRoutes.workerScaleBagsFor(widget.warehouseId),
    );
  }

  int? _preferredUnitId(List<MeasurementUnit> units) {
    if (units.isEmpty) return null;
    return units
            .where((unit) => unit.name.toUpperCase() == 'KILOGRAM')
            .firstOrNull
            ?.id ??
        units.first.id;
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }

  String _farmerName(Farmer farmer) {
    return [
      farmer.firstName,
      farmer.middleName,
      farmer.lastName,
    ]
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .join(' ');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}
