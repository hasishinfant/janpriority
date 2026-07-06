import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jan_priority/main.dart';

void main() {
  testWidgets('App smoke test - verifies onboarding text', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: JanPriorityApp(),
      ),
    );

    // Verify that onboarding screen shows the welcome text.
    expect(find.text('Welcome to JanPriority'), findsOneWidget);
  });
}

