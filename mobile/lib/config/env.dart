/// Supabase project config, ported from the web app's .env.
///
/// The anon key is public-by-design (RLS-gated, not a secret) -- same
/// reasoning as the web app, see docs/decisions.md in the repo root.
class Env {
  static const supabaseUrl = 'https://pytkeurgdbhekyppfblh.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5dGtldXJnZGJoZWt5cHBmYmxoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0NzQ0NDAsImV4cCI6MjEwNTA1MDQ0MH0.Mm2YEccm7GgZ0OrXpiXPe9IwGvunTD3m3LRjB2Xo-2M';
}
