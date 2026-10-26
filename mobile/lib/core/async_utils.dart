import 'dart:async';
import 'dart:math' as math;

import '../config/env.dart';
import 'app_error.dart';

/// Small helpers for making network calls behave on flaky mobile connections.

/// Completes with [future]'s result, or throws a [TimeoutException] when it
/// takes longer than [timeout]. The underlying request is not cancelled (the
/// Supabase client has no cancellation), but the caller stops waiting.
Future<T> withTimeout<T>(
  Future<T> future, {
  Duration timeout = AppEnv.requestTimeout,
  String? message,
}) {
  return future.timeout(
    timeout,
    onTimeout: () => throw TimeoutException(message ?? 'The request timed out.', timeout),
  );
}

/// Runs [task] up to [maxAttempts] times with exponential backoff and a little
/// jitter, retrying only while [retryIf] says the failure is worth another go.
///
/// By default only transient failures (offline, timeouts, 5xx, rate limits)
/// are retried; permission, validation and not-found errors surface at once.
/// Keep [maxAttempts] small -- this is for a one-off read, not a retry storm.
Future<T> retry<T>(
  Future<T> Function() task, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 400),
  double factor = 2,
  Duration maxDelay = const Duration(seconds: 5),
  bool Function(Object error)? retryIf,
}) async {
  assert(maxAttempts >= 1, 'maxAttempts must be at least 1');
  final shouldRetry = retryIf ?? isTransientError;
  final random = math.Random();
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    attempt++;
    try {
      return await task();
    } catch (error) {
      if (attempt >= maxAttempts || !shouldRetry(error)) rethrow;
      final jitterMs = random.nextInt(150);
      await Future<void>.delayed(delay + Duration(milliseconds: jitterMs));
      final nextMs = (delay.inMilliseconds * factor).round();
      delay = Duration(milliseconds: math.min(nextMs, maxDelay.inMilliseconds));
    }
  }
}

/// [withTimeout] wrapped in [retry]: each attempt gets its own [timeout].
Future<T> resilient<T>(
  Future<T> Function() task, {
  Duration timeout = AppEnv.requestTimeout,
  int maxAttempts = 2,
}) {
  return retry(() => withTimeout(task(), timeout: timeout), maxAttempts: maxAttempts);
}
