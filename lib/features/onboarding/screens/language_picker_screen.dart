// lib/features/onboarding/screens/language_picker_screen.dart
//
// Shown once on first app open, before the onboarding slides.
// Also reachable later from Settings to change language.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/router/app_router.dart';

class LanguagePickerScreen extends ConsumerWidget {
  /// When true, this is the first-launch flow and selecting a language
  /// advances to onboarding. When false (opened from Settings), selecting
  /// a language just saves it and pops back.
  final bool isFirstLaunch;

  const LanguagePickerScreen({super.key, this.isFirstLaunch = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.translate, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Choose your language',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Chagua lugha yako',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _LanguageOption(
                language: AppLanguage.english,
                isSelected: currentLang == AppLanguage.english,
                onTap: () => ref.read(localeProvider.notifier).setLanguage(AppLanguage.english),
              ),
              const SizedBox(height: 12),
              _LanguageOption(
                language: AppLanguage.swahili,
                isSelected: currentLang == AppLanguage.swahili,
                onTap: () => ref.read(localeProvider.notifier).setLanguage(AppLanguage.swahili),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isFirstLaunch) {
                      context.go(AppRoutes.onboarding);
                    } else {
                      context.pop();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(isFirstLaunch ? l10n.continueButton : l10n.saveButton),
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

class _LanguageOption extends StatelessWidget {
  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.primary : colors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? colors.primaryContainer.withOpacity(0.3) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                language.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: colors.primary),
          ],
        ),
      ),
    );
  }
}