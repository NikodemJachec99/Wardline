/// Build-time configuration passed with `--dart-define-from-file=.env.json`.
///
/// Only the public anon key belongs here. The `service_role` key must never
/// reach the app or the repository.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
