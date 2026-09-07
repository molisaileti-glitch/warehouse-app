// lib/core/components/input_field.dart
//
// Shared outlined form fields with labels above the field.

import 'package:flutter/material.dart';

String optionalLabel(String label) => '$label (Optional)';

class AppLabeledField extends StatelessWidget {
  final String labelText;
  final Widget child;

  const AppLabeledField({
    super.key,
    required this.labelText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class AppTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  const AppTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
    this.hintText,
    this.validator,
    this.onFieldSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );

    return AppLabeledField(labelText: labelText, child: field);
  }
}

/// Dropdown counterpart to [AppTextFormField].
class AppDropdownFormField<T> extends StatelessWidget {
  final String labelText;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final String? hintText;

  const AppDropdownFormField({
    super.key,
    required this.labelText,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.value,
    this.validator,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
      ),
    );

    return AppLabeledField(labelText: labelText, child: field);
  }
}
