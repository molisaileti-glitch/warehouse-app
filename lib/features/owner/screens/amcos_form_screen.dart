import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/components/app_stepper.dart';
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

  final _detailsFormKey = GlobalKey<FormState>();
  final _contactFormKey = GlobalKey<FormState>();
  final _stepperKey = GlobalKey<AppStepperState>();
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
  String? _detailsError;

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

  bool _validateAmcosDetailsStep() {
    final l10n = AppLocalizations.of(context)!;
    final missingRequiredDetails = _name.text.trim().isEmpty ||
        _category == null ||
        _crop == null ||
        _registrationNumber.text.trim().isEmpty ||
        _phoneNumber.text.trim().isEmpty;
    if (missingRequiredDetails) {
      setState(() => _detailsError = l10n.requiredField);
      return false;
    }

    final formOk = _detailsFormKey.currentState?.validate() ?? true;
    if (!formOk) return false;
    if (_email.text.trim().isNotEmpty && !_email.text.contains('@')) {
      setState(() => _detailsError = l10n.validationEmailInvalid);
      return false;
    }
    if (_region == null ||
        _district == null ||
        _ward == null ||
        _village == null) {
      setState(() => _detailsError = l10n.requiredField);
      return false;
    }
    setState(() => _detailsError = null);
    return true;
  }

  bool _validateContactStep() {
    return _contactFormKey.currentState?.validate() ?? true;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context)!;
    if (!_validateAmcosDetailsStep()) {
      _stepperKey.currentState?.goToStep(0);
      return;
    }
    if (!_validateContactStep()) {
      _stepperKey.currentState?.goToStep(1);
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
          memberCategory: _category ?? '',
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
          cropId: _crop?.id,
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

  Widget _detailsErrorBanner() {
    if (_detailsError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _detailsError!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmcosDetailsStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final crops = ref.watch(allCropsProvider).valueOrNull ?? const <Crop>[];

    return Form(
      key: _detailsFormKey,
      child: Column(
        children: [
          _detailsErrorBanner(),
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
            validator: (value) =>
                value == null ? l10n.selectMemberCategory : null,
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
            labelText: optionalLabel(l10n.tinNumber, l10n.optional),
            icon: Icons.badge_outlined,
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
            validator: (value) => value == null ? l10n.selectCrop : null,
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
                : ref.read(wardDaoProvider).watchWardsByDistrict(_district!.id),
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
                : ref.read(villageDaoProvider).watchVillagesByWard(_ward!.id),
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
            labelText: optionalLabel(l10n.businessEmail, l10n.optional),
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              return value.contains('@') ? null : l10n.validationEmailInvalid;
            },
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _website,
            labelText: optionalLabel(l10n.website, l10n.optional),
            icon: Icons.language_outlined,
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }

  Widget _buildContactPersonStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _contactFormKey,
      child: Column(
        children: [
          AppTextFormField(
            controller: _contactName,
            labelText: optionalLabel(l10n.contactName, l10n.optional),
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _contactPhone,
            labelText: optionalLabel(l10n.contactPhone, l10n.optional),
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _contactEmail,
            labelText: optionalLabel(l10n.contactEmail, l10n.optional),
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              return value.contains('@') ? null : l10n.validationEmailInvalid;
            },
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _contactTitle,
            labelText: optionalLabel(l10n.contactTitle, l10n.optional),
            icon: Icons.work_outline_rounded,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.createAmcos)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            children: [
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppColors.primary,
                        ),
                  ),
                  child: AppStepper(
                    key: _stepperKey,
                    completeLabel: l10n.createAmcos,
                    onComplete: _submit,
                    steps: [
                      AppStep(
                        title: l10n.amcos,
                        description: l10n.businessInfoDescription,
                        contentBuilder: _buildAmcosDetailsStep,
                        validate: _validateAmcosDetailsStep,
                      ),
                      AppStep(
                        title: l10n.contactPerson,
                        description: l10n.contactPersonDescription,
                        contentBuilder: _buildContactPersonStep,
                        validate: _validateContactStep,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
