import 'package:flutter/material.dart';
import 'package:warehouse_app/core/components/input_field.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_dependant_model.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import 'package:warehouse_app/l10n/localized_values.dart';

const kDependantRelationships = [
  'FATHER',
  'MOTHER',
  'SPOUSE',
  'CHILD',
  'BROTHER',
  'SISTER',
  'OTHER',
];

class DependantForm extends StatefulWidget {
  final FarmerDependantInput? initialValue;
  final ValueChanged<FarmerDependantInput> onSubmit;
  final String? submitLabel;

  const DependantForm({
    super.key,
    this.initialValue,
    required this.onSubmit,
    this.submitLabel,
  });

  @override
  State<DependantForm> createState() => _DependantFormState();
}

class _DependantFormState extends State<DependantForm> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameCtrl =
      TextEditingController(text: widget.initialValue?.firstName ?? '');
  late final _middleNameCtrl =
      TextEditingController(text: widget.initialValue?.middleName ?? '');
  late final _lastNameCtrl =
      TextEditingController(text: widget.initialValue?.lastName ?? '');
  late final _emailCtrl =
      TextEditingController(text: widget.initialValue?.email ?? '');
  late final _addressCtrl =
      TextEditingController(text: widget.initialValue?.address ?? '');
  late final _phoneCtrl =
      TextEditingController(text: widget.initialValue?.phoneNumber ?? '');
  late final _dobCtrl =
      TextEditingController(text: widget.initialValue?.dob ?? '');

  late String _relationship =
      widget.initialValue?.relationship ?? kDependantRelationships.first;
  late String _gender = widget.initialValue?.gender ?? 'MALE';

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(
      FarmerDependantInput(
        firstName: _firstNameCtrl.text.trim(),
        middleName: _nullable(_middleNameCtrl.text),
        lastName: _lastNameCtrl.text.trim(),
        relationship: _relationship,
        gender: _gender,
        email: _nullable(_emailCtrl.text),
        address: _nullable(_addressCtrl.text),
        phoneNumber: _nullable(_phoneCtrl.text),
        dob: _dobCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextFormField(
              controller: _firstNameCtrl,
              labelText: l10n.firstName,
              icon: Icons.person_outline,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              textCapitalization: TextCapitalization.words,
              validator: _required,
            ),
            const SizedBox(height: 14),
            AppTextFormField(
              controller: _middleNameCtrl,
              labelText: l10n.middleName,
              icon: Icons.person_outline,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              textCapitalization: TextCapitalization.words,
              validator: _required,
            ),
            const SizedBox(height: 14),
            AppTextFormField(
              controller: _lastNameCtrl,
              labelText: l10n.lastName,
              icon: Icons.person_outline,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              textCapitalization: TextCapitalization.words,
              validator: _required,
            ),
            const SizedBox(height: 14),
            AppDropdownFormField<String>(
              labelText: l10n.relationship,
              icon: Icons.family_restroom_rounded,
              value: _relationship,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              items: kDependantRelationships
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(localizedReferenceValue(l10n, item)),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _relationship = value!),
            ),
            const SizedBox(height: 14),
            AppDropdownFormField<String>(
              labelText: l10n.gender,
              icon: Icons.wc_rounded,
              value: _gender,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              items: [
                DropdownMenuItem(
                  value: 'MALE',
                  child: Text(l10n.male),
                ),
                DropdownMenuItem(
                  value: 'FEMALE',
                  child: Text(l10n.female),
                ),
              ],
              onChanged: (value) => setState(() => _gender = value!),
            ),
            const SizedBox(height: 14),
            AppTextFormField(
              controller: _dobCtrl,
              labelText: l10n.dateOfBirth,
              icon: Icons.calendar_today_outlined,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: 'YYYY-MM-DD',
              readOnly: true,
              onTap: () => _pickDate(_dobCtrl),
              suffixIcon: const Icon(Icons.calendar_month_outlined),
              validator: _date,
            ),
            const SizedBox(height: 14),
            AppTextFormField(
              controller: _phoneCtrl,
              labelText: optionalLabel(l10n.phoneNumber),
              icon: Icons.phone_outlined,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            AppTextFormField(
              controller: _emailCtrl,
              labelText: optionalLabel(l10n.emailAddress),
              icon: Icons.email_outlined,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return value.contains('@') ? null : l10n.validationEmailInvalid;
              },
            ),
            const SizedBox(height: 14),
            AppTextFormField(
              controller: _addressCtrl,
              labelText: optionalLabel(l10n.address),
              icon: Icons.location_on_outlined,
              useFloatingLabel: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded),
              label: Text(widget.submitLabel ?? l10n.addDependant),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.workerColor),
            ),
          ],
        ),
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
}
