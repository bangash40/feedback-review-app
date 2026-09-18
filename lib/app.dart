import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class FeedbackReviewApp extends StatelessWidget {
  const FeedbackReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feedback Review App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Text(
            'Feedback Review App',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
