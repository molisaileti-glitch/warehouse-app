// lib/core/providers/locale_provider.dart
//
// Tracks the app's selected language and whether onboarding has been seen.
// Both are persisted with SharedPreferences — neither is sensitive, so no
// need for secure storage here (that's reserved for auth tokens).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLangKey = 'app_language';
const _kOnboardedKey = 'has_onboarded';

enum AppLanguage {
  english,
  swahili;

  String get code => switch (this) {
        AppLanguage.english => 'en',
        AppLanguage.swahili => 'sw',
      };

  String get label => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.swahili => 'Kiswahili',
      };

  static AppLanguage fromCode(String code) => switch (code) {
        'sw' => AppLanguage.swahili,
        _ => AppLanguage.english,
      };
}

/// Holds the current language. Defaults to English until SharedPreferences
/// loads, then updates. UI should watch this and rebuild text using
/// AppStrings.of(locale.code) — same pattern as the Fedha app.
class LocaleNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    _load();
    return AppLanguage.english;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangKey);
    if (saved != null) {
      state = AppLanguage.fromCode(saved);
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, lang.code);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLanguage>(
  LocaleNotifier.new,
);

/// Tracks whether the user has completed onboarding at least once.
/// GoRouter's redirect logic reads this — same way it reads authProvider.
class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardedKey) ?? false;
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardedKey, true);
    state = const AsyncData(true);
  }

  /// Useful for testing or a "replay onboarding" debug option.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardedKey, false);
    state = const AsyncData(false);
  }
}

final onboardingProvider = AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);