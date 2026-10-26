import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/env.dart';
import 'core/crash_reporter.dart';
import 'core/error_handling.dart';
import 'core/startup_gate.dart';
import 'core/text_scale.dart';
import 'router/app_router.dart';
import 'services/supabase_service.dart';
import 'state/auth_provider.dart';
import 'state/catalog_provider.dart';
import 'theme/app_theme.dart';

/// Every uncaught error -- framework, async, platform -- is routed to
/// [CrashReporting] (see core/crash_reporter.dart) instead of the user's face.
void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      installErrorHandling();
      runApp(
        ProviderScope(
          // Supabase is initialised behind a gate so a failed start shows a
          // "Can't start PETSTA" screen with Retry, never a blank window.
          child: StartupGate(
            initialize: SupabaseService.init,
            builder: (context) => const PawsNearbyApp(),
          ),
        ),
      );
    },
    (error, stack) => CrashReporting.report(error, stack, fatal: true),
  );
}

class PawsNearbyApp extends ConsumerStatefulWidget {
  const PawsNearbyApp({super.key});

  @override
  ConsumerState<PawsNearbyApp> createState() => _PawsNearbyAppState();
}

class _PawsNearbyAppState extends ConsumerState<PawsNearbyApp> with WidgetsBindingObserver {
  /// When the app last left the foreground; null while it is in front.
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null) _onResumed(DateTime.now().difference(since));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onResumed(Duration away) {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    // A profile that failed to load while offline is retried straight away.
    if (auth.profileFailed) unawaited(auth.refreshProfile());
    // Prices, stock and shop approvals may have changed while we were away.
    if (away >= AppEnv.resumeRefreshAfter) ref.invalidate(catalogProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PETSTA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
      builder: clampTextScale,
    );
  }
}
