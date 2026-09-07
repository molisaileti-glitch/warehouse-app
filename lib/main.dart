// lib/main.dart
 
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/locale_provider.dart';
import 'core/network/api_client.dart' show sessionExpiredProvider;

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait on phones.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    const ProviderScope(
      child: WarehouseApp(),
    ),
  );
}

class WarehouseApp extends ConsumerStatefulWidget {
  const WarehouseApp({super.key});

  @override
  ConsumerState<WarehouseApp> createState() => _WarehouseAppState();
}

class _WarehouseAppState extends ConsumerState<WarehouseApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool? _wasOffline;
  bool _sessionExpiredMessageShown = false;

  @override
  void initState() {
    super.initState();
    _watchConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _watchConnectivity() {
    final connectivity = Connectivity();
    connectivity.checkConnectivity().then((results) {
      final isOffline = _isOffline(results);
      _wasOffline = isOffline;
      if (isOffline) _showConnectivityMessage(isOffline: true);
    });
    _connectivitySubscription =
        connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isOffline = _isOffline(results);
    if (_wasOffline == isOffline) return;
    _wasOffline = isOffline;
    _showConnectivityMessage(isOffline: isOffline);
  }

  bool _isOffline(List<ConnectivityResult> results) {
    return results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
  }

  void _showConnectivityMessage({required bool isOffline}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = appScaffoldMessengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: isOffline ? AppColors.error : AppColors.primary,
            content: Text(
              isOffline
                  ? 'No internet connection. Turn on mobile data or Wi-Fi.'
                  : 'Internet connection restored.',
            ),
          ),
        );
    });
  }

  void _showSessionExpiredMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = appScaffoldMessengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            content: Text('Session expired. Please log in again.'),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final currentLang = ref.watch(localeProvider);
    ref.listen(sessionExpiredProvider, (_, notifier) {
      if (notifier.expired && !_sessionExpiredMessageShown) {
        _sessionExpiredMessageShown = true;
        _showSessionExpiredMessage();
      }
      if (!notifier.expired) {
        _sessionExpiredMessageShown = false;
      }
    });

    return MaterialApp.router(
      title: 'StockPilot',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: AppTheme.light,
      routerConfig: router,
      locale: Locale(currentLang.code),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
