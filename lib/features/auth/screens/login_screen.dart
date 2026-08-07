// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/repositories/auth_repository.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';

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
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Stack(
                children: [
                  const _LoginHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 206, 24, 28),
                    child: Column(
                      children: [
                        _LoginCard(
                          formKey: _formKey,
                          emailCtrl: _emailCtrl,
                          passCtrl: _passCtrl,
                          obscure: _obscure,
                          loading: _loading,
                          error: error,
                          l10n: l10n,
                          onTogglePassword: () =>
                              setState(() => _obscure = !_obscure),
                          onSubmit: _submit,
                          onForgotPassword: _showForgotPasswordSheet,
                          localizeError: (errorKey) =>
                              _localizeError(context, errorKey),
                        ),
                        const SizedBox(height: 70),
                        const _RegisterPrompt(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(parentContext: context),
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

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ClipPath(
      clipper: _HeaderWaveClipper(),
      child: Container(
        width: double.infinity,
        height: 310,
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 58),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(
                      'assets/logo/warehouse_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.warehouse_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'MavunoHub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.signInTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final bool loading;
  final String? error;
  final AppLocalizations l10n;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final String Function(String?) localizeError;

  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.l10n,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.localizeError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: AppColors.divider),
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Welcome Back',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 26),
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
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
                        localizeError(error),
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.emailAddress,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.validationEmailRequired;
                }
                if (!value.contains('@')) {
                  return l10n.validationEmailInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passCtrl,
              keyboardType: TextInputType.visiblePassword,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.password,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: onTogglePassword,
                  tooltip: obscure ? 'Show password' : 'Hide password',
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.validationPasswordRequired;
                }
                if (value.length < 6) {
                  return l10n.validationPasswordTooShort;
                }
                return null;
              },
              onFieldSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 22),
            loading
                ? const SizedBox(
                    height: 52,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: onSubmit,
                    child: Text(l10n.signIn),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: loading ? null : onForgotPassword,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  final BuildContext parentContext;

  const _ForgotPasswordSheet({required this.parentContext});

  @override
  ConsumerState<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    showCenteredLoadingDialog(
      context,
      title: 'Sending Instructions',
      description: 'Checking this email address.',
    );

    final result = await ref.read(authRepositoryProvider).forgotPassword(
          email: _emailCtrl.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.error ?? 'Failed to send reset email.');
      return;
    }

    Navigator.pop(context);
    if (!widget.parentContext.mounted) return;
    final resetNow = await showAppFeedbackDialog<bool>(
      widget.parentContext,
      title: 'Check Your Email',
      description: result.message ??
          'Password reset instructions have been sent to your email.',
      type: AppFeedbackType.success,
      actions: const [
        AppFeedbackAction<bool>(label: 'OK', result: false),
        AppFeedbackAction<bool>(
          label: 'Reset Password',
          result: true,
          isPrimary: true,
        ),
      ],
    );
    if (resetNow == true && widget.parentContext.mounted) {
      showModalBottomSheet(
        context: widget.parentContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            _ResetPasswordSheet(parentContext: widget.parentContext),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthSheetFrame(
      title: 'Forgot Password',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              _AuthErrorBox(message: _error!),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                return value.contains('@') ? null : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: const Text('Send Instructions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetPasswordSheet extends ConsumerStatefulWidget {
  final BuildContext parentContext;

  const _ResetPasswordSheet({required this.parentContext});

  @override
  ConsumerState<_ResetPasswordSheet> createState() =>
      _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends ConsumerState<_ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    showCenteredLoadingDialog(
      context,
      title: 'Resetting Password',
      description: 'Saving your new password.',
    );

    final result = await ref.read(authRepositoryProvider).resetPassword(
          token: _tokenCtrl.text.trim(),
          newPassword: _passwordCtrl.text,
        );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.error ?? 'Failed to reset password.');
      return;
    }

    Navigator.pop(context);
    if (widget.parentContext.mounted) {
      await showCreationSuccessDialog(
        widget.parentContext,
        title: 'Password Reset',
        description: result.message ?? 'Password has been reset successfully.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthSheetFrame(
      title: 'Reset Password',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              _AuthErrorBox(message: _error!),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _tokenCtrl,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Reset token',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            _ResetPasswordField(
              controller: _passwordCtrl,
              label: 'New password',
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 14),
            _ResetPasswordField(
              controller: _confirmCtrl,
              label: 'Confirm password',
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (value != _passwordCtrl.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthSheetFrame extends StatelessWidget {
  final String title;
  final Widget child;

  const _AuthSheetFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
      child: SingleChildScrollView(
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
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResetPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _ResetPasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) return 'Required';
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
    );
  }
}

class _AuthErrorBox extends StatelessWidget {
  final String message;

  const _AuthErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          "Don't have an Account",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: () => context.push('/register'),
          child: const Text(
            'Register',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 34)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 30,
        size.width,
        size.height - 34,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
