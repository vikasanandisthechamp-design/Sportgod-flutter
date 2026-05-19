import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/coins_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Global navigator key — allows push navigation from notification taps
/// (outside the widget tree, e.g. in NotificationService._handleTap).
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase — graceful failure
  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  // Initialize Firebase (requires google-services.json / GoogleService-Info.plist).
  // Fails silently when the config files haven't been added yet (pre-flutterfire configure).
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;

    // Register background message handler (must be registered before runApp)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Capture all Flutter framework errors → Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Capture async errors outside the Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Firebase init skipped (config not found): $e');
  }

  // Initialize FCM push notifications if Firebase is ready
  if (firebaseReady) {
    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Onboarding check is now handled by SplashScreen — no need to read prefs here.

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CoinsProvider()),
      ],
      child: const SportGodApp(),
    ),
  );
}

class SportGodApp extends StatelessWidget {
  const SportGodApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final router = buildRouter(auth);

    return MaterialApp.router(
      title: 'SportGod AI',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
