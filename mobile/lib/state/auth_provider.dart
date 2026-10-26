import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../core/app_error.dart';
import '../core/async_utils.dart';
import '../core/crash_reporter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

enum AuthStatus { loading, signedOut, signedIn }

/// Mirrors src/store/authStore.js from the web app: session + profile +
/// status, with the same signUp/signIn/signOut/roleHomePath shape.
///
/// Resilience rules:
///  * A failed profile load (network blip, timeout, 5xx) never signs the user
///    out. The session is kept, [profileFailed] is set, [status] stays
///    [AuthStatus.loading] while the load is retried with backoff, and anyone
///    can force another attempt with [refreshProfile].
///  * Token refreshes and session recoveries for the account that is already
///    loaded never reload (or drop) the profile.
///  * Only a definite "this account has no profile row" result, or an
///    explicit sign-out / revoked session, ends the session.
class AuthController extends ChangeNotifier {
  AuthController() {
    _init();
  }

  final SupabaseClient _client = SupabaseService.client;
  StreamSubscription<AuthState>? _authSub;
  Timer? _retryTimer;
  Future<void>? _profileInFlight;
  int _retryAttempt = 0;
  bool _disposed = false;

  static const List<Duration> _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 30),
  ];

  Session? session;

  /// Plain field on purpose: screens that save the profile assign it directly.
  Profile? profile;
  AuthStatus status = AuthStatus.loading;

  /// True while a session exists but its profile could not be loaded (for
  /// example no connection). [status] stays [AuthStatus.loading] meanwhile.
  bool profileFailed = false;

  /// True after the user opened a password-reset link and until they set a new
  /// password (or sign out). The router sends them to /reset-password.
  bool passwordRecovery = false;

  /// Friendly message when an emailed link (password reset, confirmation)
  /// could not be used, for example because it expired. Cleared on the next
  /// successful sign-in / recovery.
  String? linkError;

  /// Signed in with a loaded profile.
  bool get isSignedIn => status == AuthStatus.signedIn && profile != null;

  void _init() {
    session = _client.auth.currentSession;
    if (session == null) {
      status = AuthStatus.signedOut;
    } else {
      status = AuthStatus.loading;
      unawaited(_loadProfile());
    }
    // The auth stream replays earlier events (initial session, password
    // recovery deep links), so nothing is missed by subscribing late.
    _authSub = _client.auth.onAuthStateChange.listen(_onAuthEvent, onError: _onAuthStreamError);
  }

  void _onAuthStreamError(Object error, StackTrace stack) {
    // Token refresh failures while offline land here; gotrue keeps the
    // session and retries, so this is not a reason to sign out.
    if (isNetworkError(error) || isTimeoutError(error)) return;
    if (error is AuthException) {
      // Typically an expired or already-used emailed link (deep link); the
      // reset-password screen shows this instead of waiting forever.
      linkError = friendlyError(error);
      _notify();
      return;
    }
    CrashReporting.report(error, stack, reason: 'auth stream');
  }

  void _onAuthEvent(AuthState data) {
    if (_disposed) return;
    final event = data.event;
    final next = data.session;

    if (event == AuthChangeEvent.signedOut) {
      _clearUser();
      _notify();
    } else if (event == AuthChangeEvent.passwordRecovery) {
      passwordRecovery = true;
      linkError = null;
      _applySession(next);
    } else if (event == AuthChangeEvent.tokenRefreshed) {
      if (next != null) session = next;
      if (session != null && profile == null && !profileFailed) unawaited(_loadProfile());
    } else if (event == AuthChangeEvent.userUpdated) {
      if (next != null) session = next;
      _notify();
    } else {
      // initialSession, signedIn, mfaChallengeVerified.
      _applySession(next);
    }
  }

  void _applySession(Session? next) {
    if (next == null) {
      _clearUser();
      _notify();
      return;
    }
    final loaded = profile;
    session = next;
    linkError = null;
    if (loaded != null && loaded.id == next.user.id) {
      // Same account (session recovery / token refresh): keep the profile.
      if (status != AuthStatus.signedIn) {
        status = AuthStatus.signedIn;
        _notify();
      }
      return;
    }
    profile = null;
    status = AuthStatus.loading;
    profileFailed = false;
    _notify();
    unawaited(_loadProfile());
  }

  void _clearUser() {
    session = null;
    profile = null;
    status = AuthStatus.signedOut;
    profileFailed = false;
    passwordRecovery = false;
    linkError = null;
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      CrashReporting.instance.setUserId(null);
    } catch (_) {
      // Reporter problems must not affect sign-out.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------- profile

  /// Loads the signed-in user's profile. Concurrent callers share one request.
  Future<void> _loadProfile({bool force = false}) {
    final running = _profileInFlight;
    if (running != null) return running;
    final future = _fetchProfile(force: force).whenComplete(() => _profileInFlight = null);
    _profileInFlight = future;
    return future;
  }

  Future<void> _fetchProfile({required bool force}) async {
    final userId = session?.user.id;
    if (userId == null) return;
    if (!force && profile?.id == userId) {
      if (status != AuthStatus.signedIn) {
        status = AuthStatus.signedIn;
        _notify();
      }
      return;
    }

    var missingRows = 0;
    while (true) {
      Map<String, dynamic>? row;
      try {
        row = await withTimeout(
          _client.from('profiles').select().eq('id', userId).maybeSingle(),
        );
      } catch (error, stack) {
        if (_disposed || session?.user.id != userId) return;
        _onProfileError(error, stack);
        return;
      }
      if (_disposed || session?.user.id != userId) return;

      if (row != null) {
        try {
          profile = Profile.fromJson(row);
        } catch (error, stack) {
          _onProfileError(error, stack);
          return;
        }
        status = AuthStatus.signedIn;
        profileFailed = false;
        _retryAttempt = 0;
        _retryTimer?.cancel();
        _retryTimer = null;
        try {
          CrashReporting.instance.setUserId(userId);
        } catch (_) {
          // Ignore reporter problems.
        }
        _notify();
        return;
      }

      // No row: the profile trigger may lag a moment behind sign-up.
      missingRows++;
      if (missingRows >= 2) break;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (_disposed || session?.user.id != userId) return;
    }

    // The account really has no profile; nothing in the app can work for it.
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Signed out locally either way.
    }
    if (_disposed) return;
    _clearUser();
    _notify();
  }

  void _onProfileError(Object error, StackTrace stack) {
    if (!isNetworkError(error) && !isTimeoutError(error)) {
      CrashReporting.report(error, stack, reason: 'profile load');
    }
    final loaded = profile;
    if (loaded != null && loaded.id == session?.user.id) {
      // A background refresh failed; the profile we already have is fine.
      return;
    }
    status = AuthStatus.loading;
    profileFailed = true;
    _notify();
    _scheduleProfileRetry();
  }

  void _scheduleProfileRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_disposed || _retryAttempt >= _retryDelays.length) return;
    final delay = _retryDelays[_retryAttempt];
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_disposed || session == null) return;
      unawaited(_loadProfile(force: true));
    });
  }

  /// Reloads the profile now (also resets the automatic retry schedule).
  /// Returns true when a profile is available afterwards.
  Future<bool> refreshProfile() async {
    if (session == null) return false;
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _loadProfile(force: true);
    return profile != null;
  }

  // ------------------------------------------------------------------ flows

  UserFacingException _asFailure(Object error, StackTrace stack) {
    if (error is UserFacingException) return error;
    if (error is! AuthException && !isNetworkError(error) && !isTimeoutError(error)) {
      CrashReporting.report(error, stack, reason: 'auth');
    }
    return UserFacingException(friendlyError(error), cause: error);
  }

  /// Returns true if sign-up needs email confirmation before a session exists.
  /// Throws [UserFacingException] with a friendly message on failure.
  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final AuthResponse response;
    try {
      response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name, 'full_name': name, 'phone': phone, 'role': role},
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(_asFailure(error, stack), stack);
    }

    final newSession = response.session;
    if (newSession == null) {
      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        // Supabase answers "success" for an address that is already registered
        // but hands back a user with no identities.
        throw const UserFacingException(
          'An account with this email already exists. Try logging in or resetting your password.',
        );
      }
      return true; // needs email confirmation
    }
    _applySession(newSession);
    await _loadProfile(force: true);
    return false;
  }

  /// Signs in. When the credentials work but the profile cannot be loaded
  /// right now, the session is kept ([profileFailed] is set and loading is
  /// retried) so callers should check [profile] before routing by role.
  Future<void> signIn({required String email, required String password}) async {
    final AuthResponse response;
    try {
      response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(_asFailure(error, stack), stack);
    }
    final newSession = response.session;
    if (newSession == null) {
      throw const UserFacingException("Couldn't log you in. Check your details and try again.");
    }
    _applySession(newSession);
    await _loadProfile(force: true);
  }

  /// Signs out on this device. Never throws: even when the server call fails
  /// (offline), the local session has already been removed.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error, stack) {
      if (!isNetworkError(error) && !isTimeoutError(error) && error is! AuthException) {
        CrashReporting.report(error, stack, reason: 'sign out');
      }
    }
    _clearUser();
    _notify();
  }

  /// Emails a password-reset link that opens the app ([AppEnv.authRedirect]).
  ///
  /// An unknown address is treated exactly like a known one so the screen
  /// can't be used to find out who has an account.
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppEnv.authRedirect,
      );
    } on AuthException catch (error, stack) {
      if ((error.code ?? '').toLowerCase() == 'user_not_found') return;
      Error.throwWithStackTrace(_asFailure(error, stack), stack);
    } catch (error, stack) {
      Error.throwWithStackTrace(_asFailure(error, stack), stack);
    }
  }

  /// Sets a new password for the current session (used after following a
  /// password-reset link, or from account settings).
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (error, stack) {
      Error.throwWithStackTrace(_asFailure(error, stack), stack);
    }
    passwordRecovery = false;
    _notify();
  }

  /// Sends the sign-up confirmation email again.
  Future<void> resendConfirmation(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email.trim());
    } catch (error, stack) {
      Error.throwWithStackTrace(_asFailure(error, stack), stack);
    }
  }

  /// Deletes / anonymises the signed-in customer's account through the
  /// `delete_my_account()` database function, then signs out. Shop owners get
  /// the server's message telling them to contact support first. Until the
  /// function is deployed the friendly "isn't available yet" error is thrown.
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_my_account');
    } catch (error, stack) {
      Error.throwWithStackTrace(_asFailure(error, stack), stack);
    }
    await signOut();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    unawaited(_authSub?.cancel());
    _authSub = null;
    super.dispose();
  }
}

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController();
});

/// Mirrors roleHomePath() from src/store/authStore.js.
String roleHomePath(String? role) {
  switch (role) {
    case 'admin':
      return '/admin/dashboard';
    case 'shop_owner':
      return '/seller/dashboard';
    default:
      return '/account';
  }
}
