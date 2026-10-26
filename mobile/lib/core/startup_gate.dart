import 'package:flutter/material.dart';

import '../config/env.dart';
import '../theme/app_theme.dart';
import 'async_utils.dart';
import 'crash_reporter.dart';
import 'text_scale.dart';

/// Runs [initialize] (Supabase init) before building the real app, so a
/// failed start shows a clear screen with a Retry button instead of a blank
/// window or a crash.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.initialize, required this.builder});

  final Future<void> Function() initialize;

  /// Builds the app once [initialize] has succeeded.
  final WidgetBuilder builder;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

enum _StartupPhase { starting, ready, failed }

class _StartupGateState extends State<StartupGate> {
  _StartupPhase _phase = _StartupPhase.starting;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final run = ++_run;
    try {
      await withTimeout(
        widget.initialize(),
        timeout: AppEnv.startupTimeout,
        message: 'Start-up timed out.',
      );
      if (!mounted || run != _run) return;
      setState(() => _phase = _StartupPhase.ready);
    } catch (error, stack) {
      CrashReporting.report(error, stack, reason: 'startup');
      if (!mounted || run != _run) return;
      setState(() => _phase = _StartupPhase.failed);
    }
  }

  void _retry() {
    setState(() => _phase = _StartupPhase.starting);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _StartupPhase.ready:
        return widget.builder(context);
      case _StartupPhase.starting:
        return const _StartupShell(child: _SplashView());
      case _StartupPhase.failed:
        return _StartupShell(child: StartupErrorView(onRetry: _retry));
    }
  }
}

/// Minimal MaterialApp used before the real (router-based) app exists.
class _StartupShell extends StatelessWidget {
  const _StartupShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PETSTA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: clampTextScale,
      home: Scaffold(body: SafeArea(child: child)),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.pets, color: Colors.white, size: 34),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Starting PETSTA',
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BrandMark(),
            const SizedBox(height: 16),
            Text('PETSTA', style: AppTheme.display(fontSize: 24)),
            const SizedBox(height: 24),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen "Can't start PETSTA" state with a Retry button.
class StartupErrorView extends StatelessWidget {
  const StartupErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.inkSoft),
              const SizedBox(height: 16),
              Text(
                "Can't start PETSTA",
                style: AppTheme.display(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection, then try again.',
                style: AppTheme.body(color: AppColors.inkSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
