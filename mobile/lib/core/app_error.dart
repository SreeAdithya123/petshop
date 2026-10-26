import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Friendly, user-facing error text for anything the app can throw.
///
/// Raw exception text ('PostgrestException(message: ..., code: ...)') must
/// never reach the screen. [friendlyError] turns network failures, expired
/// sessions, Postgres / PostgREST error codes and Supabase Auth errors into
/// short sentences a customer can act on. `errorText()` in `ui_kit.dart` is
/// the widget-layer entry point and simply calls this.

const String kGenericError = 'Something went wrong. Please try again.';
const String kOfflineError = "You're offline or the connection is unstable. Check your internet and try again.";
const String kTimeoutError = 'This is taking longer than expected. Check your connection and try again.';
const String kSessionExpiredError = 'Your session has expired. Please log in again.';
const String kPermissionError = "You don't have permission to do that.";
const String kServerError = "We're having trouble on our side. Please try again in a moment.";
const String kRpcNotDeployedError = "This action isn't available yet. Please try again later.";
const String kStaleStatusError = "That didn't go through — its status may have changed.";

/// An error whose [message] is already safe and friendly to show as-is.
class UserFacingException implements Exception {
  final String message;

  /// The underlying error, kept for crash reports; never shown to the user.
  final Object? cause;

  const UserFacingException(this.message, {this.cause});

  @override
  String toString() => message;
}

Object _unwrap(Object error) {
  var current = error;
  // Riverpod wraps errors of failed providers; look through (a few levels).
  for (var i = 0; i < 5 && current is ProviderException; i++) {
    current = current.exception;
  }
  return current;
}

/// True when the failure is about connectivity (no internet, DNS, TLS, reset
/// connection) rather than something the server decided.
bool isNetworkError(Object error) {
  final e = _unwrap(error);
  if (e is SocketException ||
      e is HandshakeException ||
      e is TlsException ||
      e is HttpException ||
      e is WebSocketException ||
      e is AuthRetryableFetchException) {
    return true;
  }
  // package:http's ClientException is not a direct dependency of the app, so
  // it is recognised by name.
  final type = e.runtimeType.toString();
  if (type == 'ClientException' || type.contains('SocketException')) return true;
  if (e is UserFacingException || e is PostgrestException || e is AuthException) {
    return false;
  }
  return _looksOffline(e.toString());
}

bool _looksOffline(String text) {
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset') ||
      text.contains('Connection closed') ||
      text.contains('Connection timed out') ||
      text.contains('Software caused connection abort') ||
      text.contains('HandshakeException');
}

/// True for request timeouts.
bool isTimeoutError(Object error) {
  final e = _unwrap(error);
  if (e is TimeoutException) return true;
  if (e is PostgrestException) return e.code == '57014' || e.code == '504' || e.code == '408';
  if (e is AuthException) return e.code == 'request_timeout' || e.statusCode == '504' || e.statusCode == '408';
  return false;
}

/// True when the server rejected the session / JWT (expired, revoked, missing).
bool isSessionExpiredError(Object error) {
  final e = _unwrap(error);
  if (e is AuthSessionMissingException || e is AuthInvalidJwtException) return true;
  if (e is AuthException) {
    final code = (e.code ?? '').toLowerCase();
    if (const {
      'session_expired',
      'session_not_found',
      'session_missing',
      'refresh_token_not_found',
      'refresh_token_already_used',
      'bad_jwt',
      'invalid_jwt',
    }.contains(code)) {
      return true;
    }
    return e.statusCode == '401' && !_isCredentialsError(e);
  }
  if (e is PostgrestException) {
    final code = e.code ?? '';
    return code == 'PGRST301' ||
        code == 'PGRST303' ||
        code == '401' ||
        e.message.toLowerCase().contains('jwt expired') ||
        e.message.toLowerCase().contains('invalid jwt');
  }
  return false;
}

bool _isCredentialsError(AuthException e) {
  final code = (e.code ?? '').toLowerCase();
  final message = e.message.toLowerCase();
  return code == 'invalid_credentials' || message.contains('invalid login credentials');
}

/// True when a database function (RPC) has not been deployed yet.
bool isRpcNotDeployedError(Object error) {
  final e = _unwrap(error);
  if (e is PostgrestException) {
    return e.code == 'PGRST202' ||
        e.code == '42883' ||
        e.message.contains('Could not find the function') ||
        (e.details is String && (e.details as String).contains('Could not find the function'));
  }
  return false;
}

/// True for failures worth retrying automatically: connectivity, timeouts and
/// 5xx responses. Never true for permission / validation / not-found errors.
bool isTransientError(Object error) {
  final e = _unwrap(error);
  if (isNetworkError(e) || isTimeoutError(e)) return true;
  if (e is PostgrestException) {
    final code = e.code ?? '';
    return code == '500' ||
        code == '502' ||
        code == '503' ||
        code == '504' ||
        code == '429' ||
        code == '53300' ||
        code.startsWith('08');
  }
  if (e is AuthException) {
    final status = e.statusCode ?? '';
    return status == '429' || status.startsWith('5');
  }
  return false;
}

/// The friendly message for [error]. Falls back to [fallback] (or a generic
/// sentence) for anything unrecognised; never returns raw exception dumps.
String friendlyError(Object error, {String fallback = kGenericError}) {
  final e = _unwrap(error);

  if (e is UserFacingException) return e.message;
  if (isRpcNotDeployedError(e)) return kRpcNotDeployedError;
  if (isNetworkError(e)) return kOfflineError;
  if (isTimeoutError(e)) return kTimeoutError;
  if (isSessionExpiredError(e)) return kSessionExpiredError;

  if (e is AuthException) return _authMessage(e, fallback);
  if (e is PostgrestException) return _postgrestMessage(e, fallback);
  if (e is StorageException) return _storageMessage(e, fallback);
  if (e is String) return _fromText(e, fallback);
  if (e is FormatException || e is Error) return fallback;
  if (e is PlatformException) return fallback;
  if (e is Exception) return _fromText(e.toString(), fallback);
  return fallback;
}

String _fromText(String raw, String fallback) {
  var text = raw.trim();
  if (text.startsWith('Exception: ')) text = text.substring('Exception: '.length).trim();
  if (text.isEmpty) return fallback;
  if (_looksOffline(text)) return kOfflineError;
  if (text.contains('Could not find the function')) return kRpcNotDeployedError;
  final lower = text.toLowerCase();
  if (lower.contains('jwt expired')) return kSessionExpiredError;
  // Technical dumps ("PostgrestException(message: ...") are never user text.
  final looksTechnical = RegExp(r'^[A-Za-z_]+(Exception|Error)\(').hasMatch(text) ||
      text.startsWith("Instance of '") ||
      (text.contains("type '") && text.contains('is not a subtype'));
  if (looksTechnical) return fallback;
  return text;
}

String _postgrestMessage(PostgrestException e, String fallback) {
  final code = e.code ?? '';
  switch (code) {
    case '42501':
      return kPermissionError;
    case '403':
      return kPermissionError;
    case '23505':
      return 'That already exists. Check your existing entries and try again.';
    case '23503':
      return "That can't be completed because it's linked to other records or something it refers to was removed.";
    case '23502':
      return 'A required detail is missing. Please fill in everything and try again.';
    case '23514':
      return "One of the values isn't allowed. Please check your details and try again.";
    case '22P02':
    case '22007':
    case '22003':
    case '22001':
      return "One of the values isn't in the right format. Please check and try again.";
    case 'PGRST116':
      return "We couldn't find that. It may have been removed.";
    case '404':
      return "We couldn't find that. It may have been removed.";
    case '429':
      return 'Too many requests. Please wait a moment and try again.';
    case '500':
    case '502':
    case '503':
    case '504':
    case '53300':
      return kServerError;
  }
  if (code.startsWith('08')) return kOfflineError;
  // Messages raised deliberately by our own database functions / triggers
  // (RAISE EXCEPTION => SQLSTATE P0001) are written for people.
  if (code == 'P0001' && e.message.trim().isNotEmpty) return e.message.trim();
  if (code.startsWith('PGRST') || code.startsWith('XX') || code.startsWith('42')) return kServerError;
  return fallback;
}

String _authMessage(AuthException e, String fallback) {
  final code = (e.code ?? '').toLowerCase();
  final message = e.message.toLowerCase();

  if (e is AuthWeakPasswordException) {
    return 'Choose a stronger password: at least 8 characters and not easy to guess.';
  }

  switch (code) {
    case 'invalid_credentials':
      return 'Incorrect email or password. Please try again.';
    case 'email_not_confirmed':
      return 'Please confirm your email address first. Check your inbox for the link.';
    case 'user_already_exists':
    case 'email_exists':
      return 'An account with this email already exists. Try logging in instead.';
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
    case 'over_sms_send_rate_limit':
      return 'Too many attempts. Please wait a minute and try again.';
    case 'weak_password':
      return 'Choose a stronger password: at least 8 characters and not easy to guess.';
    case 'same_password':
      return 'Your new password must be different from your current one.';
    case 'user_not_found':
      return "We couldn't find an account with those details.";
    case 'user_banned':
      return 'This account has been suspended. Please contact support.';
    case 'signup_disabled':
    case 'email_provider_disabled':
      return 'Sign-ups are unavailable right now. Please try again later.';
    case 'otp_expired':
    case 'flow_state_expired':
    case 'flow_state_not_found':
    case 'bad_code_verifier':
      return 'This link has expired or was already used. Please request a new one.';
    case 'captcha_failed':
      return 'Verification failed. Please try again.';
    case 'validation_failed':
    case 'bad_json':
      return 'Please check your details and try again.';
    case 'email_address_invalid':
      return "That email address doesn't look valid.";
    case 'email_address_not_authorized':
      return "We can't send email to that address right now.";
    case 'reauthentication_needed':
    case 'reauthentication_not_valid':
      return 'For your security, please log in again to do that.';
    case 'unexpected_failure':
    case 'hook_timeout':
    case 'hook_timeout_after_retry':
      return kServerError;
  }

  // Older auth servers send no machine-readable code.
  if (message.contains('invalid login credentials')) {
    return 'Incorrect email or password. Please try again.';
  }
  if (message.contains('email not confirmed')) {
    return 'Please confirm your email address first. Check your inbox for the link.';
  }
  if (message.contains('already registered') || message.contains('already been registered')) {
    return 'An account with this email already exists. Try logging in instead.';
  }
  if (message.contains('rate limit') || message.contains('too many requests') || e.statusCode == '429') {
    return 'Too many attempts. Please wait a minute and try again.';
  }
  if (message.contains('password should be') || message.contains('weak password')) {
    return 'Choose a stronger password: at least 8 characters and not easy to guess.';
  }
  if (message.contains('different from the old password')) {
    return 'Your new password must be different from your current one.';
  }
  final status = e.statusCode ?? '';
  if (status.startsWith('5')) return kServerError;

  // GoTrue messages are generally written for people; keep short ones.
  final text = e.message.trim();
  if (text.isNotEmpty && text.length <= 140 && !text.contains('Exception')) return text;
  return fallback;
}

String _storageMessage(StorageException e, String fallback) {
  final status = e.statusCode ?? '';
  if (status == '413') return 'That file is too large. Choose a smaller one.';
  if (status == '401' || status == '403') return kPermissionError;
  if (status == '404') return "We couldn't find that file.";
  if (status.startsWith('5')) return kServerError;
  return 'The file could not be uploaded. Please try again.';
}
