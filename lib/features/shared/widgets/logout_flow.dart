import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

Future<void> runLogoutFlow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final canLogout = await _ensureSyncedBeforeLogout(context, ref, l10n);
  if (!canLogout || !context.mounted) return;

  final confirmed = await showCreationConfirmDialog(
    context,
    title: l10n.logout,
    description: l10n.logoutConfirmMessage,
    confirmLabel: l10n.logout,
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;

  showCenteredLoadingDialog(
    context,
    title: l10n.loggingOut,
    description: l10n.clearingLocalSession,
  );
  await ref.read(authProvider.notifier).logout();
  if (!context.mounted) return;
  if (Navigator.of(context, rootNavigator: true).canPop()) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}

Future<bool> _ensureSyncedBeforeLogout(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  final pending = await ref.read(syncQueueDaoProvider).getPendingCount();
  final conflicts =
      (await ref.read(syncQueueDaoProvider).getConflicts()).length;
  if (pending == 0 && conflicts == 0) return true;
  if (!context.mounted) return false;

  final shouldSync = await showAppFeedbackDialog<bool>(
        context,
        title: l10n.logoutUnsyncedTitle,
        description: l10n.logoutUnsyncedMessage(pending, conflicts),
        type: AppFeedbackType.warning,
        actions: [
          AppFeedbackAction<bool>(label: l10n.cancel, result: false),
          AppFeedbackAction<bool>(
            label: l10n.syncNow,
            result: true,
            isPrimary: true,
          ),
        ],
      ) ??
      false;
  if (!shouldSync || !context.mounted) return false;

  await runSyncWithProgressDialog(context, ref);
  if (!context.mounted) return false;

  final remainingPending =
      await ref.read(syncQueueDaoProvider).getPendingCount();
  final remainingConflicts =
      (await ref.read(syncQueueDaoProvider).getConflicts()).length;
  if (remainingPending == 0 && remainingConflicts == 0) return true;
  if (!context.mounted) return false;

  await showWarningDialog(
    context,
    title: l10n.logoutBlockedTitle,
    description: l10n.logoutBlockedMessage,
  );
  return false;
}
