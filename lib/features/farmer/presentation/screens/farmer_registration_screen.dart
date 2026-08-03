import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    if (!_validateFarmerStep()) {
      _stepperKey.currentState?.goToStep(0);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Create Farmer',
      message: 'Confirm these details and create this farmer record?',
      confirmLabel: 'Create',
    );
    if (!confirmed) return;

    final mcuId = await _deriveMcuId();
    if (mcuId == null) {
      setState(() {
        _submitError =
            'Could not determine MCU for this worker. Please sync your profile or contact the owner.';
      });
      _stepperKey.currentState?.goToStep(2);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

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
    setState(() => _submitting = false);

    if (!result.success) {
      setState(() => _submitError = result.error ?? 'Failed to create farmer.');
      return;
    }

    ref.invalidate(allFarmersProvider);
    final dependantMessage = result.dependantErrors.isEmpty
        ? '${result.createdDependants} dependant(s) added.'
        : '${result.createdDependants} dependant(s) added. Some dependants failed.';
    final messenger = ScaffoldMessenger.of(context);
    context.go(widget.returnRoute);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Farmer created. $dependantMessage'),
        backgroundColor: result.dependantErrors.isEmpty
            ? AppColors.success
            : AppColors.warning,
      ),
    );
  }

  Future<int?> _deriveMcuId() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return null;
    final ownerMcuId = int.tryParse(currentUserId);
    if (ownerMcuId != null) return ownerMcuId;
    final worker = await ref.read(workerDaoProvider).getUserById(currentUserId);
    if (worker?.mcu != null) return worker!.mcu;
    final warehouseId = worker?.warehouseId;
    if (warehouseId == null) return null;
    final warehouse = await ref.read(warehouseDaoProvider).getWarehouseById(
          warehouseId,
        );
    return int.tryParse(warehouse?.ownerId ?? '');
  }

  Widget _buildFarmerStep(BuildContext context) {
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
            labelText: 'First name',
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            validator: _required,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _middleNameCtrl,
            labelText: 'Middle name',
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _lastNameCtrl,
            labelText: 'Last name',
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            validator: _required,
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            labelText: 'Sex',
            icon: Icons.wc_rounded,
            value: _sex,
            items: kFarmerSexValues
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => _sex = value!),
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            labelText: 'ID type',
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
            labelText: 'ID number',
            icon: Icons.numbers_outlined,
            validator: _required,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _dobCtrl,
            labelText: 'Date of birth',
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
            labelText: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: _required,
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<Crop>(
            labelText: 'Main crop',
            icon: Icons.grass_outlined,
            value: _mainCrop,
            hintText: 'Select main crop',
            items: crops
                .map((crop) => DropdownMenuItem(
                      value: crop,
                      child: Text(crop.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _mainCrop = value),
            validator: (value) => value == null ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<Crop>(
            labelText: 'Secondary crop',
            icon: Icons.spa_outlined,
            value: _secondaryCrop,
            hintText: 'Select secondary crop',
            items: crops
                .map((crop) => DropdownMenuItem(
                      value: crop,
                      child: Text(crop.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _secondaryCrop = value),
            validator: (value) {
              if (value == null) return 'Required';
              if (crops.length > 1 &&
                  _mainCrop != null &&
                  value.id == _mainCrop!.id) {
                return 'Secondary crop must be different from main crop';
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
                labelText: 'AMCOS',
                icon: Icons.account_tree_outlined,
                value: _selectedAmcos,
                hintText: 'Select AMCOS',
                items: amcosList
                    .map((amcos) => DropdownMenuItem(
                          value: amcos,
                          child: Text(amcos.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedAmcos = value),
                validator: (value) => value == null ? 'Required' : null,
              );
            },
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            labelText: 'Member type',
            icon: Icons.groups_outlined,
            value: _memberType,
            items: kFarmerMemberTypes
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => _memberType = value!),
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            labelText: 'Marital status',
            icon: Icons.favorite_border_rounded,
            value: _maritalStatus,
            items: kFarmerMaritalStatuses
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => _maritalStatus = value!),
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _amcosMemberCtrl,
            labelText: 'AMCOS member ID',
            icon: Icons.assignment_ind_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _tumeCtrl,
            labelText: 'TUME number',
            icon: Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _ttbCtrl,
            labelText: 'TTB number',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _tinCtrl,
            labelText: 'TIN number',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _voterCtrl,
            labelText: 'Voter ID',
            icon: Icons.how_to_vote_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _driversLicenseCtrl,
            labelText: 'Drivers license',
            icon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 14),
          AppTextFormField(
            controller: _sharesCtrl,
            labelText: 'Number of shares',
            icon: Icons.pie_chart_outline,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              return double.tryParse(value.trim()) == null
                  ? 'Enter a valid number'
                  : null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDependantsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dependants.isEmpty)
          const EmptyState(
            icon: Icons.family_restroom_rounded,
            title: 'No dependants added',
            subtitle:
                'This step is optional. Dependants can also be added later.',
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
          label: const Text('Add Dependant'),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _errorBanner(),
        _reviewHeader('Farmer'),
        _reviewRow('Name', _fullName),
        _reviewRow('Sex', _sex),
        _reviewRow('ID type', _idType),
        _reviewRow('ID number', _idNumberCtrl.text),
        _reviewRow('Date of birth', _dobCtrl.text),
        _reviewRow('Phone', _phoneCtrl.text),
        _reviewRow('Main crop', _mainCrop?.name ?? ''),
        _reviewRow('Secondary crop', _secondaryCrop?.name ?? ''),
        _reviewRow('AMCOS', _selectedAmcos?.name ?? ''),
        _reviewRow('Member type', _memberType),
        _reviewRow('Marital status', _maritalStatus),
        _reviewRow('Education level', 'PRIMARY'),
        const SizedBox(height: 14),
        _reviewHeader('Dependants'),
        _reviewRow('Total', '${_dependants.length}'),
        if (_dependants.isNotEmpty)
          for (final dependant in _dependants)
            _reviewRow(
              dependant.relationship,
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Register Farmer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: AppStepper(
            key: _stepperKey,
            completeLabel: 'Create Farmer',
            onComplete: _submitting ? () {} : _submit,
            steps: [
              AppStep(
                title: 'Farmer Details',
                description: 'Capture the farmer record at point of contact.',
                contentBuilder: _buildFarmerStep,
                validate: _validateFarmerStep,
              ),
              AppStep(
                title: 'Dependants',
                description: 'Add dependants now, or leave this for later.',
                contentBuilder: _buildDependantsStep,
              ),
              AppStep(
                title: 'Review',
                description: 'Confirm the details before creating the farmer.',
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
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _date(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final text = value.trim();
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return !datePattern.hasMatch(text) || DateTime.tryParse(text) == null
        ? 'Use YYYY-MM-DD'
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
                  '${dependant.relationship} · ${dependant.gender}',
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
            tooltip: 'Remove dependant',
          ),
        ],
      ),
    );
  }
}
