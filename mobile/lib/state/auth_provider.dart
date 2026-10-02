import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

enum AuthStatus { loading, signedOut, signedIn }

/// Mirrors src/store/authStore.js from the web app: session + profile +
/// status, with the same signUp/signIn/signOut/roleHomePath shape.
class AuthController extends ChangeNotifier {
  AuthController() {
    _init();
  }

  Session? session;
  Profile? profile;
  AuthStatus status = AuthStatus.loading;

  Future<void> _init() async {
    final client = SupabaseService.client;
    session = client.auth.currentSession;
    if (session != null) {
      await _loadProfile();
    } else {
      status = AuthStatus.signedOut;
    }
    notifyListeners();

    client.auth.onAuthStateChange.listen((data) async {
      session = data.session;
      if (session != null) {
        await _loadProfile();
      } else {
        profile = null;
        status = AuthStatus.signedOut;
      }
      notifyListeners();
    });
  }

  Future<void> _loadProfile() async {
    final userId = session?.user.id;
    if (userId == null) {
      status = AuthStatus.signedOut;
      return;
    }
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      profile = row != null ? Profile.fromJson(row) : null;
      status = profile != null ? AuthStatus.signedIn : AuthStatus.signedOut;
    } catch (_) {
      status = AuthStatus.signedOut;
    }
  }

  /// Returns true if sign-up needs email confirmation before a session exists.
  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final response = await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'phone': phone, 'role': role},
    );
    if (response.session == null) {
      return true; // needs email confirmation
    }
    session = response.session;
    await _loadProfile();
    notifyListeners();
    return false;
  }

  Future<void> signIn({required String email, required String password}) async {
    final response = await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    session = response.session;
    await _loadProfile();
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
    session = null;
    profile = null;
    status = AuthStatus.signedOut;
    notifyListeners();
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
