import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Where uncaught errors go.
///
/// The app never shows stack traces to users. Instead, every uncaught error
/// (Flutter framework errors, async errors, errors in the root zone) is routed
/// through [CrashReporting.instance]. The default implementation
/// ([DefaultCrashReporter]) keeps a short in-memory log and prints to the
/// developer console in debug builds only.
///
/// ## Plugging in Sentry / Firebase Crashlytics
///
/// 1. Add the SDK (for example `sentry_flutter` or `firebase_crashlytics`).
/// 2. Implement [CrashReporter] and forward to it:
///
/// ```dart
/// class SentryCrashReporter implements CrashReporter {
///   @override
///   void recordError(Object error, StackTrace? stack, {String? reason, bool fatal = false}) {
///     Sentry.captureException(error, stackTrace: stack);
///   }
///
///   @override
///   void recordFlutterError(FlutterErrorDetails details) {
///     Sentry.captureException(details.exception, stackTrace: details.stack);
///   }
///
///   @override
///   void log(String message) => Sentry.addBreadcrumb(Breadcrumb(message: message));
///
///   @override
///   void setUserId(String? id) =>
///       Sentry.configureScope((scope) => scope.setUser(id == null ? null : SentryUser(id: id)));
/// }
/// ```
///
/// 3. Install it once, before `runApp`, e.g. at the top of the guarded zone in
///    `main()`: `CrashReporting.install(SentryCrashReporter());`
///
/// Nothing else in the app needs to change. Do not attach emails, phone
/// numbers or addresses to reports -- the opaque user id is enough.
abstract class CrashReporter {
  /// Records an uncaught or handled error. [fatal] marks errors that were not
  /// caught anywhere (zone / platform dispatcher / framework).
  void recordError(Object error, StackTrace? stack, {String? reason, bool fatal = false});

  /// Records an error reported through [FlutterError.onError].
  void recordFlutterError(FlutterErrorDetails details);

  /// Adds a breadcrumb that is attached to later reports.
  void log(String message);

  /// Associates later reports with an opaque user id (never PII), or clears it.
  void setUserId(String? id);
}

/// One entry of [DefaultCrashReporter.recent].
class CrashRecord {
  final DateTime time;
  final String summary;
  final bool fatal;
  const CrashRecord(this.time, this.summary, this.fatal);
}

/// Keeps errors out of the user's face: nothing is shown on screen and nothing
/// leaves the device. Errors are remembered (last [maxRecords]) and echoed to
/// the developer console in debug builds only.
class DefaultCrashReporter implements CrashReporter {
  DefaultCrashReporter({this.maxRecords = 50});

  final int maxRecords;
  final List<CrashRecord> _records = <CrashRecord>[];
  final List<String> _breadcrumbs = <String>[];
  String? _userId;
  String? _lastSummary;
  DateTime? _lastTime;

  /// Most recent errors, oldest first.
  List<CrashRecord> get recent => List.unmodifiable(_records);

  /// Signed-in user id attached to reports (null when signed out).
  String? get userId => _userId;

  @override
  void recordError(Object error, StackTrace? stack, {String? reason, bool fatal = false}) {
    _add(error.toString(), fatal, error: error, stack: stack, reason: reason);
  }

  @override
  void recordFlutterError(FlutterErrorDetails details) {
    final summary = details.exceptionAsString();
    _add(summary, true, error: details.exception, stack: details.stack, reason: details.context?.toDescription());
  }

  @override
  void log(String message) {
    _breadcrumbs.add(message);
    if (_breadcrumbs.length > 30) _breadcrumbs.removeAt(0);
  }

  @override
  void setUserId(String? id) {
    _userId = id;
  }

  void _add(String summary, bool fatal, {Object? error, StackTrace? stack, String? reason}) {
    final now = DateTime.now();
    // The same failing frame can report hundreds of identical errors a second.
    final repeated = _lastSummary == summary &&
        _lastTime != null &&
        now.difference(_lastTime!) < const Duration(seconds: 2);
    _lastSummary = summary;
    _lastTime = now;
    if (repeated) return;

    final firstLine = summary.split('\n').first;
    _records.add(CrashRecord(now, firstLine.length > 300 ? firstLine.substring(0, 300) : firstLine, fatal));
    if (_records.length > maxRecords) _records.removeAt(0);

    if (kDebugMode) {
      developer.log(
        reason == null ? firstLine : '$firstLine ($reason)',
        name: 'petsta.crash',
        error: error,
        stackTrace: stack,
        level: fatal ? 1000 : 900,
      );
    }
  }
}

/// Global access point for the active [CrashReporter].
class CrashReporting {
  CrashReporting._();

  static CrashReporter _instance = DefaultCrashReporter();

  static CrashReporter get instance => _instance;

  /// Replaces the active reporter (see the class docs of [CrashReporter]).
  static void install(CrashReporter reporter) {
    _instance = reporter;
  }

  /// Reports [error] without ever throwing, so it is safe inside error
  /// handlers and `catch` blocks.
  static void report(Object error, StackTrace? stack, {String? reason, bool fatal = false}) {
    try {
      _instance.recordError(error, stack, reason: reason, fatal: fatal);
    } catch (_) {
      // A broken reporter must never take the app down.
    }
  }

  /// Adds a breadcrumb without ever throwing.
  static void breadcrumb(String message) {
    try {
      _instance.log(message);
    } catch (_) {
      // Ignore.
    }
  }
}
