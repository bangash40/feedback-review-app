/// Form field validators. Each returns an error message, or null when valid.
class Validators {
  const Validators._();

  static const minPasswordLength = 6;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your name';
    return null;
  }

  static const maxTitleLength = 80;

  static String? itemTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Enter a title';
    if (title.length > maxTitleLength) {
      return 'Title must be $maxTitleLength characters or fewer';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }
}
