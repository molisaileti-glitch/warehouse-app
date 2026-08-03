import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

String buildWarehouseGpsLocation({
  String? regionName,
  String? districtName,
  String? wardName,
  String? villageName,
}) {
  final parts = <String>[];
  if (regionName?.trim().isNotEmpty ?? false) parts.add(regionName!.trim());
  if (districtName?.trim().isNotEmpty ?? false) parts.add(districtName!.trim());
  if (wardName?.trim().isNotEmpty ?? false) parts.add(wardName!.trim());
  if (villageName?.trim().isNotEmpty ?? false) parts.add(villageName!.trim());
  return parts.join(', ');
}

class WarehouseListScreen extends ConsumerStatefulWidget {
  const WarehouseListScreen({super.key});

  @override
  ConsumerState<WarehouseListScreen> createState() =>
      _WarehouseListScreenState();
}

class _WarehouseListScreenState extends ConsumerState<WarehouseListScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _activeOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {}

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final warehousesAsync = userId != null
        ? ref.watch(warehousesByOwnerProvider(userId))
        : const AsyncValue.data(<Warehouse>[]);
    final workersAsync = ref.watch(allWorkersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Warehouses'),
        actions: [
          IconButton(
            tooltip: 'Add warehouse',
            onPressed: () => _showCreateSheet(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: warehousesAsync.when(
            data: (warehouses) {
              final query = _query.trim().toLowerCase();
              final baseList = _activeOnly
                  ? warehouses.where((warehouse) => warehouse.isActive).toList()
                  : warehouses;
              final filtered = query.isEmpty
                  ? baseList
                  : baseList.where((warehouse) {
                      final location = _warehouseLocation(warehouse);
                      return warehouse.name.toLowerCase().contains(query) ||
                          location.toLowerCase().contains(query);
                    }).toList();
              final activeCount =
                  warehouses.where((warehouse) => warehouse.isActive).length;
              final workerCount = workersAsync.valueOrNull?.length ?? 0;

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: 'Search warehouses...',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _WarehouseSummaryCard(
                                  value: '${warehouses.length}',
                                  label: 'Total',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _WarehouseSummaryCard(
                                  value: '$workerCount',
                                  label: 'Workers',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _WarehouseSummaryCard(
                                  value: '$activeCount/${warehouses.length}',
                                  label: 'Active',
                                  highlighted: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'All Warehouses',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _activeOnly = !_activeOnly,
                                ),
                                child: Text(_activeOnly ? 'All' : 'Filter'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.warehouse_rounded,
                        title: 'No warehouses found',
                        subtitle: 'Tap + to create your first warehouse.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, index) {
                            if (index.isOdd) {
                              return const SizedBox(height: 12);
                            }
                            return _WarehouseTile(
                              warehouse: filtered[index ~/ 2],
                            );
                          },
                          childCount: filtered.length * 2 - 1,
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(message: '$error'),
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateWarehouseSheet(),
    );
  }
}

class _WarehouseSummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final bool highlighted;

  const _WarehouseSummaryCard({
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? AppColors.ownerColor : Colors.white;
    final fg = highlighted ? Colors.white : AppColors.textPrimary;
    final sub = highlighted ? Colors.white70 : AppColors.textSecondary;

    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: highlighted ? null : Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: fg,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sub,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseTile extends StatelessWidget {
  final Warehouse warehouse;

  const _WarehouseTile({required this.warehouse});

  @override
  Widget build(BuildContext context) {
    final location = _warehouseLocation(warehouse);
    final active = warehouse.isActive;

    return AppCard(
      onTap: () => context.push('/owner/warehouses/${warehouse.id}'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        warehouse.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _WarehouseStatusBadge(active: active),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _WarehouseStatusBadge extends StatelessWidget {
  final bool active;

  const _WarehouseStatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _warehouseLocation(Warehouse warehouse) {
  final value = warehouse.gpsLocation?.trim();
  if (value != null && value.isNotEmpty) {
    return value.split(',').first.trim();
  }
  final village = warehouse.villageName?.trim();
  if (village != null && village.isNotEmpty) return village;
  final amcos = warehouse.amcosName?.trim();
  if (amcos != null && amcos.isNotEmpty) return amcos;
  return 'Location not set';
}

class _CreateWarehouseSheet extends ConsumerStatefulWidget {
  const _CreateWarehouseSheet();

  @override
  ConsumerState<_CreateWarehouseSheet> createState() =>
      _CreateWarehouseSheetState();
}

class _CreateWarehouseSheetState extends ConsumerState<_CreateWarehouseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _gpsCtrl = TextEditingController();
  Region? _selectedRegion;
  District? _selectedDistrict;
  Ward? _selectedWard;
  Village? _selectedVillage;
  Amcos? _selectedAmcos;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gpsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final gpsLocation = buildWarehouseGpsLocation(
        regionName: _selectedRegion?.name,
        districtName: _selectedDistrict?.name,
        wardName: _selectedWard?.name,
        villageName: _selectedVillage?.name,
      );

      await ref.read(warehouseRepoProvider).createWarehouse(
            name: _nameCtrl.text.trim(),
            gpsLocation:
                gpsLocation.isEmpty ? _selectedVillage?.name : gpsLocation,
            amcos: _selectedAmcos?.id,
            amcosName: _selectedAmcos?.name,
            village: _selectedVillage?.id,
            villageName: _selectedVillage?.name,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warehouse created locally. Sync to upload.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildLocationDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> Function(List<T>) itemBuilder,
    required ValueChanged<T?> onChanged,
    required Stream<List<T>> Function() streamBuilder,
    String? Function(T?)? validator,
  }) {
    return StreamBuilder<List<T>>(
      stream: streamBuilder(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? <T>[];
        return DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: itemBuilder(items),
          onChanged: onChanged,
          validator:
              validator == null ? null : (selected) => validator(selected),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 20),
              const Text(
                'New Warehouse',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Warehouse name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildLocationDropdown<Region>(
                label: 'Region',
                value: _selectedRegion,
                streamBuilder: () =>
                    ref.read(regionDaoProvider).watchAllRegions(),
                itemBuilder: (regions) => regions
                    .map(
                      (region) => DropdownMenuItem<Region>(
                        value: region,
                        child: Text(region.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRegion = value;
                    _selectedDistrict = null;
                    _selectedWard = null;
                    _selectedVillage = null;
                    _gpsCtrl.text =
                        buildWarehouseGpsLocation(regionName: value?.name);
                  });
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildLocationDropdown<District>(
                label: 'District',
                value: _selectedDistrict,
                streamBuilder: () => _selectedRegion == null
                    ? Stream.value(const <District>[])
                    : ref
                        .read(districtDaoProvider)
                        .watchDistrictsByRegion(_selectedRegion!.id),
                itemBuilder: (districts) => districts
                    .map(
                      (district) => DropdownMenuItem<District>(
                        value: district,
                        child: Text(district.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDistrict = value;
                    _selectedWard = null;
                    _selectedVillage = null;
                    _gpsCtrl.text = buildWarehouseGpsLocation(
                      regionName: _selectedRegion?.name,
                      districtName: value?.name,
                    );
                  });
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildLocationDropdown<Ward>(
                label: 'Ward',
                value: _selectedWard,
                streamBuilder: () => _selectedDistrict == null
                    ? Stream.value(const <Ward>[])
                    : ref
                        .read(wardDaoProvider)
                        .watchWardsByDistrict(_selectedDistrict!.id),
                itemBuilder: (wards) => wards
                    .map(
                      (ward) => DropdownMenuItem<Ward>(
                        value: ward,
                        child: Text(ward.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedWard = value;
                    _selectedVillage = null;
                    _gpsCtrl.text = buildWarehouseGpsLocation(
                      regionName: _selectedRegion?.name,
                      districtName: _selectedDistrict?.name,
                      wardName: value?.name,
                    );
                  });
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildLocationDropdown<Village>(
                label: 'Village',
                value: _selectedVillage,
                streamBuilder: () => _selectedWard == null
                    ? Stream.value(const <Village>[])
                    : ref
                        .read(villageDaoProvider)
                        .watchVillagesByWard(_selectedWard!.id),
                itemBuilder: (villages) => villages
                    .map(
                      (village) => DropdownMenuItem<Village>(
                        value: village,
                        child: Text(village.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVillage = value;
                    _gpsCtrl.text = buildWarehouseGpsLocation(
                      regionName: _selectedRegion?.name,
                      districtName: _selectedDistrict?.name,
                      wardName: _selectedWard?.name,
                      villageName: value?.name,
                    );
                  });
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildLocationDropdown<Amcos>(
                label: 'AMCOS',
                value: _selectedAmcos,
                streamBuilder: () => ref.read(amcosDaoProvider).watchAllAmcos(),
                itemBuilder: (amcosList) => amcosList
                    .map(
                      (amcos) => DropdownMenuItem<Amcos>(
                        value: amcos,
                        child: Text(amcos.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedAmcos = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gpsCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'GPS location / address',
                  hintText:
                      'Auto-built from region, district, ward and village',
                ),
              ),
              const SizedBox(height: 24),
              _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Create Warehouse'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
