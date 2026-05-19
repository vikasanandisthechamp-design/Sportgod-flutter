import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/match_screen.dart';
import '../screens/fantasy/team_builder_screen.dart';
import '../screens/predictions/predict_screen.dart';
import '../screens/contests/contests_screen.dart';
import '../screens/partner/partner_screen.dart';
import '../screens/legal/privacy_screen.dart';
import '../screens/legal/terms_screen.dart';
import '../screens/player_screen.dart';
import '../screens/premium_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/search_screen.dart';

/// Singleton router instance — usable from anywhere (e.g. notification taps).
GoRouter? appRouter;

/// Builds a [GoRouter] bound to [auth] so redirects fire on sign-in / sign-out.
///
/// The router always starts at `/splash`; the [SplashScreen] reads the
/// onboarding flag and navigates to `/` or `/onboarding` after a short delay.
GoRouter buildRouter(AuthProvider auth) {
  final router = GoRouter(
    debugLogDiagnostics: false,
    initialLocation: '/splash',
    refreshListenable: auth,

    // ── Auth redirect ─────────────────────────────────────────────────────────
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Always allow splash and onboarding through without auth
      if (loc == '/splash' || loc == '/onboarding') return null;

      final loggedIn   = auth.isLoggedIn;
      final goingLogin = loc == '/login';
      if (!loggedIn && !goingLogin) return '/login';
      if (loggedIn  && goingLogin)  return '/';
      return null;
    },

    routes: [
      // Splash — in-app loading screen shown during initialization
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // Onboarding (first launch only)
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),

      // Login
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),

      // Shell (bottom-nav home — handles its own tab switching internally)
      GoRoute(
        path: '/',
        builder: (_, __) => const ShellScreen(),
      ),

      // ── Deep-linkable screens ─────────────────────────────────────────────

      // Match detail: sportgod://match/12345
      GoRoute(
        path: '/match/:matchId',
        builder: (_, state) => MatchScreen(
          matchId: state.pathParameters['matchId']!,
        ),
      ),

      // Fantasy builder: sportgod://fantasy/build/12345
      GoRoute(
        path: '/fantasy/build/:matchId',
        builder: (_, state) => TeamBuilderScreen(
          matchId: state.pathParameters['matchId']!,
        ),
      ),

      // Predictions: sportgod://predict/12345
      GoRoute(
        path: '/predict/:matchId',
        builder: (_, state) => PredictScreen(
          matchId: state.pathParameters['matchId']!,
        ),
      ),

      // Contests: sportgod://contests/12345?team_code=SG-ABC&tab=private
      GoRoute(
        path: '/contests/:matchId',
        builder: (_, state) {
          final matchId  = state.pathParameters['matchId']!;
          final teamCode = state.uri.queryParameters['team_code'];
          final tab      = state.uri.queryParameters['tab'];
          return ContestsScreen(
            matchId:    matchId,
            teamCode:   teamCode,
            initialTab: tab == 'private' ? 1 : 0,
          );
        },
      ),

      // Chat — deep linkable (also navigated to from Profile)
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),

      // Premium upgrade
      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),

      // Edit profile
      GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),

      // Global leaderboard
      GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),

      // Player profile: sportgod://player/12345?name=Virat+Kohli
      GoRoute(
        path: '/player/:playerId',
        builder: (_, state) => PlayerScreen(
          playerId:   state.pathParameters['playerId']!,
          playerName: state.uri.queryParameters['name'] ?? '',
        ),
      ),

      // Search
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),

      // Static pages
      GoRoute(path: '/partner', builder: (_, __) => const PartnerScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/terms',   builder: (_, __) => const TermsScreen()),
    ],
  );
  appRouter = router;
  return router;
}
