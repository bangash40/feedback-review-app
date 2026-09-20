/// Route paths used by go_router. Kept apart from the router config so
/// screens can navigate without importing the router (and every screen).
class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot';
  static const home = '/home';
  static const admin = '/admin';

  /// Routes reachable while signed out.
  static const publicRoutes = {login, register, forgotPassword};
}
