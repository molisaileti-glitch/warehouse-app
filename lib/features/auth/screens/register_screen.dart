// lib/features/auth/screens/register_screen.dart
//
// Owner registration screen.
// Submits to POST {{API_URL}}/mcus
// Region list is fetched from GET {{API_URL}}/regions
//
// Uses AppStepper for a 3-step flow: Business Info -> Contact Person -> Review.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../../core/components/app_feedback.dart';
import '../../../core/components/input_field.dart';
import '../../../core/components/app_stepper.dart';
import '../../../core/repositories/auth_repository.dart' as auth_repo;
import '../../../features/shared/widgets/common_widgets.dart';

/// TODO: replace with the real list once the backend dev confirms it.
/// Placeholder values only.
const List<String> kBusinessTypes = [
  'AGRICULTURAL',
  'RETAIL',
  'MANUFACTURING',
  'LOGISTICS',
  'WHOLESALE',
  'OTHER',
];

class Region {
  final int id;
  final String name;
  final String postCode;

  Region({required this.id, required this.name, required this.postCode});

  factory Region.fromJsonToModel(dynamic json) {
    final map = _flattenRegionJson(json);
    return Region(
      id: _readInt(map, const ['id', 'regionId', 'region_id']),
      name: _readString(map, const ['name', 'regionName', 'title', 'label']),
      postCode: _readString(map,
          const ['postCode', 'postcode', 'postalCode', 'code', 'regionCode']),
    );
  }
}

Map<String, dynamic> _flattenRegionJson(dynamic json) {
  if (json is Map<String, dynamic>) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return {...json, ...data};
    }

    final attributes = json['attributes'];
    if (attributes is Map<String, dynamic>) {
      return {...json, ...attributes};
    }

    return json;
  }

  return const {};
}

int _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is int) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

String _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
  }
  return '';
}

List<Region> parseRegionsPayload(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    final data =
        responseData['records'] ?? responseData['data'] ?? responseData;
    if (data is List) {
      return data
          .map(Region.fromJsonToModel)
          .where((region) => region.id > 0 && region.name.isNotEmpty)
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final region = Region.fromJsonToModel(data);
      return region.id > 0 && region.name.isNotEmpty ? [region] : [];
    }
  }

  if (responseData is List) {
    return responseData
        .map(Region.fromJsonToModel)
        .where((region) => region.id > 0 && region.name.isNotEmpty)
        .toList();
  }

  return [];
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Separate form keys per step so we only validate the fields on screen.
  final _businessFormKey = GlobalKey<FormState>();
  final _contactFormKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _registrationNumberCtrl = TextEditingController();
  final _phoneNumberCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _tinNumberCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _contactPersonNameCtrl = TextEditingController();
  final _contactPersonPhoneNumberCtrl = TextEditingController();
  final _contactPersonEmailCtrl = TextEditingController();
  final _contactPersonTitleCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedType = kBusinessTypes.first;
  Region? _selectedRegion;

  List<Region> _regions = [];
  bool _loadingRegions = true;
  String? _regionsError;

  bool _submitting = false;
  String? _submitError;
  bool _regionsLoadingDialogVisible = false;
  bool _initialRegionsLoadStarted = false;
  bool _obscurePassword = true;

  final _stepperKey = GlobalKey<AppStepperState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialRegionsLoadStarted) return;
    _initialRegionsLoadStarted = true;
    _fetchRegions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _registrationNumberCtrl.dispose();
    _phoneNumberCtrl.dispose();
    _emailCtrl.dispose();
    _tinNumberCtrl.dispose();
    _websiteCtrl.dispose();
    _contactPersonNameCtrl.dispose();
    _contactPersonPhoneNumberCtrl.dispose();
    _contactPersonEmailCtrl.dispose();
    _contactPersonTitleCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRegions() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingRegions = true;
      _regionsError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_loadingRegions || _regionsLoadingDialogVisible) return;
      _regionsLoadingDialogVisible = true;
      showLoadingDialog(
        context,
        title: l10n.loadingTitle,
        description: l10n.loadingDescription,
      ).whenComplete(() {
        _regionsLoadingDialogVisible = false;
      });
    });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.get('/regions');
      final regions = parseRegionsPayload(response.data);
      if (!mounted) return;
      if (regions.isEmpty) {
        setState(() {
          _regions = [];
          _regionsError = AppLocalizations.of(context)!.noValidRegions;
          _loadingRegions = false;
        });
        if (_regionsLoadingDialogVisible &&
            Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        return;
      }
      setState(() {
        _regions = regions;
        _loadingRegions = false;
      });
      if (_regionsLoadingDialogVisible &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _regionsError =
            '${AppLocalizations.of(context)!.couldNotLoadRegions}: ${e.message}';
        _loadingRegions = false;
      });
      if (_regionsLoadingDialogVisible &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  bool _validateBusinessStep() {
    final formOk = _businessFormKey.currentState?.validate() ?? false;
    if (!formOk) return false;
    if (_selectedRegion == null) {
      setState(
          () => _submitError = AppLocalizations.of(context)!.selectRegionError);
      return false;
    }
    setState(() => _submitError = null);
    return true;
  }

  bool _validateContactStep() {
    return _contactFormKey.currentState?.validate() ?? false;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showCreationConfirmDialog(
      context,
      title: l10n.registrationConfirmTitle,
      description: l10n.registrationConfirmMessage,
      confirmLabel: l10n.confirm,
    );
    if (!confirmed || !mounted) return;

    final body = {
      'name': _nameCtrl.text.trim(),
      'type': _selectedType,
      'region': _selectedRegion!.id,
      'regionName': _selectedRegion!.name,
      'address': _addressCtrl.text.trim(),
      'registrationNumber': _registrationNumberCtrl.text.trim(),
      'phoneNumber': _phoneNumberCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'tinNumber': _tinNumberCtrl.text.trim(),
      'website': _websiteCtrl.text.trim(),
      'contactPersonName': _contactPersonNameCtrl.text.trim(),
      'contactPersonPhoneNumber': _contactPersonPhoneNumberCtrl.text.trim(),
      'contactPersonEmail': _contactPersonEmailCtrl.text.trim(),
      'contactPersonTitle': _contactPersonTitleCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'status': 'ACTIVE',
    };

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    showCenteredLoadingDialog(
      context,
      title: l10n.loadingTitle,
      description: l10n.loadingDescription,
    );

    String? failureMessage;

    try {
      final result =
          await ref.read(auth_repo.authRepositoryProvider).register(body);
      if (!result.success) {
        failureMessage = _localizeAuthError(l10n, result.error);
        if (mounted) {
          setState(() => _submitError = result.error);
        }
      } else {
        try {
          await ref.read(auth_repo.authRepositoryProvider).logout();
        } catch (_) {
          // Best-effort cleanup; the registration itself already succeeded.
        }
      }
    } catch (e) {
      failureMessage = e.toString();
      if (mounted) {
        setState(() => _submitError = failureMessage);
      }
    } finally {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => _submitting = false);
    }

    if (!mounted) return;

    if (failureMessage != null) {
      await showErrorDialog(
        context,
        title: l10n.registrationErrorTitle,
        description: '${l10n.registrationErrorMessage}\n\n$failureMessage',
        actionLabel: l10n.ok,
      );
      return;
    }

    await showCreationSuccessDialog(
      context,
      title: l10n.registrationSuccessTitle,
      description: l10n.registrationSuccessMessage,
      actionLabel: l10n.ok,
    );
    if (mounted) context.go(AppRoutes.login);
  }

  Widget _errorBanner() {
    if (_submitError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_submitError!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13))),
        ]),
      ),
    );
  }

  String _localizeAuthError(AppLocalizations l10n, String? errorKey) {
    if (errorKey == null) return l10n.registrationErrorMessage;
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

  Widget _buildBusinessStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _businessFormKey,
      child: Column(
        children: [
          AppTextFormField(
            controller: _nameCtrl,
            labelText: l10n.businessName,
            icon: Icons.storefront_outlined,
            hintText: l10n.enterBusinessName,
            validator: (v) => Validators.required(v, l10n.enterBusinessName),
          ),
          const SizedBox(height: 16),
          AppDropdownFormField<String>(
            labelText: l10n.businessType,
            icon: Icons.category_outlined,
            value: _selectedType,
            hintText: l10n.selectBusinessType,
            items: kBusinessTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 16),
          AppDropdownFormField<Region>(
            labelText: l10n.region,
            icon: Icons.map_outlined,
            value: _selectedRegion,
            hintText: l10n.selectRegion,
            items: _regions
                .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedRegion = v),
            validator: (v) => v == null ? l10n.selectRegionError : null,
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _addressCtrl,
            labelText: l10n.address,
            icon: Icons.location_on_outlined,
            hintText: l10n.enterAddress,
            validator: (v) => Validators.required(v, l10n.enterAddress),
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _registrationNumberCtrl,
            labelText: l10n.registrationNumber,
            icon: Icons.numbers_outlined,
            hintText: l10n.enterRegistrationNumber,
            validator: (v) =>
                Validators.required(v, l10n.enterRegistrationNumber),
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _phoneNumberCtrl,
            labelText: l10n.phoneNumber,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            hintText: l10n.enterPhoneNumber,
            validator: (v) => Validators.required(v, l10n.enterPhoneNumber),
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _emailCtrl,
            labelText: l10n.businessEmail,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            hintText: l10n.enterBusinessEmail,
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.validationEmailRequired;
              if (!v.contains('@')) return l10n.validationEmailInvalid;
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _tinNumberCtrl,
            labelText: l10n.tinNumber,
            icon: Icons.badge_outlined,
            hintText: l10n.enterTinNumber,
            validator: (v) => Validators.required(v, l10n.enterTinNumber),
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _websiteCtrl,
            labelText: l10n.website,
            icon: Icons.language_outlined,
            keyboardType: TextInputType.url,
            autocorrect: false,
            hintText: l10n.enterWebsiteUrl,
            validator: (v) => Validators.required(v, l10n.enterWebsiteUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildContactStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _contactFormKey,
      child: Column(
        children: [
          AppTextFormField(
            controller: _contactPersonNameCtrl,
            labelText: l10n.contactName,
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            hintText: l10n.enterContactName,
            validator: (v) => Validators.required(v, l10n.enterContactName),
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _contactPersonPhoneNumberCtrl,
            labelText: l10n.contactPhone,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            hintText: l10n.enterContactPhone,
            validator: (v) => Validators.required(v, l10n.enterContactPhone),
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _contactPersonEmailCtrl,
            labelText: l10n.contactEmail,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            hintText: l10n.enterContactEmail,
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.enterContactEmail;
              if (!v.contains('@')) return l10n.validationEmailInvalid;
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _contactPersonTitleCtrl,
            labelText: l10n.contactTitle,
            icon: Icons.work_outline_rounded,
            hintText: l10n.enterJobTitle,
            validator: (v) => Validators.required(v, l10n.enterJobTitle),
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: _passwordCtrl,
            labelText: l10n.password,
            icon: Icons.lock_outline_rounded,
            hintText: l10n.validationPasswordRequired,
            keyboardType: TextInputType.visiblePassword,
            obscureText: _obscurePassword,
            autocorrect: false,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              tooltip: _obscurePassword ? l10n.showPassword : l10n.hidePassword,
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
          ),
        ],
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
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _errorBanner(),
        Text(l10n.businessName.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.4)),
        _reviewRow(l10n.businessName, _nameCtrl.text),
        _reviewRow(l10n.businessType, _selectedType),
        _reviewRow(l10n.region, _selectedRegion?.name ?? ''),
        _reviewRow(l10n.address, _addressCtrl.text),
        _reviewRow(l10n.registrationNumber, _registrationNumberCtrl.text),
        _reviewRow(l10n.phoneNumber, _phoneNumberCtrl.text),
        _reviewRow(l10n.businessEmail, _emailCtrl.text),
        _reviewRow(l10n.tinNumber, _tinNumberCtrl.text),
        _reviewRow(l10n.website, _websiteCtrl.text),
        const SizedBox(height: 12),
        Text(l10n.contactName.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.4)),
        _reviewRow(l10n.contactName, _contactPersonNameCtrl.text),
        _reviewRow(l10n.contactPhone, _contactPersonPhoneNumberCtrl.text),
        _reviewRow(l10n.contactEmail, _contactPersonEmailCtrl.text),
        _reviewRow(l10n.contactTitle, _contactPersonTitleCtrl.text),
        _reviewRow(l10n.password, _passwordCtrl.text.isEmpty ? '' : '********'),
        const SizedBox(height: 12),
        if (_submitting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loadingRegions) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: LoadingView(message: l10n.preparingRegistrationRegions),
        ),
      );
    }

    if (_regionsError != null && _regions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 44, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  _regionsError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 180,
                  child: OutlinedButton(
                    onPressed: _fetchRegions,
                    child: Text(l10n.retry),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(l10n.createOwnerAccount,
            style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //   Container(
              //     padding: const EdgeInsets.all(16),
              //     decoration: BoxDecoration(
              //       color: AppColors.primary,
              //       borderRadius: BorderRadius.circular(18),
              //     ),
              //     child: const Icon(Icons.admin_panel_settings_rounded,
              //         size: 36, color: Colors.white),
              //   ),

              //   const SizedBox(height: 20),

              //   Text(l10n.createOwnerAccount,
              //       style: const TextStyle(
              //           fontSize: 24,
              //           fontWeight: FontWeight.w800,
              //           color: AppColors.textPrimary,
              //           letterSpacing: -0.4)),
              //   const SizedBox(height: 6),
              //   Text(
              //     l10n.registerSubtitle,
              //     style: const TextStyle(
              //         fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              //   ),
              const SizedBox(height: 16),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppColors.primary,
                        ),
                  ),
                  child: AppStepper(
                    key: _stepperKey,
                    completeLabel: l10n.createAccount,
                    onComplete: _submit,
                    steps: [
                      AppStep(
                        title: l10n.businessInfo,
                        description: l10n.businessInfoDescription,
                        contentBuilder: _buildBusinessStep,
                        validate: _validateBusinessStep,
                      ),
                      AppStep(
                        title: l10n.contactPerson,
                        description: l10n.contactPersonDescription,
                        contentBuilder: _buildContactStep,
                        validate: _validateContactStep,
                      ),
                      AppStep(
                        title: l10n.review,
                        description: l10n.registrationReviewDescription,
                        contentBuilder: _buildReviewStep,
                        validate: () => true,
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
