// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:starbucks_card_animation/main.dart';

void main() {
  testWidgets('App shows bottom navigation and navigates to Menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Bottom navigation labels should be present
    expect(find.text('My Cards'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);

    // Tap the Menu tab and verify Menu screen content
    await tester.tap(find.text('Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Our Menu'), findsOneWidget);
  });
}
