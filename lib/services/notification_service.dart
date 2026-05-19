import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';
import '../router/app_router.dart';

/// Handles Firebase Cloud Messaging push notifications.
///
/// SETUP (one-time — founder action required):
///   1. Go to https://console.firebase.google.com → Create project "SportGod AI"
///   2. Add Android app (package: com.sportgod.app) → download google-services.json
///      → place at android/app/google-services.json
///   3. Add iOS app (bundle ID: com.sportgod.app) → download GoogleService-Info.plist
///      → place at ios/Runner/GoogleService-Info.plist
///   4. Run: `flutterfire configure` (installs firebase_options.dart)
///      → This generates lib/firebase_options.dart with your project's config
///   5. main.dart already initializes Firebase + Crashlytics + registers background handler
///   6. In Railway backend: set FIREBASE_PROJECT_ID + FIREBASE_SERVICE_ACCOUNT_JSON env vars
///
/// Notification types we send:
///   - match_start: "CSK vs MI starts in 5 minutes. Build your team now!"
///   - wicket: "WICKET! Kohli out for 45. MI in trouble at 89/4"
///   - fantasy_result: "You ranked #47 this week! Your team scored 312 pts"
class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static String? _fcmToken;

  /// Call once on app start (after Firebase.initializeApp).
  static Future<void> init() async {
    try {
      // Request permission (iOS requires explicit prompt; Android 13+ does too)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');

      // Get the FCM token for this device
      _fcmToken = await _fcm.getToken();
      debugPrint('FCM token: $_fcmToken');

      // Refresh token handler
      _fcm.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _uploadToken(token);
      });

      // Upload current token to backend
      if (_fcmToken != null) await _uploadToken(_fcmToken!);

      // Foreground message handler (app is open)
      FirebaseMessaging.onMessage.listen(_handleForeground);

      // Background / terminated tap handler
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    } catch (e) {
      // Non-fatal — app works without push notifications
      debugPrint('NotificationService init error: $e');
    }
  }

  static String? get fcmToken => _fcmToken;

  /// Upload FCM token to backend so it can send targeted push notifications.
  /// Calls POST /api/v1/notifications/register-device (requires auth).
  static Future<void> _uploadToken(String token) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint('FCM token upload skipped — user not authenticated');
        return;
      }

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      final res = await http.post(
        Uri.parse('${Env.apiBaseUrl}/api/v1/notifications/register-device'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: json.encode({'fcm_token': token, 'platform': platform}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        debugPrint('FCM token registered successfully');
      } else {
        debugPrint('FCM token registration failed: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Token upload failed: $e');
    }
  }

  /// Show an in-app banner for foreground notifications.
  static void _handleForeground(RemoteMessage message) {
    debugPrint('FCM foreground: ${message.notification?.title} — ${message.notification?.body}');
    // The EventToast pattern from the web can be replicated here.
    // For now, Firebase automatically shows a notification on Android.
    // For iOS foreground, add flutter_local_notifications for a custom banner.
  }

  /// Navigate to the right screen when user taps a notification.
  /// Backend sends: { "type": "match_start"|"ball_event"|"fantasy_result", "match_id": "12345" }
  static void _handleTap(RemoteMessage message) {
    final data    = message.data;
    final type    = data['type'] as String?;
    final matchId = data['match_id'] as String?;

    debugPrint('FCM tap: type=$type matchId=$matchId');

    if (matchId == null || matchId.isEmpty) return;
    final router = appRouter;
    if (router == null) return;

    switch (type) {
      case 'match_start':
      case 'ball_event':
      case 'wicket':
      case 'score_update':
        router.go('/match/$matchId');
      case 'fantasy_result':
        router.go('/contests/$matchId');
      case 'predict':
        router.go('/predict/$matchId');
      default:
        router.go('/match/$matchId');
    }
  }
}

/// Background message handler — must be a top-level function (not a method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background: ${message.notification?.title}');
  // Don't do heavy work here — just log and exit.
  // The notification is shown by the system automatically.
}
