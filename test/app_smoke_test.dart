import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feedback_review_app/app.dart';

void main() {
  testWidgets('app boots to the home placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FeedbackReviewApp()));
    expect(find.text('Feedback & Review App'), findsOneWidget);
  });
}
