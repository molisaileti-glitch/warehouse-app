// lib/core/components/input_field.dart
//
// Shared outlined form fields with labels kept visible on the border.

import 'package:flutter/material.dart';

String optionalLabel(String label) => '$label (Optional)';

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
  final FloatingLabelBehavior? floatingLabelBehavior;
  final bool useFloatingLabel;

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
    this.floatingLabelBehavior,
    this.useFloatingLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!useFloatingLabel) ...[
          Text(
            labelText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autocorrect: autocorrect,
          textCapitalization: textCapitalization,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            labelText: useFloatingLabel ? labelText : null,
            hintText: hintText ?? (!useFloatingLabel ? labelText : null),
            floatingLabelBehavior: useFloatingLabel
                ? (floatingLabelBehavior ?? FloatingLabelBehavior.always)
                : null,
            prefixIcon: Icon(icon),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
        ),
      ],
    );
  }
}

/// Dropdown counterpart to [AppTextFormField] — same "label above, no
/// floating label" look, so business type / region selectors match the
/// text fields visually. Relies on the same global InputDecorationTheme
/// as AppTextFormField (no border colors hardcoded here on purpose).
class AppDropdownFormField<T> extends StatelessWidget {
  final String labelText;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final String? hintText;
  final FloatingLabelBehavior? floatingLabelBehavior;
  final bool useFloatingLabel;

  const AppDropdownFormField({
    super.key,
    required this.labelText,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.value,
    this.validator,
    this.hintText,
    this.floatingLabelBehavior,
    this.useFloatingLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!useFloatingLabel) ...[
          Text(
            labelText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: useFloatingLabel ? labelText : null,
            hintText: hintText ?? (!useFloatingLabel ? labelText : null),
            floatingLabelBehavior: useFloatingLabel
                ? (floatingLabelBehavior ?? FloatingLabelBehavior.always)
                : null,
            prefixIcon: Icon(icon),
          ),
          hint: hintText != null ? Text(hintText!) : null,
        ),
      ],
    );
  }
}
