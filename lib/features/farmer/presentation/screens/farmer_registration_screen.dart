import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/components/app_stepper.dart';
import 'package:warehouse_app/core/components/input_field.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_dependant_model.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_model.dart';
import 'package:warehouse_app/features/farmer/presentation/widgets/dependant_form.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import 'package:warehouse_app/l10n/localized_values.dart';

const kFarmerSexValues = ['MALE', 'FEMALE'];
const kFarmerIdTypes = ['VOTER', 'NIN', 'OTHER'];
const kFarmerMemberTypes = ['MEMBER', 'NON_MEMBER'];
const kFarmerMaritalStatuses = ['SINGLE', 'MARRIED'];

class FarmerRegistrationScreen extends ConsumerStatefulWidget {
  final String returnRoute;

  const FarmerRegistrationScreen({
    super.key,
    this.returnRoute = '/worker/farmers',
  });

  @override
  ConsumerState<FarmerRegistrationScreen> createState() =>
      _FarmerRegistrationScreenState();
}

class _FarmerRegistrationScreenState
    extends ConsumerState<FarmerRegistrationScreen> {
  final _farmerFormKey = GlobalKey<FormState>();
  final _stepperKey = GlobalKey<AppStepperState>();

  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _tumeCtrl = TextEditingController();
  final _amcosMemberCtrl = TextEditingController();
  final _ttbCtrl = TextEditingController();
  final _tinCtrl = TextEditingController();
  final _voterCtrl = TextEditingController();
  final _driversLicenseCtrl = TextEditingController();
  final _sharesCtrl = TextEditingController();

  String _sex = kFarmerSexValues.first;
  String _idType = 'NIN';
  String _memberType = kFarmerMemberTypes.first;
  String _maritalStatus = kFarmerMaritalStatuses.first;
  Crop? _mainCrop;
  Crop? _secondaryCrop;
  Amcos? _selectedAmcos;
  final _dependants = <FarmerDependantInput>[];
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _idNumberCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    _tumeCtrl.dispose();
    _amcosMemberCtrl.dispose();
    _ttbCtrl.dispose();
    _tinCtrl.dispose();
    _voterCtrl.dispose();
    _driversLicenseCtrl.dispose();
    _sharesCtrl.dispose();
    super.dispose();
  }

  bool _validateFarmerStep() {
    final formOk = _farmerFormKey.currentState?.validate() ?? true;
    setState(() => _submitError = null);
    return formOk;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_validateFarmerStep()) {
      _stepperKey.currentState?.goToStep(0);
      return;
    }

    final confirmed = await showCreationConfirmDialog(
      context,
      title: l10n.createFarmer,
      description: l10n.createFarmerConfirm,
      confirmLabel: l10n.create,
    );
    if (!confirmed) return;
    if (!mounted) return;

    final mcuId = await _deriveMcuId();
    if (!mounted) return;
    if (mcuId == null) {
      setState(() {
        _submitError = l10n.workerMcuUnavailable;
      });
      _stepperKey.currentState?.goToStep(2);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    showCenteredLoadingDialog(
      context,
      title: l10n.creatingFarmer,
      description: l10n.savingFarmerLocally,
    );

    final result = await ref.read(farmerRepoProvider).createFarmer(
          farmer: FarmerCreateInput(
            firstName: _firstNameCtrl.text.trim(),
            middleName: _nullable(_middleNameCtrl.text),
            lastName: _lastNameCtrl.text.trim(),
            sex: _sex,
            idType: _idType,
            idNumber: _idNumberCtrl.text.trim(),
            dob: _dobCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            tumeNumber: _nullable(_tumeCtrl.text),
            amcosMemberID: _nullable(_amcosMemberCtrl.text),
            mainCrop: _mainCrop!.id,
            secondaryCrop: _secondaryCrop!.id,
            amcos: _selectedAmcos!.id,
            mcu: mcuId,
            memberType: _memberType,
            ttbNumber: _nullable(_ttbCtrl.text),
            tinNumber: _nullable(_tinCtrl.text),
            voterId: _nullable(_voterCtrl.text),
            driversLicense: _nullable(_driversLicenseCtrl.text),
            maritalStatus: _maritalStatus,
            noOfShares: double.tryParse(_sharesCtrl.text.trim()),
          ),
          dependants: _dependants,
        );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _submitting = false);

    if (!result.success) {
      setState(() => _submitError = result.error ?? l10n.createFarmerFailed);
      return;
    }

    ref.invalidate(allFarmersProvider);
    final dependantMessage = result.dependantErrors.isEmpty
        ? l10n.dependantsAdded(result.createdDependants)
        : l10n.someDependantsFailed(result.createdDependants);
    await showCreationSuccessDialog(
      context,
      title: l10n.farmerRegistered,
      description: l10n.farmerRegisteredMessage(dependantMessage),
    );
    if (!mounted) return;
    context.go(widget.returnRoute);
  }

  Future<int?> _deriveMcuId() async {
    return ref.read(currentUserMcuProvider.future);
  }

  Widget _buildFarmerStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cropsAsync = ref.watch(allCropsProvider);
    final crops = cropsAsync.valueOrNull ?? const <Crop>[];
    final amcosAsync = ref.watch(amcosDaoProvider).watchAllAmcos();

    return Form(
      key: _farmerFormKey,
      child: Column(
        children: [
          _errorBanner(),
          AppTextFormField(
            controller: _firstNameCtrl,
            labelText: l10n.firstName,
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            validator: _required,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _middleNameCtrl,
            labelText: optionalLabel(l10n.middleName),
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _lastNameCtrl,
            labelText: l10n.lastName,
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            validator: _required,
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            labelText: l10n.sex,
            icon: Icons.wc_rounded,
            value: _sex,
            items: kFarmerSexValues
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(localizedReferenceValue(l10n, item)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _sex = value!),
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            labelText: optionalLabel(l10n.idType),
            icon: Icons.badge_outlined,
            value: _idType,
            items: kFarmerIdTypes
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => _idType = value!),
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _idNumberCtrl,
            labelText: optionalLabel(l10n.idNumber),
            icon: Icons.numbers_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _dobCtrl,
            labelText: l10n.dateOfBirth,
            icon: Icons.calendar_today_outlined,
            hintText: 'YYYY-MM-DD',
            readOnly: true,
            onTap: () => _pickDate(_dobCtrl),
            suffixIcon: const Icon(Icons.calendar_month_outlined),
            validator: _date,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _phoneCtrl,
            labelText: l10n.phoneNumber,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: _required,
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<Crop>(
            labelText: l10n.mainCrop,
            icon: Icons.grass_outlined,
            value: _mainCrop,
            hintText: l10n.selectMainCrop,
            items: crops
                .map((crop) => DropdownMenuItem(
                      value: crop,
                      child: Text(crop.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _mainCrop = value),
            validator: (value) => value == null ? l10n.requiredField : null,
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<Crop>(
            labelText: l10n.secondaryCrop,
            icon: Icons.spa_outlined,
            value: _secondaryCrop,
            hintText: l10n.selectSecondaryCrop,
            items: crops
                .map((crop) => DropdownMenuItem(
                      value: crop,
                      child: Text(crop.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _secondaryCrop = value),
            validator: (value) {
              if (value == null) return l10n.requiredField;
              if (crops.length > 1 &&
                  _mainCrop != null &&
                  value.id == _mainCrop!.id) {
                return l10n.secondaryCropDifferent;
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<Amcos>>(
            stream: amcosAsync,
            builder: (context, snapshot) {
              final amcosList = snapshot.data ?? const <Amcos>[];
              return AppDropdownFormField<Amcos>(
                labelText: l10n.amcos,
                icon: Icons.account_tree_outlined,
                value: _selectedAmcos,
                hintText: l10n.selectAmcos,
                items: amcosList
                    .map((amcos) => DropdownMenuItem(
                          value: amcos,
                          child: Text(amcos.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedAmcos = value),
                validator: (value) => value == null ? l10n.requiredField : null,
              );
            },
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            labelText: optionalLabel(l10n.memberType),
            icon: Icons.groups_outlined,
            value: _memberType,
            items: kFarmerMemberTypes
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(localizedReferenceValue(l10n, item)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _memberType = value!),
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            labelText: optionalLabel(l10n.maritalStatus),
            icon: Icons.favorite_border_rounded,
            value: _maritalStatus,
            items: kFarmerMaritalStatuses
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(localizedReferenceValue(l10n, item)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _maritalStatus = value!),
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _amcosMemberCtrl,
            labelText: optionalLabel(l10n.amcosMemberId),
            icon: Icons.assignment_ind_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _tumeCtrl,
            labelText: optionalLabel(l10n.tumeNumber),
            icon: Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _ttbCtrl,
            labelText: optionalLabel(l10n.ttbNumber),
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _tinCtrl,
            labelText: optionalLabel(l10n.tinNumber),
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _voterCtrl,
            labelText: optionalLabel(l10n.voterId),
            icon: Icons.how_to_vote_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _driversLicenseCtrl,
            labelText: optionalLabel(l10n.driversLicense),
            icon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _sharesCtrl,
            labelText: optionalLabel(l10n.numberOfShares),
            icon: Icons.pie_chart_outline,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              return double.tryParse(value.trim()) == null
                  ? l10n.enterValidNumber
                  : null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDependantsStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dependants.isEmpty)
          EmptyState(
            icon: Icons.family_restroom_rounded,
            title: l10n.noDependantsAdded,
            subtitle: l10n.dependantsOptional,
          )
        else
          for (var i = 0; i < _dependants.length; i++) ...[
            _DependantTile(
              dependant: _dependants[i],
              onRemove: () => setState(() => _dependants.removeAt(i)),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showDependantSheet,
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.addDependant),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _errorBanner(),
        _reviewHeader(l10n.receiptFarmer),
        _reviewRow(l10n.name, _fullName),
        _reviewRow(l10n.sex, localizedReferenceValue(l10n, _sex)),
        _reviewRow(l10n.idType, _idType),
        _reviewRow(l10n.idNumber, _idNumberCtrl.text),
        _reviewRow(l10n.dateOfBirth, _dobCtrl.text),
        _reviewRow(l10n.phone, _phoneCtrl.text),
        _reviewRow(l10n.mainCrop, _mainCrop?.name ?? ''),
        _reviewRow(l10n.secondaryCrop, _secondaryCrop?.name ?? ''),
        _reviewRow(l10n.amcos, _selectedAmcos?.name ?? ''),
        _reviewRow(
          l10n.memberType,
          localizedReferenceValue(l10n, _memberType),
        ),
        _reviewRow(
          l10n.maritalStatus,
          localizedReferenceValue(l10n, _maritalStatus),
        ),
        _reviewRow(l10n.educationLevel, l10n.primaryEducation),
        const SizedBox(height: 14),
        _reviewHeader(l10n.dependants),
        _reviewRow(l10n.total, '${_dependants.length}'),
        if (_dependants.isNotEmpty)
          for (final dependant in _dependants)
            _reviewRow(
              localizedReferenceValue(l10n, dependant.relationship),
              [
                dependant.firstName,
                dependant.middleName,
                dependant.lastName,
              ].whereType<String>().where((v) => v.isNotEmpty).join(' '),
            ),
        if (_submitting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.registerFarmer)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: AppStepper(
            key: _stepperKey,
            completeLabel: l10n.createFarmer,
            onComplete: _submitting ? () {} : _submit,
            steps: [
              AppStep(
                title: l10n.farmerDetails,
                description: l10n.captureFarmerDescription,
                contentBuilder: _buildFarmerStep,
                validate: _validateFarmerStep,
              ),
              AppStep(
                title: l10n.dependants,
                description: l10n.addDependantsDescription,
                contentBuilder: _buildDependantsStep,
              ),
              AppStep(
                title: l10n.review,
                description: l10n.reviewFarmerDescription,
                contentBuilder: _buildReviewStep,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDependantSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DependantSheet(
        onSubmit: (dependant) {
          setState(() => _dependants.add(dependant));
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _errorBanner() {
    if (_submitError == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Text(
        _submitError!,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }

  Widget _reviewHeader(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
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

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? AppLocalizations.of(context)!.requiredField
        : null;
  }

  String? _date(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) return l10n.requiredField;
    final text = value.trim();
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return !datePattern.hasMatch(text) || DateTime.tryParse(text) == null
        ? l10n.useDateFormat
        : null;
  }

  String? _nullable(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initialDate = DateTime.tryParse(controller.text) ?? DateTime(2000);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    controller.text = _formatDate(selected);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String get _fullName {
    return [
      _firstNameCtrl.text,
      _middleNameCtrl.text,
      _lastNameCtrl.text,
    ].map((v) => v.trim()).where((v) => v.isNotEmpty).join(' ');
  }
}

class _DependantSheet extends StatelessWidget {
  final ValueChanged<FarmerDependantInput> onSubmit;

  const _DependantSheet({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            Text(
              l10n.addDependant,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            DependantForm(onSubmit: onSubmit),
          ],
        ),
      ),
    );
  }
}

class _DependantTile extends StatelessWidget {
  final FarmerDependantInput dependant;
  final VoidCallback onRemove;

  const _DependantTile({
    required this.dependant,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = [
      dependant.firstName,
      dependant.middleName,
      dependant.lastName,
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' ');

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.workerColor.withValues(alpha: 0.1),
            child:
                const Icon(Icons.person_outline, color: AppColors.workerColor),
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
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.error,
            tooltip: l10n.removeDependant,
          ),
        ],
      ),
    );
  }
}
