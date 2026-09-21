/// Form field validators. Each returns an error message, or null when valid.
class Validators {
  const Validators._();

  static const minPasswordLength = 6;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Matches the limit in the Firestore security rules.
  static const maxNameLength = 100;

  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your name';
    if (name.length > maxNameLength) {
      return 'Name must be $maxNameLength characters or fewer';
    }
    return null;
  }

  /// Matches the limit in the Firestore security rules.
  static const maxDescriptionLength = 2000;

  static String? itemDescription(String? value) {
    if ((value?.trim().length ?? 0) > maxDescriptionLength) {
      return 'Description must be $maxDescriptionLength characters or fewer';
    }
    return null;
  }

  static const maxFeedbackTextLength = 1000;

  static String? rating(int? value) {
    if (value == null || value < 1 || value > 5) {
      return 'Please select a rating';
    }
    return null;
  }

  static String? feedbackText(String? value) {
    if ((value?.trim().length ?? 0) > maxFeedbackTextLength) {
      return 'Keep this under $maxFeedbackTextLength characters';
    }
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
