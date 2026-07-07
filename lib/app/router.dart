import 'package:go_router/go_router.dart';

// Placeholder imports for screens
// import '../features/citizen/onboarding/onboarding_screen.dart';
import '../features/citizen/onboarding/splash_screen.dart';
import '../features/citizen/onboarding/onboarding_screen.dart';
import '../features/citizen/onboarding/login_screen.dart';
import '../features/citizen/status_tracker/citizen_home_screen.dart';
import '../features/citizen/submission/submit_screen.dart';
import '../features/dashboard/dashboard_scaffold.dart';
import '../features/dashboard/overview/overview_screen.dart';
import '../features/dashboard/map_hotspots/hotspots_screen.dart';
import '../features/dashboard/ranked_list/rankings_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/citizen/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/citizen/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/citizen/home',
      builder: (context, state) => const CitizenHomeScreen(),
    ),
    GoRoute(
      path: '/citizen/submit',
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'] ?? 'text';
        return SubmitScreen(mode: mode);
      },
    ),
    // MP Dashboard Routes
    ShellRoute(
      builder: (context, state, child) {
        return DashboardScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard/overview',
          builder: (context, state) => const OverviewScreen(),
        ),
        GoRoute(
          path: '/dashboard/hotspots',
          builder: (context, state) => const HotspotsScreen(),
        ),
        GoRoute(
          path: '/dashboard/rankings',
          builder: (context, state) => const RankingsScreen(),
        ),
      ]
    )
  ],
);
