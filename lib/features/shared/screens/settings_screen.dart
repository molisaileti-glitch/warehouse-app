// lib/features/shared/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0+1';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    final themeModeLabel = Theme.of(context).brightness == Brightness.dark ? 'Dark' : 'Light';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.go(AppRoutes.ownerDashboard),
        ),
        title: Text(l10n.settings),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _SectionTitle(title: 'Account'),
          const SizedBox(height: 12),
          _SettingCard(
            icon: Icons.person_rounded,
            title: 'Profile',
            subtitle: 'View and edit your profile',
            onTap: () => _showComingSoon(context, 'Profile'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Preferences'),
          const SizedBox(height: 12),
          _SettingCard(
            icon: Icons.language_rounded,
            title: l10n.language,
            subtitle: lang.label,
            onTap: () => _showLanguageSheet(context, ref),
          ),
          const SizedBox(height: 12),
          _SettingCard(
            icon: Icons.palette_rounded,
            title: 'Theme',
            subtitle: themeModeLabel,
            onTap: () => _showComingSoon(context, 'Theme'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'App Information'),
          const SizedBox(height: 12),
          _SettingCard(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () => _showAboutDialog(context),
          ),
          const SizedBox(height: 12),
          const _SettingCard(
            icon: Icons.verified_rounded,
            title: 'Version',
            subtitle: _appVersion,
            showChevron: false,
          ),
          const SizedBox(height: 12),
          _SettingCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Open the official policy in your browser.',
            onTap: () => _showComingSoon(context, 'Privacy Policy'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final currentLang = ref.read(localeProvider);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              for (final lang in AppLanguage.values)
                ListTile(
                  title: Text(lang.label),
                  trailing: currentLang == lang ? const Icon(Icons.check_rounded) : null,
                  onTap: () async {
                    await ref.read(localeProvider.notifier).setLanguage(lang);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('About'),
          content: const Text('StockPilot helps warehouse teams manage inventory, workers, and sync.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title settings coming soon')),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.ownerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.ownerColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 28),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
