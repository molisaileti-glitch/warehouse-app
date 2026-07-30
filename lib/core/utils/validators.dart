// lib/core/utils/validators.dart

class Validators {
  static String? required(String? v, String message) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? v, {String requiredMessage = 'Enter an email'}) {
    if (v == null || v.isEmpty) return requiredMessage;
    if (!v.contains('@')) return 'Enter a valid email';
    return null;
  }
}