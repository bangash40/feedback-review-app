import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/app.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/providers/firebase_providers.dart';
import 'package:feedback_review_app/services/auth_service.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

Widget buildApp(MockFirebaseAuth auth, FakeFirebaseFirestore db) {
  return ProviderScope(
    // No retries: a failing stream should surface, not leave timers pending.
    retry: (_, _) => null,
    overrides: [
      authServiceProvider.overrideWithValue(AuthService(auth: auth)),
      firestoreServiceProvider.overrideWithValue(
        FirestoreService(firestore: db),
      ),
    ],
    child: const FeedbackReviewApp(),
  );
}

Future<void> seedProfile(
  FakeFirebaseFirestore db, {
  required String uid,
  required String name,
  required UserRole role,
}) {
  return db
      .collection('users')
      .doc(uid)
      .set(
        AppUser(
          uid: uid,
          name: name,
          email: '$uid@example.com',
          role: role,
          createdAt: DateTime(2026),
        ).toMap(),
      );
}

/// A mock auth whose email sign-in always fails with [code].
MockFirebaseAuth authFailingSignIn(String code) {
  final auth = MockFirebaseAuth();
  whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
      .on(auth)
      .thenThrow(FirebaseAuthException(code: code));
  return auth;
}

/// An [AuthService] whose sign-in can be held open via [gate], so a test can
/// inspect the screen while the request is in flight (as on a real network).
class GatedAuthService extends AuthService {
  GatedAuthService(MockFirebaseAuth auth) : super(auth: auth);

  Completer<void>? gate;

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    await gate?.future;
    return super.signIn(email: email, password: password);
  }
}

void main() {
  testWidgets('signed out users land on the login screen', (tester) async {
    await tester.pumpWidget(
      buildApp(MockFirebaseAuth(), FakeFirebaseFirestore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('login form shows validation errors and does not submit', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    await tester.pumpWidget(buildApp(auth, FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('register creates the account and lands on home', (tester) async {
    final auth = MockFirebaseAuth();
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(buildApp(auth, db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Test User',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Test User'), findsOneWidget);
    final profile = await db
        .collection('users')
        .doc(auth.currentUser!.uid)
        .get();
    expect(profile.data()!['role'], 'user');
  });

  testWidgets('mismatched confirm password is rejected', (tester) async {
    final auth = MockFirebaseAuth();
    await tester.pumpWidget(buildApp(auth, FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'T',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'different',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('an already signed-in user skips login (session persists)', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'u1@example.com'),
    );
    await tester.pumpWidget(buildApp(auth, db));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Sam'), findsOneWidget);
  });

  testWidgets('admins land on the admin dashboard', (tester) async {
    final db = FakeFirebaseFirestore();
    await seedProfile(db, uid: 'a1', name: 'Boss', role: UserRole.admin);
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'a1', email: 'a1@example.com'),
    );
    await tester.pumpWidget(buildApp(auth, db));
    await tester.pumpAndSettle();

    expect(find.text('Admin dashboard'), findsOneWidget);
  });

  testWidgets('log out returns to the login screen', (tester) async {
    final db = FakeFirebaseFirestore();
    await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'u1@example.com'),
    );
    await tester.pumpWidget(buildApp(auth, db));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('forgot password validates then returns to login', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    await tester.pumpWidget(buildApp(auth, FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('reset link has been sent'), findsOneWidget);
  });

  testWidgets('unknown account shows a pop-up that leads to sign up', (
    tester,
  ) async {
    final auth = authFailingSignIn('user-not-found');
    await tester.pumpWidget(buildApp(auth, FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'nobody@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('No account found'), findsOneWidget);
    expect(find.textContaining('Please sign up'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('cancelling the no-account pop-up stays on login', (
    tester,
  ) async {
    final auth = authFailingSignIn('user-not-found');
    await tester.pumpWidget(buildApp(auth, FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'nobody@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('wrong password shows a snackbar, not the no-account pop-up', (
    tester,
  ) async {
    final auth = authFailingSignIn('invalid-credential');
    await tester.pumpWidget(buildApp(auth, FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Incorrect email or password'), findsOneWidget);
  });

  testWidgets('forgot password for an unknown email shows exactly one pop-up', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    whenCalling(Invocation.method(#sendPasswordResetEmail, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'user-not-found'));
    await tester.pumpWidget(buildApp(auth, FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'nobody@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('No account found'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('a failed login does not replay its pop-up on the next attempt', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    // Only the unregistered email fails; any other email signs in.
    whenCalling(
      Invocation.method(#signInWithEmailAndPassword, null, {
        #email: 'nobody@example.com',
      }),
    ).on(auth).thenThrow(FirebaseAuthException(code: 'user-not-found'));
    final service = GatedAuthService(auth);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authServiceProvider.overrideWithValue(service),
          firestoreServiceProvider.overrideWithValue(
            FirestoreService(firestore: FakeFirebaseFirestore()),
          ),
        ],
        child: const FeedbackReviewApp(),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> submit(String email) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    }

    await submit('nobody@example.com');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Second attempt: keep the request in flight and look at the screen.
    final gate = service.gate = Completer<void>();
    await submit('real@example.com');
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Welcome, '), findsOneWidget);
  });
}
