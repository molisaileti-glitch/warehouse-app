import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class OwnerDrawer extends StatelessWidget {
  const OwnerDrawer({super.key});

  void _go(BuildContext context, String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 72,
              color: AppColors.primary,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(
                Icons.account_balance_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: Text(l10n.amcosManagement),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _go(context, AppRoutes.ownerAmcos),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.settings),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _go(context, AppRoutes.ownerSettings),
            ),
          ],
        ),
      ),
    );
  }
}
