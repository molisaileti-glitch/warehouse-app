// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../enums/sync_status.dart';
import '../../features/onboarding/screens/language_picker_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/owner/screens/owner_shell.dart';
import '../../features/owner/screens/owner_dashboard_screen.dart';
import '../../features/owner/screens/pending_syncs_screen.dart';
import '../../features/owner/screens/warehouse_list_screen.dart';
import '../../features/owner/screens/warehouse_detail_screen.dart';
import '../../features/owner/screens/user_management_screen.dart';
import '../../features/owner/screens/owner_harvest_detail_screen.dart';
import '../../features/owner/screens/owner_harvests_screen.dart';
import '../../features/owner/screens/owner_farmers_screen.dart';
import '../../features/owner/screens/owner_worker_detail_screen.dart';
import '../../features/owner/screens/audit_log_screen.dart';
import '../../features/worker/presentation/screens/worker_shell.dart';
import '../../features/worker/presentation/screens/worker_dashboard_screen.dart';
import '../../features/worker/presentation/screens/inventory_item_screen.dart';
import '../../features/worker/presentation/screens/inventory_list_screen.dart';
import '../../features/harvest/presentation/screens/harvest_connect_scale_screen.dart';
import '../../features/harvest/presentation/screens/harvest_farmer_details_screen.dart';
import '../../features/harvest/presentation/screens/harvest_list_screen.dart';
import '../../features/harvest/presentation/screens/harvest_receipt_screen.dart';
import '../../features/harvest/presentation/screens/harvest_scale_bags_screen.dart';
import '../../features/harvest/presentation/screens/worker_harvest_detail_screen.dart';
import '../../features/farmer/presentation/screens/farmer_detail_screen.dart';
import '../../features/farmer/presentation/screens/farmer_list_screen.dart';
import '../../features/farmer/presentation/screens/farmer_registration_screen.dart';
import '../../features/shared/screens/splash_screen.dart';
import '../../features/shared/screens/settings_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const languagePicker = '/language';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';

  // Owner
  static const ownerDashboard = '/owner';
  static const ownerWarehouses = '/owner/warehouses';
  static const ownerWarehouseDetail = '/owner/warehouses/:id';
  static const ownerUsers = '/owner/users';
  static const ownerUserDetail = '/owner/users/:id';
  static const ownerAuditLog = '/owner/audit';
  static const ownerHarvests = '/owner/harvests';
  static const ownerHarvestDetail = '/owner/harvests/detail/:id';
  static const ownerConnectScale = '/owner/harvests/connect-scale/:warehouseId';
  static const ownerFarmerDetails = '/owner/harvests/details/:warehouseId';
  static const ownerScaleBags = '/owner/harvests/scale/:warehouseId';
  static const ownerReceipt = '/owner/harvests/receipt/:warehouseId';
  static const ownerFarmers = '/owner/farmers';
  static const ownerFarmerRegistration = '/owner/farmers/new';
  static const ownerFarmerDetail = '/owner/farmers/:id';
  static const ownerSettings = '/owner/settings';
  static const ownerPendingSyncs = '/owner/pending-syncs';

  // Worker
  static const workerDashboard = '/worker';
  static const workerInventory = '/worker/inventory/:warehouseId';
  static const workerInventoryItem =
      '/worker/inventory/:warehouseId/item/:itemId';
  static const workerHarvests = '/worker/harvests/:warehouseId';
  static const workerHarvestDetail = '/worker/harvests/:warehouseId/detail/:id';
  static const workerConnectScale =
      '/worker/harvests/:warehouseId/connect-scale';
  static const workerFarmerDetails = '/worker/harvests/:warehouseId/details';
  static const workerScaleBags = '/worker/harvests/:warehouseId/scale';
  static const workerReceipt = '/worker/harvests/:warehouseId/receipt';
  static const workerFarmers = '/worker/farmers';
  static const workerFarmerRegistration = '/worker/farmers/new';
  static const workerFarmerDetail = '/worker/farmers/:id';

  static String workerInventoryFor(String warehouseId) =>
      '/worker/inventory/$warehouseId';

  static String workerInventoryItemFor(String warehouseId, String itemId) =>
      '/worker/inventory/$warehouseId/item/$itemId';

  static String workerHarvestsFor(String warehouseId) =>
      '/worker/harvests/$warehouseId';

  static String workerRecordFor(String warehouseId) =>
      workerHarvestsFor(warehouseId);

  static String workerHarvestDetailFor(String warehouseId, String id) =>
      '/worker/harvests/$warehouseId/detail/$id';

  static String workerConnectScaleFor(String warehouseId) =>
      '/worker/harvests/$warehouseId/connect-scale';

  static String workerFarmerDetailsFor(String warehouseId) =>
      '/worker/harvests/$warehouseId/details';

  static String workerScaleBagsFor(String warehouseId) =>
      '/worker/harvests/$warehouseId/scale';

  static String workerReceiptFor(String warehouseId) =>
      '/worker/harvests/$warehouseId/receipt';

  static String workerFarmerDetailFor(int id) => '/worker/farmers/$id';

  static String ownerConnectScaleFor(String warehouseId) =>
      '/owner/harvests/connect-scale/$warehouseId';

  static String ownerFarmerDetailsFor(String warehouseId) =>
      '/owner/harvests/details/$warehouseId';

  static String ownerScaleBagsFor(String warehouseId) =>
      '/owner/harvests/scale/$warehouseId';

  static String ownerReceiptFor(String warehouseId) =>
      '/owner/harvests/receipt/$warehouseId';

  static String ownerUserDetailFor(String id) => '/owner/users/$id';

  static String ownerHarvestDetailFor(String id) =>
      '/owner/harvests/detail/$id';

  static String ownerFarmerDetailFor(int id) => '/owner/farmers/$id';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final appListenable = _AppStateListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: appListenable,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onLangPicker = loc == AppRoutes.languagePicker;
      final onOnboarding = loc == AppRoutes.onboarding;
      final onLogin = loc == AppRoutes.login;
      final onRegister = loc == AppRoutes.register;
      final onSplash = loc == AppRoutes.splash;

      // ── Step 1: has onboarding finished loading from SharedPreferences? ──
      final onboardingState = ref.read(onboardingProvider);
      final hasOnboarded = onboardingState.valueOrNull;

      if (onboardingState.isLoading || hasOnboarded == null) {
        return onSplash ? null : AppRoutes.splash;
      }

      // ── Step 2: first launch ever? Route to language → onboarding ──────
      if (!hasOnboarded) {
        if (onLangPicker || onOnboarding) return null;
        return AppRoutes.languagePicker;
      }

      // ── Step 3: onboarding already done — normal auth flow ──────────────
      final authState = ref.read(authProvider).valueOrNull;
      final onAnyPreLoginScreen =
          onLangPicker || onOnboarding || onLogin || onRegister || onSplash;

      if (authState == null || authState.status == AuthStatus.loading) {
        return onSplash ? null : AppRoutes.splash;
      }

      if (authState.status == AuthStatus.unauthenticated) {
        // Allow language picker (from settings) and register (owner signup)
        // even when logged out — everything else bounces to login.
        if (onLogin || onLangPicker || onRegister) return null;
        return AppRoutes.login;
      }

      // Authenticated — redirect away from any pre-login screen.
      if (onAnyPreLoginScreen) {
        return _homeForRole(authState.role);
      }

      return _roleGuard(loc, authState.role);
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.languagePicker,
        builder: (_, state) => LanguagePickerScreen(
          isFirstLaunch: state.uri.queryParameters['from'] != 'settings',
        ),
      ),
      GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),

      // ── Owner shell ──────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => OwnerShell(child: child),
        routes: [
          GoRoute(
              path: AppRoutes.ownerDashboard,
              builder: (_, __) => const OwnerDashboardScreen()),
          GoRoute(
              path: AppRoutes.ownerWarehouses,
              builder: (_, __) => const WarehouseListScreen()),
          GoRoute(
            path: AppRoutes.ownerWarehouseDetail,
            builder: (_, state) =>
                WarehouseDetailScreen(warehouseId: state.pathParameters['id']!),
          ),
          GoRoute(
              path: AppRoutes.ownerUsers,
              builder: (_, __) => const UserManagementScreen()),
          GoRoute(
            path: AppRoutes.ownerUserDetail,
            builder: (_, state) => OwnerWorkerDetailScreen(
              workerId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
              path: AppRoutes.ownerHarvests,
              builder: (_, __) => const OwnerHarvestsScreen()),
          GoRoute(
            path: AppRoutes.ownerHarvestDetail,
            builder: (_, state) => OwnerHarvestDetailScreen(
              harvestUuid: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.ownerConnectScale,
            builder: (_, state) => HarvestConnectScaleScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              ownerFlow: true,
            ),
          ),
          GoRoute(
            path: AppRoutes.ownerFarmerDetails,
            builder: (_, state) => HarvestFarmerDetailsScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              ownerFlow: true,
            ),
          ),
          GoRoute(
            path: AppRoutes.ownerScaleBags,
            builder: (_, state) => HarvestScaleBagsScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              ownerFlow: true,
            ),
          ),
          GoRoute(
            path: AppRoutes.ownerReceipt,
            builder: (_, state) => HarvestReceiptScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              ownerFlow: true,
            ),
          ),
          GoRoute(
              path: AppRoutes.ownerFarmers,
              builder: (_, __) => const OwnerFarmersScreen()),
          GoRoute(
            path: AppRoutes.ownerFarmerRegistration,
            builder: (_, __) => const FarmerRegistrationScreen(
              returnRoute: AppRoutes.ownerFarmers,
            ),
          ),
          GoRoute(
            path: AppRoutes.ownerFarmerDetail,
            builder: (_, state) => FarmerDetailScreen(
              farmerId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
              path: AppRoutes.ownerPendingSyncs,
              builder: (_, __) => const PendingSyncsScreen()),
          GoRoute(
              path: AppRoutes.ownerAuditLog,
              builder: (_, __) => const AuditLogScreen()),
          GoRoute(
              path: AppRoutes.ownerSettings,
              builder: (_, __) => const SettingsScreen()),
        ],
      ),

      // ── Worker shell ──────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => WorkerShell(child: child),
        routes: [
          GoRoute(
              path: AppRoutes.workerDashboard,
              builder: (_, __) => const WorkerDashboardScreen()),
          GoRoute(
            path: AppRoutes.workerInventory,
            builder: (_, state) => InventoryListScreen(
              warehouseId: state.pathParameters['warehouseId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.workerInventoryItem,
            builder: (_, state) => InventoryItemScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              itemId: state.pathParameters['itemId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.workerHarvests,
            builder: (_, state) => HarvestListScreen(
              warehouseId: state.pathParameters['warehouseId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.workerHarvestDetail,
            builder: (_, state) => WorkerHarvestDetailScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              harvestUuid: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.workerConnectScale,
            builder: (_, state) => HarvestConnectScaleScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              ownerFlow: false,
            ),
          ),
          GoRoute(
            path: AppRoutes.workerFarmerDetails,
            builder: (_, state) => HarvestFarmerDetailsScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              ownerFlow: false,
            ),
          ),
          GoRoute(
            path: AppRoutes.workerScaleBags,
            builder: (_, state) => HarvestScaleBagsScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              ownerFlow: false,
            ),
          ),
          GoRoute(
              path: AppRoutes.workerFarmers,
              builder: (_, __) => const FarmerListScreen()),
          GoRoute(
            path: AppRoutes.workerFarmerRegistration,
            builder: (_, __) => const FarmerRegistrationScreen(),
          ),
          GoRoute(
            path: AppRoutes.workerFarmerDetail,
            builder: (_, state) => FarmerDetailScreen(
              farmerId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: AppRoutes.workerReceipt,
            builder: (_, state) => HarvestReceiptScreen(
              warehouseId: state.pathParameters['warehouseId']!,
              ownerFlow: false,
            ),
          ),
        ],
      ),
    ],
  );
});

String _homeForRole(UserRole? role) => switch (role) {
      UserRole.owner || UserRole.superAdmin => AppRoutes.ownerDashboard,
      UserRole.worker => AppRoutes.workerDashboard,
      null => AppRoutes.login,
    };

String? _roleGuard(String location, UserRole? role) {
  if (role == null) return AppRoutes.login;

  final isOwnerRole = role == UserRole.owner || role == UserRole.superAdmin;
  final isWorkerRole = role == UserRole.worker;

  if (location.startsWith('/owner') && !isOwnerRole) {
    return _homeForRole(role);
  }

  if (location.startsWith('/worker') && !isWorkerRole) {
    return _homeForRole(role);
  }

  return null;
}

class _AppStateListenable extends ChangeNotifier {
  _AppStateListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(onboardingProvider, (_, __) => notifyListeners());
  }
}
