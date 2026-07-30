// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/sync/sync_engine.dart';

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
  String? _lastSeededUserId;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final currentLang = ref.watch(localeProvider);

    ref.listen<AsyncValue<AuthState>>(authProvider, (_, next) {
      final state = next.valueOrNull;
      final userId = state?.userId;
      if (state?.status != AuthStatus.authenticated || userId == null) {
        _lastSeededUserId = null;
        return;
      }
      if (_lastSeededUserId == userId) return;
      _lastSeededUserId = userId;
      ref.read(syncManagerProvider).pullReferenceData().catchError((_) => 0);
    });

    return MaterialApp.router(
      title: 'StockPilot',
      debugShowCheckedModeBanner: false,
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
