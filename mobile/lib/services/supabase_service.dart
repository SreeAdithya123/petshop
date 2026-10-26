import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class SupabaseService {
  static bool _initialized = false;

  /// Idempotent: safe to call again after a failed start-up (the "Retry"
  /// button on the start-up error screen).
  static Future<void> init() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
