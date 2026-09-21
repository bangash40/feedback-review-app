import 'package:feedback_review_app/core/utils/app_exception.dart';
import 'package:feedback_review_app/core/utils/validators.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('  '), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('a@b.com'), isNull);
      expect(Validators.email(' a@b.com '), isNull);
    });

    test('password needs at least 6 characters', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('name is required and limited to what the rules allow', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('   '), isNotNull);
      expect(Validators.name('Farhan'), isNull);
      expect(Validators.name('x' * 100), isNull);
      expect(Validators.name('x' * 101), isNotNull);
      // Surrounding spaces are trimmed before saving, so they don't count.
      expect(Validators.name('  ${'x' * 100}  '), isNull);
    });

    test(
      'item description is optional but limited to what the rules allow',
      () {
        expect(Validators.itemDescription(null), isNull);
        expect(Validators.itemDescription(''), isNull);
        expect(Validators.itemDescription('x' * 2000), isNull);
        expect(Validators.itemDescription('x' * 2001), isNotNull);
      },
    );

    test('confirmPassword must match', () {
      expect(Validators.confirmPassword('', 'secret1'), isNotNull);
      expect(Validators.confirmPassword('other', 'secret1'), isNotNull);
      expect(Validators.confirmPassword('secret1', 'secret1'), isNull);
    });
  });

  group('AppException.from', () {
    test('maps Firebase auth codes to friendly messages', () {
      String msg(String code) =>
          AppException.from(FirebaseAuthException(code: code)).message;

      expect(
        msg('invalid-credential'),
        contains('Incorrect email or password'),
      );
      expect(msg('wrong-password'), contains('Incorrect email or password'));
      expect(msg('email-already-in-use'), contains('already exists'));
      expect(msg('weak-password'), contains('stronger password'));
      expect(msg('network-request-failed'), contains('internet'));
      expect(msg('something-unknown'), contains('Authentication failed'));
    });

    test('user-not-found suggests signing up; other errors do not', () {
      final missing = AppException.from(
        FirebaseAuthException(code: 'user-not-found'),
      );
      expect(missing.suggestSignUp, isTrue);
      expect(missing.message, contains('sign up'));

      expect(
        AppException.from(FirebaseAuthException(code: 'invalid-credential'))
            .suggestSignUp,
        isFalse,
      );
    });

    test('maps the other Firestore failures to friendly messages', () {
      String msg(String code) => AppException.from(
        FirebaseException(plugin: 'cloud_firestore', code: code),
      ).message;

      expect(msg('unauthenticated'), contains('log in'));
      expect(msg('aborted'), contains('try again'));
      expect(msg('deadline-exceeded'), contains('too long'));
      expect(msg('resource-exhausted'), contains('Too many'));
      expect(msg('failed-precondition'), contains('try again'));
      expect(msg('some-new-code'), 'Something went wrong. Please try again.');
    });

    test('maps Firestore permission errors', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(AppException.from(error).message, contains('permission'));
    });

    test('unknown errors get a generic message', () {
      expect(
        AppException.from(StateError('boom')).message,
        'Something went wrong. Please try again.',
      );
    });
  });
}
