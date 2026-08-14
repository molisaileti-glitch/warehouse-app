import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class OwnerShell extends StatelessWidget {
  final Widget child;

  const OwnerShell({super.key, required this.child});

  static const _tabs = [
    (
      icon: Icons.dashboard_rounded,
      route: AppRoutes.ownerDashboard,
    ),
    (
      icon: Icons.warehouse_rounded,
      route: AppRoutes.ownerWarehouses,
    ),
    (
      icon: Icons.groups_rounded,
      route: AppRoutes.ownerUsers,
    ),
    (
      icon: Icons.inventory_2_rounded,
      route: AppRoutes.ownerHarvests,
    ),
    (
      icon: Icons.agriculture_rounded,
      route: AppRoutes.ownerFarmers,
    ),
  ];

  int _selectedIndex(String location) {
    if (location.startsWith('/owner/warehouses')) return 1;
    if (location.startsWith('/owner/users')) return 2;
    if (location.startsWith('/owner/harvests')) return 3;
    if (location.startsWith('/owner/farmers')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final index = _selectedIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.7),
              ),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _OwnerNavItem(
                    icon: _tabs[i].icon,
                    label: switch (i) {
                      0 => l10n.dashboard,
                      1 => l10n.warehouse,
                      2 => l10n.workers,
                      3 => l10n.harvests,
                      _ => l10n.farmers,
                    },
                    selected: i == index,
                    onTap: () => context.go(_tabs[i].route),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OwnerNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ownerColor : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 44 : 32,
            height: selected ? 44 : 32,
            decoration: BoxDecoration(
              color: selected ? AppColors.ownerColor : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : color,
              size: selected ? 24 : 23,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
