// lib/features/shared/widgets/common_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../l10n/app_localizations.dart';

// ── AppCard ───────────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color ?? AppColors.cardBg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// ── SyncStatusBadge ───────────────────────────────────────────────────────────

class SyncStatusBadge extends StatelessWidget {
  final String status;

  const SyncStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final normalized = status.trim().toLowerCase();
    if (normalized != 'synced' && normalized != 'conflict') {
      return const SizedBox.shrink();
    }

    final (color, icon, label) = switch (normalized) {
      'synced' => (
          AppColors.syncSynced,
          Icons.cloud_done_rounded,
          l10n.allSynced
        ),
      _ => (AppColors.syncConflict, Icons.warning_rounded, l10n.conflict),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Global sync indicator (shown in AppBar) ────────────────────────────────────

class SyncIndicator extends ConsumerWidget {
  final VoidCallback? onTap;
  const SyncIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pendingAsync = ref.watch(syncPendingCountProvider);
    final count = pendingAsync.valueOrNull ?? 0;

    if (count == 0) {
      return IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.cloud_done_rounded, color: Colors.white70),
        tooltip: l10n.allSyncedTooltip,
      );
    }

    return Stack(
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
          tooltip: l10n.pendingTooltip(count),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
                color: AppColors.warning, shape: BoxShape.circle),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

// ── EmptyState ─────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 48, color: AppColors.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                    onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── LoadingView ────────────────────────────────────────────────────────────────

class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ]
        ],
      ),
    );
  }
}

// ── ErrorView ──────────────────────────────────────────────────────────────────

enum AppDialogType { success, error, warning, info, confirmation, loading }

class AppDialogAction<T> {
  final String label;
  final T? result;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;

  const AppDialogAction({
    required this.label,
    this.result,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });
}

Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  required String description,
  required AppDialogType type,
  List<AppDialogAction<T>> actions = const [],
  bool barrierDismissible = true,
}) {
  final (icon, accentColor) = switch (type) {
    AppDialogType.success => (Icons.check_circle_rounded, AppColors.success),
    AppDialogType.error => (Icons.error_rounded, AppColors.error),
    AppDialogType.warning => (Icons.warning_rounded, AppColors.warning),
    AppDialogType.info => (Icons.info_rounded, AppColors.info),
    AppDialogType.confirmation => (
        Icons.help_outline_rounded,
        AppColors.primary
      ),
    AppDialogType.loading => (Icons.hourglass_top_rounded, AppColors.primary),
  };

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible && type != AppDialogType.loading,
    barrierColor: Colors.black54,
    builder: (ctx) {
      Widget buildAction(AppDialogAction<T> action) {
        Widget button;
        if (action.isDestructive && action.isPrimary) {
          button = FilledButton(
            onPressed: () {
              action.onPressed?.call();
              Navigator.of(ctx).pop(action.result);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(action.label, textAlign: TextAlign.center),
          );
        } else if (action.isDestructive) {
          button = TextButton(
            onPressed: () {
              action.onPressed?.call();
              Navigator.of(ctx).pop(action.result);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(action.label, textAlign: TextAlign.center),
          );
        } else if (action.isPrimary) {
          button = FilledButton(
            onPressed: () {
              action.onPressed?.call();
              Navigator.of(ctx).pop(action.result);
            },
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            child: Text(action.label, textAlign: TextAlign.center),
          );
        } else {
          button = OutlinedButton(
            onPressed: () {
              action.onPressed?.call();
              Navigator.of(ctx).pop(action.result);
            },
            style: OutlinedButton.styleFrom(foregroundColor: accentColor),
            child: Text(action.label, textAlign: TextAlign.center),
          );
        }

        return SizedBox(width: double.infinity, child: button);
      }

      Widget buildActions() {
        if (actions.isEmpty) return const SizedBox.shrink();
        if (actions.length == 1) {
          return buildAction(actions.first);
        }
        if (actions.length == 2) {
          return Row(
            children: [
              Expanded(child: buildAction(actions[0])),
              const SizedBox(width: 12),
              Expanded(child: buildAction(actions[1])),
            ],
          );
        }
        return Column(
          children: [
            for (final action in actions) ...[
              buildAction(action),
              const SizedBox(height: 10),
            ],
          ],
        );
      }

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: const SizedBox.shrink(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: type == AppDialogType.loading
                  ? SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: accentColor,
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accentColor, size: 28),
                    ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              buildActions(),
            ],
          ],
        ),
      );
    },
  );
}

Future<void> showLoadingDialog(
  BuildContext context, {
  required String title,
  required String description,
}) {
  return showAppDialog<void>(
    context,
    title: title,
    description: description,
    type: AppDialogType.loading,
    barrierDismissible: false,
  );
}

Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String description,
  String? actionLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppDialog<void>(
    context,
    title: title,
    description: description,
    type: AppDialogType.info,
    actions: [
      AppDialogAction<void>(label: actionLabel ?? l10n.ok, isPrimary: true),
    ],
  );
}

Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required String description,
  String? actionLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppDialog<void>(
    context,
    title: title,
    description: description,
    type: AppDialogType.success,
    actions: [
      AppDialogAction<void>(label: actionLabel ?? l10n.ok, isPrimary: true),
    ],
  );
}

Future<void> showWarningDialog(
  BuildContext context, {
  required String title,
  required String description,
  String? actionLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppDialog<void>(
    context,
    title: title,
    description: description,
    type: AppDialogType.warning,
    actions: [
      AppDialogAction<void>(label: actionLabel ?? l10n.ok, isPrimary: true),
    ],
  );
}

Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String description,
  String? actionLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppDialog<void>(
    context,
    title: title,
    description: description,
    type: AppDialogType.error,
    actions: [
      AppDialogAction<void>(label: actionLabel ?? l10n.ok, isPrimary: true),
    ],
  );
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── ConfirmDialog ──────────────────────────────────────────────────────────────

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool isDestructive = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showAppDialog<bool>(
    context,
    title: title,
    description: message,
    type: AppDialogType.confirmation,
    actions: [
      AppDialogAction<bool>(
        label: l10n.cancel,
        result: false,
        isPrimary: false,
      ),
      AppDialogAction<bool>(
        label: confirmLabel ?? l10n.confirm,
        result: true,
        isPrimary: true,
        isDestructive: isDestructive,
      ),
    ],
  );
  return result ?? false;
}

// ── StatCard ── small metric tile ─────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── SectionHeader ─────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── RoleBadge ── owner / worker pill ───────────────────────────────────────────

class RoleBadge extends StatelessWidget {
  final String role; // 'owner' | 'worker'
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOwner = role == 'owner';
    final color = isOwner ? AppColors.ownerColor : AppColors.workerColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOwner ? l10n.owner : l10n.worker,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
