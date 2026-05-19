import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      // PKCE is required for OAuth on mobile — sends code verifier in the
      // redirect URL so Supabase can exchange it for a session on the callback.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static String? get accessToken => currentSession?.accessToken;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<AuthResponse> signInWithEmail(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUpWithEmail(String email, String password) {
    return client.auth.signUp(email: email, password: password);
  }

  static Future<void> signOut() => client.auth.signOut();

  static Future<void> resetPassword(String email) {
    return client.auth.resetPasswordForEmail(email);
  }

  static Future<bool> signInWithGoogle() async {
    final res = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.sportgod.app://login-callback',
    );
    return res;
  }
}
