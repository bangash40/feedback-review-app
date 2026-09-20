import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/items/home_screen.dart';
import '../../providers/auth_providers.dart';
import '../constants/app_routes.dart';

/// Re-runs the router's redirect whenever auth or profile state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Auth guard:
/// - while auth or the profile is still loading, stay on the splash screen;
/// - signed out users may only see the public auth screens;
/// - signed in users are sent past the auth screens to their landing page
///   (admins to the dashboard, everyone else to home);
/// - non-admins are kept out of `/admin*`.
String? _redirect(Ref ref, String location) {
  final auth = ref.read(authStateProvider);
  if (auth.isLoading) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  if (auth.value == null) {
    return AppRoutes.publicRoutes.contains(location) ? null : AppRoutes.login;
  }

  final profile = ref.read(currentUserProvider);
  if (profile.isLoading) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  // A missing profile document is treated as a plain user.
  final isAdmin = profile.value?.isAdmin ?? false;
  final landing = isAdmin ? AppRoutes.admin : AppRoutes.home;

  if (location == AppRoutes.splash ||
      AppRoutes.publicRoutes.contains(location)) {
    return landing;
  }
  if (location.startsWith(AppRoutes.admin) && !isAdmin) return AppRoutes.home;
  return null;
}
