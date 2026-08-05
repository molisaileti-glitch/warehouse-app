import 'package:flutter/material.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';

enum AppFeedbackType { success, error, warning, info, confirmation, loading }

class AppFeedbackAction<T> {
  final String label;
  final T? result;
  final bool isPrimary;
  final bool isDestructive;

  const AppFeedbackAction({
    required this.label,
    this.result,
    this.isPrimary = false,
    this.isDestructive = false,
  });
}

Future<T?> showAppFeedbackDialog<T>(
  BuildContext context, {
  required String title,
  required String description,
  required AppFeedbackType type,
  List<AppFeedbackAction<T>> actions = const [],
  bool barrierDismissible = true,
}) {
  final (icon, accentColor) = switch (type) {
    AppFeedbackType.success => (Icons.check_circle_rounded, AppColors.success),
    AppFeedbackType.error => (Icons.error_rounded, AppColors.error),
    AppFeedbackType.warning => (Icons.warning_rounded, AppColors.warning),
    AppFeedbackType.info => (Icons.info_rounded, AppColors.info),
    AppFeedbackType.confirmation => (
        Icons.help_outline_rounded,
        AppColors.primary
      ),
    AppFeedbackType.loading => (Icons.hourglass_top_rounded, AppColors.primary),
  };

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible && type != AppFeedbackType.loading,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      Widget buildAction(AppFeedbackAction<T> action) {
        final child = Text(action.label, textAlign: TextAlign.center);
        void onPressed() => Navigator.of(dialogContext).pop(action.result);

        if (action.isDestructive && action.isPrimary) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: child,
            ),
          );
        }

        if (action.isPrimary) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
              ),
              child: child,
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  action.isDestructive ? AppColors.error : accentColor,
            ),
            child: child,
          ),
        );
      }

      Widget buildActions() {
        if (actions.isEmpty) return const SizedBox.shrink();
        if (actions.length == 1) return buildAction(actions.first);
        if (actions.length == 2) {
          return Row(
            children: [
              Expanded(child: buildAction(actions.first)),
              const SizedBox(width: 12),
              Expanded(child: buildAction(actions.last)),
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
        titlePadding: EdgeInsets.zero,
        title: const SizedBox.shrink(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: type == AppFeedbackType.loading
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
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
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

void showCenteredLoadingDialog(
  BuildContext context, {
  required String title,
  required String description,
}) {
  showAppFeedbackDialog<void>(
    context,
    title: title,
    description: description,
    type: AppFeedbackType.loading,
    barrierDismissible: false,
  );
}

Future<void> showCreationSuccessDialog(
  BuildContext context, {
  required String title,
  required String description,
  String actionLabel = 'OK',
}) {
  return showAppFeedbackDialog<void>(
    context,
    title: title,
    description: description,
    type: AppFeedbackType.success,
    actions: [
      AppFeedbackAction<void>(label: actionLabel, isPrimary: true),
    ],
  );
}

Future<bool> showCreationConfirmDialog(
  BuildContext context, {
  required String title,
  required String description,
  String confirmLabel = 'Create',
  bool isDestructive = false,
}) async {
  final result = await showAppFeedbackDialog<bool>(
    context,
    title: title,
    description: description,
    type: AppFeedbackType.confirmation,
    actions: [
      const AppFeedbackAction<bool>(label: 'Cancel', result: false),
      AppFeedbackAction<bool>(
        label: confirmLabel,
        result: true,
        isPrimary: true,
        isDestructive: isDestructive,
      ),
    ],
  );
  return result ?? false;
}
