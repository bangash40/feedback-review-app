import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Duration? _noRetry(int retryCount, Object error) => null;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const ProviderScope(
      // Riverpod retries failed providers silently by default. Turn that off so
      // a failed load shows its error and Retry button right away.
      retry: _noRetry,
      child: FeedbackReviewApp(),
    ),
  );
}
