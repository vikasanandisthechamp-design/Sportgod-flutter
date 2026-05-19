/// Centralised environment configuration.
///
/// Every URL / key that was previously declared as a file-local `const` now
/// lives here.  Values are read from compile-time `--dart-define` flags with
/// sensible production defaults so the app works out-of-the-box for local
/// builds.
///
/// Usage:
///   import 'package:sportgod/config/env_config.dart';
///   final url = '${Env.apiBaseUrl}/api/v1/matches';
class Env {
  Env._(); // prevent instantiation

  /// Railway backend REST API.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sportgod-backend-production.up.railway.app',
  );

  /// Railway backend WebSocket endpoint.
  static const wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://sportgod-backend-production.up.railway.app',
  );

  /// Next.js / public web base URL (sportgod.in for contests, sportgod.ai for predictions).
  static const webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://sportgod.in',
  );

  /// Supabase project URL.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nqjbjyfxtfmeumwkdehr.supabase.co',
  );

  /// Supabase anonymous (public) key.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xamJqeWZ4dGZtZXVtd2tkZWhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0NjI2MTUsImV4cCI6MjA1ODAzODYxNX0.FvBzjGXBuSXo5fvVEaMUDTv6RFBHB2LPO4FLiJVZ0hQ',
  );

  /// Razorpay key ID for payment integration.
  static const razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_placeholder', // replace with rzp_live_... for production
  );
}
