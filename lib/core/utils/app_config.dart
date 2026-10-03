/// Public client configuration. Replace placeholders to use your own backend.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = 'https://backend.invalid';
  static const supabasePublishableKey =
      'sb_publishable_development_placeholder';
  static const sentryDsn = '';
}
