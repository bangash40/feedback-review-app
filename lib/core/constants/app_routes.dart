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

  static const itemDetailPattern = '/item/:id';
  static String itemDetail(String id) => '/item/$id';

  static const feedbackFormPattern = '/item/:id/feedback';
  static String feedbackForm(String itemId) => '/item/$itemId/feedback';

  static const myFeedback = '/my-feedback';

  static const adminFeedbackPattern = '/admin/feedback/:id';
  static String adminFeedback(String id) => '/admin/feedback/$id';

  static const adminUsers = '/admin/users';

  static const adminItems = '/admin/items';
  static const adminItemNew = '/admin/items/new';
  static const adminItemEditPattern = '/admin/items/:id';
  static String adminItemEdit(String id) => '/admin/items/$id';

  /// Routes reachable while signed out.
  static const publicRoutes = {login, register, forgotPassword};
}
