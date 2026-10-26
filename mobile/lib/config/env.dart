/// Supabase project config, ported from the web app's .env.
///
/// The anon key is public-by-design (RLS-gated, not a secret) -- same
/// reasoning as the web app, see docs/decisions.md in the repo root.
class Env {
  static const supabaseUrl = 'https://pytkeurgdbhekyppfblh.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5dGtldXJnZGJoZWt5cHBmYmxoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0NzQ0NDAsImV4cCI6MjEwNTA1MDQ0MH0.Mm2YEccm7GgZ0OrXpiXPe9IwGvunTD3m3LRjB2Xo-2M';
}

/// App-level (non-secret) configuration shared across the app.
class AppEnv {
  AppEnv._();

  /// Deep link that Supabase auth emails send the user back to. The scheme and
  /// host must be registered in the Android manifest (intent filter) and the
  /// iOS Info.plist (CFBundleURLTypes), and added to the Supabase dashboard's
  /// allowed redirect URLs, for password-reset links to open the app.
  static const authRedirect = 'io.supabase.petsta://reset-callback/';

  /// Host of [authRedirect]; used by the router to recognise the deep link.
  static const authRedirectHost = 'reset-callback';

  /// Refresh the catalog when the app comes back from the background after at
  /// least this long.
  static const resumeRefreshAfter = Duration(minutes: 5);

  /// How long app start-up (Supabase init) may take before it is treated as
  /// failed and the "Can't start PETSTA" screen is shown.
  static const startupTimeout = Duration(seconds: 20);

  /// Default ceiling for a single network request made by a provider.
  static const requestTimeout = Duration(seconds: 20);
}
