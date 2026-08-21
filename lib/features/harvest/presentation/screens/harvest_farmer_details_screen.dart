import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_receiving_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

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
  final _farmerSearchFocus = FocusNode();

  int? _farmerId;
  int? _cropId;
  bool _showFarmerResults = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(
      harvestReceivingControllerProvider(widget.warehouseId),
    );
    _farmerId = session.farmerId;
    _cropId = session.cropId;
    _farmerSearchFocus.addListener(() {
      if (_farmerSearchFocus.hasFocus) {
        setState(() => _showFarmerResults = true);
      }
    });
  }

  @override
  void dispose() {
    _farmerSearchCtrl.dispose();
    _farmerSearchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final warehouseAsync = ref.watch(warehouseByIdProvider(widget.warehouseId));
    final farmersAsync = ref.watch(allFarmersProvider);
    final cropsAsync = ref.watch(allCropsProvider);
    final unitsAsync = ref.watch(measurementUnitsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.farmerDetails)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'farmer_details_next_${widget.warehouseId}',
        backgroundColor: AppColors.ownerColor,
        foregroundColor: Colors.white,
        onPressed: () => _continue(unitsAsync.valueOrNull ?? const []),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(l10n.next),
      ),
      body: warehouseAsync.when(
        loading: () => LoadingView(message: l10n.loadingWarehouse),
        error: (e, _) => ErrorView(message: '$e'),
        data: (warehouse) {
          if (warehouse == null) {
            return EmptyState(
              icon: Icons.warehouse_outlined,
              title: l10n.warehouseNotFound,
            );
          }

          return _buildContent(
            warehouse: warehouse,
            farmersAsync: farmersAsync,
            cropsAsync: cropsAsync,
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required Warehouse warehouse,
    required AsyncValue<List<Farmer>> farmersAsync,
    required AsyncValue<List<Crop>> cropsAsync,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final farmers = farmersAsync.valueOrNull ?? const <Farmer>[];
    final crops = cropsAsync.valueOrNull ?? const <Crop>[];
    final selectedFarmer = farmers.where((f) => f.id == _farmerId).firstOrNull;
    if (selectedFarmer != null && _farmerSearchCtrl.text.isEmpty) {
      _farmerSearchCtrl.text = _farmerName(selectedFarmer);
    }

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
                        Text(
                          l10n.collectionCenter,
                          style: const TextStyle(
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
            _sectionTitle(l10n.receiptFarmer),
            _farmerPicker(farmersAsync, farmers),
            const SizedBox(height: 18),
            _sectionTitle(l10n.crop),
            _asyncGate(
              async: cropsAsync,
              emptyTitle: l10n.noCropsAvailable,
              emptySubtitle: l10n.syncCropDataFirst,
              child: DropdownButtonFormField<int>(
                initialValue: _cropId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.crop,
                  prefixIcon: const Icon(Icons.grass_outlined),
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
                onChanged: (value) => setState(() => _cropId = value),
                validator: (value) => value == null ? l10n.requiredField : null,
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
    final l10n = AppLocalizations.of(context)!;
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
      emptyTitle: l10n.noFarmersAvailable,
      emptySubtitle: l10n.syncOrRegisterFarmers,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _farmerSearchCtrl,
              focusNode: _farmerSearchFocus,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _farmerSearchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.clearSearch,
                        onPressed: () {
                          _farmerSearchCtrl.clear();
                          setState(() {
                            _farmerId = null;
                            _showFarmerResults = true;
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
              onTap: () => setState(() => _showFarmerResults = true),
              onChanged: (_) => setState(() => _showFarmerResults = true),
            ),
            if (_showFarmerResults) ...[
              const Divider(height: 1),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.person_search_outlined,
                    title: l10n.noMatchingFarmers,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final farmer = filtered[index];
                      return _FarmerSearchRow(
                        name: _farmerName(farmer),
                        selected: farmer.id == _farmerId,
                        onTap: () {
                          _farmerSearchCtrl.text = _farmerName(farmer);
                          _farmerSearchCtrl.selection = TextSelection.collapsed(
                            offset: _farmerSearchCtrl.text.length,
                          );
                          _farmerSearchFocus.unfocus();
                          setState(() {
                            _farmerId = farmer.id;
                            _showFarmerResults = false;
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
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
    final l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_farmerId == null) {
      _showError(l10n.selectFarmer);
      return;
    }
    if (_cropId == null) {
      _showError(l10n.selectCrop);
      return;
    }

    ref
        .read(harvestReceivingControllerProvider(widget.warehouseId).notifier)
        .setDetails(
          farmerId: _farmerId!,
          cropId: _cropId!,
          cropGradeId: null,
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
    final name = [
      farmer.firstName,
      farmer.middleName,
      farmer.lastName,
    ]
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .join(' ');
    return name.isEmpty
        ? AppLocalizations.of(context)!.farmerNumber(farmer.id)
        : name;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}

class _FarmerSearchRow extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _FarmerSearchRow({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      selected ? AppColors.ownerColor : AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.ownerColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
