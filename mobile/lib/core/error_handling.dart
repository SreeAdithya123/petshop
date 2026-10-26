import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'crash_reporter.dart';

/// Wires every uncaught-error channel to [CrashReporting] and swaps the red
/// debug error screen for a friendly placeholder in release builds.
///
/// Call once, inside the same zone as `runApp` (see `main()`), after
/// `WidgetsFlutterBinding.ensureInitialized()`.
void installErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) FlutterError.presentError(details);
    try {
      CrashReporting.instance.recordFlutterError(details);
    } catch (_) {
      // A broken reporter must never take the app down.
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    CrashReporting.report(error, stack, fatal: true);
    // Handled: keep the app alive instead of letting the engine abort.
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) => const FriendlyErrorWidget();
  }
}

/// Shown in place of a widget that threw while building (release builds only).
/// No stack traces, no technical wording, and safe to build anywhere: it
/// depends on no theme, font or ancestor other than text direction.
class FriendlyErrorWidget extends StatelessWidget {
  const FriendlyErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sentiment_dissatisfied_outlined, size: 20, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text(
                  'Something went wrong here.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
