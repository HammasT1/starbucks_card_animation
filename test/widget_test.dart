import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:starbucks_card_animation/main.dart';

Future<void> _settle(WidgetTester tester) async {
  // The card screen runs repeating animations, so pumpAndSettle never settles.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await _settle(tester);
  await tester.tap(find.text(text));
  await _settle(tester);
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MyApp());
  await _settle(tester);
}

void main() {
  testWidgets('App shows bottom navigation and navigates to Menu', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('My Cards'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);

    await tester.tap(find.text('Menu'));
    await _settle(tester);

    expect(find.text('Our Menu'), findsOneWidget);
  });

  testWidgets('No drink price shows a stray backslash', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Menu'));
    await _settle(tester);

    expect(find.textContaining(r'\$'), findsNothing);
  });

  testWidgets('Add Money increases the card balance', (tester) async {
    await _pumpApp(tester);
    expect(find.text(r'$24.50'), findsWidgets);

    await tester.tap(find.text('Add Money'));
    await _settle(tester);
    await tester.tap(find.text(r'$50'));
    await _settle(tester);
    await tester.tap(find.text(r'Add $50.00 to Classic Green'));
    await _settle(tester);

    expect(find.text(r'$74.50'), findsWidgets);
  });

  testWidgets('Pay shows a QR code and History lists transactions', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pay'));
    await _settle(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Scan to Pay'), findsOneWidget);

    Navigator.of(tester.element(find.text('Scan to Pay'))).pop();
    await _settle(tester);

    await tester.tap(find.text('History'));
    await _settle(tester);
    expect(find.text('Added money'), findsWidgets);
  });

  testWidgets('Drink price changes with size', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Menu'));
    await _settle(tester);

    await tester.tap(find.text('Caramel Macchiato'));
    await _settle(tester);
    expect(find.text(r'$5.45'), findsWidgets); // Grande (default)

    await _tapText(tester, 'Venti');
    expect(find.text(r'$5.95'), findsOneWidget);

    await _tapText(tester, 'Tall');
    expect(find.text(r'$4.95'), findsOneWidget);
  });

  testWidgets('Checkout pays with the card, earns stars, clears cart', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Menu'));
    await _settle(tester);

    await tester.tap(find.text('Caramel Macchiato'));
    await _settle(tester);
    await _tapText(tester, 'Venti');
    await tester.ensureVisible(find.textContaining('to Cart •'));
    await tester.tap(find.textContaining('to Cart •'));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded));
    await _settle(tester);

    await tester.tap(find.text('Cart'));
    await _settle(tester);
    expect(find.text(r'Checkout • $5.95'), findsOneWidget);

    await tester.tap(find.text(r'Checkout • $5.95'));
    await _settle(tester);
    expect(find.text('+11 ★'), findsOneWidget);

    await tester.tap(find.text(r'Pay $5.95'));
    await _settle(tester);
    expect(find.text('Order placed!'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text('Your cart is empty'), findsOneWidget);
  });
}
