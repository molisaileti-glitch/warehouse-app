// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/components/input_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(authProvider).valueOrNull?.error;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Logo
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.warehouse_rounded,
                      size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text('StockPilot',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5)),
              ),
              Center(
                child: Text(l10n.signInTitle,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 40),

              // Error banner
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_localizeError(context, error),
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextFormField(
  controller: _emailCtrl,
  labelText: l10n.emailAddress,
  icon: Icons.email_outlined,
  keyboardType: TextInputType.emailAddress,
  autocorrect: false,
  useFloatingLabel: true,
  floatingLabelBehavior: FloatingLabelBehavior.always,
  validator: (v) {
    if (v == null || v.isEmpty) {
      return l10n.validationEmailRequired;
    }
    if (!v.contains('@')) {
      return l10n.validationEmailInvalid;
    }
    return null;
  },
),

                    const SizedBox(height: 16),


                    AppTextFormField(
  controller: _passCtrl,
  labelText: l10n.password,
  icon: Icons.lock_outline_rounded,
  keyboardType: TextInputType.visiblePassword,
  obscureText: _obscure,
  useFloatingLabel: true,
  floatingLabelBehavior: FloatingLabelBehavior.always,
  suffixIcon: IconButton(
    icon: Icon(
      _obscure
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined,
    ),
    onPressed: () => setState(() => _obscure = !_obscure),
    tooltip: _obscure ? 'Show password' : 'Hide password',
  ),
  validator: (v) {
    if (v == null || v.isEmpty) {
      return l10n.validationPasswordRequired;
    }
    if (v.length < 6) {
      return l10n.validationPasswordTooShort;
    }
    return null;
  },
  onFieldSubmitted: (_) => _submit(),
),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Submit
              _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : ElevatedButton(
                      onPressed: _submit,
                      child: Text(l10n.signIn),
                    ),

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/register'),
                  child: Text(l10n.newOwnerPrompt,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 16),

              // Role hint
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.accessLevelHint,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localizeError(BuildContext context, String? errorKey) {
    if (errorKey == null) return '';
    final l10n = AppLocalizations.of(context)!;
    return switch (errorKey) {
      'errorInvalidDetails' => l10n.errorInvalidDetails,
      'errorIncorrectCredentials' => l10n.errorIncorrectCredentials,
      'errorAccountDisabled' => l10n.errorAccountDisabled,
      'errorEmailExists' => l10n.errorEmailExists,
      'errorTooManyAttempts' => l10n.errorTooManyAttempts,
      'errorNetworkError' => l10n.errorNetworkError,
      _ => errorKey,
    };
  }
}
