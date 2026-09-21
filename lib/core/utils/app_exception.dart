import 'package:firebase_auth/firebase_auth.dart';

/// A failure with a message that is safe to show to the user.
class AppException implements Exception {
  const AppException(this.message, {this.suggestSignUp = false});

  final String message;

  /// True when the failure means the account does not exist, so the UI can
  /// offer to take the user to the sign-up screen.
  final bool suggestSignUp;

  /// Converts anything thrown by Firebase into a user-friendly exception.
  factory AppException.from(Object error) {
    if (error is AppException) return error;
    // FirebaseAuthException extends FirebaseException, so check it first.
    if (error is FirebaseAuthException) {
      if (error.code == 'user-not-found') {
        return const AppException(
          'No account found for this email. Please sign up to create one.',
          suggestSignUp: true,
        );
      }
      return AppException(_authMessage(error.code));
    }
    if (error is FirebaseException) {
      return AppException(_firebaseMessage(error.code));
    }
    return const AppException('Something went wrong. Please try again.');
  }

  static String _authMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      // With email enumeration protection on (the default for new Firebase
      // projects) a wrong password and an unknown email both come back as
      // invalid-credential, so the two cannot be told apart.
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. New here? Sign up to create an account.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this app.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  static String _firebaseMessage(String code) {
    switch (code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Service unavailable. Check your connection and try again.';
      case 'not-found':
        return 'The requested data could not be found.';
      case 'unauthenticated':
        return 'Please log in again.';
      // A transaction that lost a race with another writer; retrying works.
      case 'aborted':
        return 'That was busy. Please try again.';
      case 'deadline-exceeded':
        return 'That took too long. Check your connection and try again.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'failed-precondition':
        return "That isn't possible right now. Please try again.";
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => message;
}
