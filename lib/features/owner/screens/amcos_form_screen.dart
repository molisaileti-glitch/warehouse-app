import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/components/input_field.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/additional.data/amcos/presentation/providers/amcos_providers.dart';
import 'package:warehouse_app/features/additional.data/crop/presentation/providers/crop_providers.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class AmcosFormScreen extends ConsumerStatefulWidget {
  const AmcosFormScreen({super.key});

  @override
  ConsumerState<AmcosFormScreen> createState() => _AmcosFormScreenState();
}

class _AmcosFormScreenState extends ConsumerState<AmcosFormScreen> {
  static const _categories = [
    'FARMERS',
    'FISHERMAN',
    'LIVESTOCK_TRADERS',
    'LIVESTOCK_KEEPERS',
    'SUPPLIERS',
    'OTHER',
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _tinNumber = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _email = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _contactEmail = TextEditingController();
  final _contactTitle = TextEditingController();
  final _website = TextEditingController();

  String? _category;
  Crop? _crop;
  Region? _region;
  District? _district;
  Ward? _ward;
  Village? _village;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _registrationNumber.dispose();
    _tinNumber.dispose();
    _phoneNumber.dispose();
    _email.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _contactEmail.dispose();
    _contactTitle.dispose();
    _website.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.requiredField;
    }
    return null;
  }

  String _categoryLabel(String category, AppLocalizations l10n) {
    return switch (category) {
      'FARMERS' => l10n.farmers,
      'FISHERMAN' => l10n.fisherman,
      'LIVESTOCK_TRADERS' => l10n.livestockTraders,
      'LIVESTOCK_KEEPERS' => l10n.livestockKeepers,
      'SUPPLIERS' => l10n.suppliers,
      _ => l10n.other,
    };
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_crop == null ||
        _region == null ||
        _district == null ||
        _ward == null ||
        _village == null) {
      await showErrorDialog(
        context,
        title: l10n.createAmcos,
        description: l10n.requiredField,
        actionLabel: l10n.ok,
      );
      return;
    }

    final mcuId = await ref.read(currentUserMcuProvider.future);
    if (!mounted) return;
    if (mcuId == null) {
      await showErrorDialog(
        context,
        title: l10n.createAmcos,
        description: l10n.errorMissingMcuAssignment,
        actionLabel: l10n.ok,
      );
      return;
    }

    final confirmed = await showCreationConfirmDialog(
      context,
      title: l10n.createAmcos,
      description: l10n.createAmcosConfirm(_name.text.trim()),
      confirmLabel: l10n.create,
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    showCenteredLoadingDialog(
      context,
      title: l10n.creatingAmcos,
      description: l10n.savingAmcos,
    );

    final result = await ref.read(amcosRepositoryProvider).create(
          name: _name.text.trim(),
          memberCategory: _category!,
          registrationNumber: _registrationNumber.text.trim(),
          tinNumber: _tinNumber.text.trim(),
          mcuId: mcuId,
          mcuName: '', // server resolves the real MCU name on pull
          regionId: _region!.id,
          regionName: _region!.name,
          districtId: _district!.id,
          districtName: _district!.name,
          wardId: _ward!.id,
          wardName: _ward!.name,
          villageId: _village!.id,
          villageName: _village!.name,
          phoneNumber: _phoneNumber.text.trim(),
          email: _email.text.trim(),
          contactPersonName: _contactName.text.trim(),
          contactPersonPhoneNumber: _contactPhone.text.trim(),
          contactPersonEmail: _contactEmail.text.trim(),
          contactPersonTitle: _contactTitle.text.trim(),
          website: _website.text.trim(),
          cropId: _crop!.id,
        );

    if (!mounted) return;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    setState(() => _submitting = false);

    if (!result.success) {
      await showErrorDialog(
        context,
        title: l10n.createAmcos,
        description: result.error ?? l10n.errorNetworkError,
        actionLabel: l10n.ok,
      );
      return;
    }

    await showCreationSuccessDialog(
      context,
      title: l10n.amcosCreated,
      description: l10n.amcosCreatedSuccess,
    );
    if (mounted) context.pop();
  }

  Widget _locationDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required Stream<List<T>> stream,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) => AppDropdownFormField<T>(
        labelText: label,
        icon: icon,
        value: value,
        items: (snapshot.data ?? <T>[])
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
        validator: (selected) => selected == null
            ? AppLocalizations.of(context)!.requiredField
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final crops = ref.watch(allCropsProvider).valueOrNull ?? const <Crop>[];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.createAmcos)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              AppTextFormField(
                controller: _name,
                labelText: l10n.amcosName,
                icon: Icons.groups_2_outlined,
                validator: _required,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              AppDropdownFormField<String>(
                labelText: l10n.memberCategory,
                icon: Icons.category_outlined,
                value: _category,
                hintText: l10n.selectMemberCategory,
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(_categoryLabel(category, l10n)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value),
                validator: (value) => value == null ? l10n.requiredField : null,
              ),
              const SizedBox(height: 14),
              AppTextFormField(
                controller: _registrationNumber,
                labelText: l10n.registrationNumber,
                icon: Icons.numbers_outlined,
                validator: _required,
              ),
              const SizedBox(height: 14),
              AppTextFormField(
                controller: _tinNumber,
                labelText: l10n.tinNumber,
                icon: Icons.badge_outlined,
                validator: _required,
              ),
              const SizedBox(height: 14),
              AppDropdownFormField<Crop>(
                labelText: l10n.crop,
                icon: Icons.agriculture_outlined,
                value: _crop,
                hintText: l10n.selectCrop,
                items: crops
                    .map(
                      (crop) => DropdownMenuItem(
                        value: crop,
                        child: Text(crop.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _crop = value),
                validator: (value) => value == null ? l10n.requiredField : null,
              ),
              const SizedBox(height: 20),
              _locationDropdown<Region>(
                label: l10n.region,
                icon: Icons.map_outlined,
                value: _region,
                stream: ref.read(regionDaoProvider).watchAllRegions(),
                itemLabel: (item) => item.name,
                onChanged: (value) => setState(() {
                  _region = value;
                  _district = null;
                  _ward = null;
                  _village = null;
                }),
              ),
              const SizedBox(height: 14),
              _locationDropdown<District>(
                label: l10n.district,
                icon: Icons.location_city_outlined,
                value: _district,
                stream: _region == null
                    ? Stream.value(const <District>[])
                    : ref
                        .read(districtDaoProvider)
                        .watchDistrictsByRegion(_region!.id),
                itemLabel: (item) => item.name,
                onChanged: (value) => setState(() {
                  _district = value;
                  _ward = null;
                  _village = null;
                }),
              ),
              const SizedBox(height: 14),
              _locationDropdown<Ward>(
                label: l10n.ward,
                icon: Icons.location_on_outlined,
                value: _ward,
                stream: _district == null
                    ? Stream.value(const <Ward>[])
                    : ref
                        .read(wardDaoProvider)
                        .watchWardsByDistrict(_district!.id),
                itemLabel: (item) => item.name,
                onChanged: (value) => setState(() {
                  _ward = value;
                  _village = null;
                }),
              ),
              const SizedBox(height: 14),
              _locationDropdown<Village>(
                label: l10n.village,
                icon: Icons.home_work_outlined,
                value: _village,
                stream: _ward == null
                    ? Stream.value(const <Village>[])
                    : ref
                        .read(villageDaoProvider)
                        .watchVillagesByWard(_ward!.id),
                itemLabel: (item) => item.name,
                onChanged: (value) => setState(() => _village = value),
              ),
              const SizedBox(height: 20),
              AppTextFormField(
                controller: _phoneNumber,
                labelText: l10n.phoneNumber,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: _required,
              ),
              const SizedBox(height: 14),
              AppTextFormField(
                controller: _email,
                labelText: l10n.businessEmail,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: _required,
              ),
              const SizedBox(height: 14),
              AppTextFormField(
                controller: _website,
                labelText: l10n.website,
                icon: Icons.language_outlined,
                keyboardType: TextInputType.url,
                validator: _required,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.contactPerson,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              AppTextFormField(
                controller: _contactName,
                labelText: l10n.contactName,
                icon: Icons.person_outline_rounded,
                validator: _required,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              AppTextFormField(
                controller: _contactPhone,
                labelText: l10n.contactPhone,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: _required,
              ),
              const SizedBox(height: 14),
              AppTextFormField(
                controller: _contactEmail,
                labelText: l10n.contactEmail,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: _required,
              ),
              const SizedBox(height: 14),
              AppTextFormField(
                controller: _contactTitle,
                labelText: l10n.contactTitle,
                icon: Icons.work_outline_rounded,
                validator: _required,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(l10n.createAmcos),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
