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

    // Step 1: review
    expect(find.text('Your order'), findsOneWidget);
    expect(find.text('+11 ★'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    // Step 2: pickup
    expect(find.text('Pickup store'), findsOneWidget);
    await tester.tap(find.text('Riverside Mall'));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    // Step 3: payment
    await tester.tap(find.text(r'Pay $5.95'));
    await _settle(tester);
    await _settle(tester);
    await _settle(tester); // cup-filling intro
    expect(find.text('Order placed!'), findsOneWidget);
    expect(find.byType(OrderTracker), findsOneWidget);

    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('Rewards ring, recent activity and picks are shown', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _settle(tester); // let the rewards ring finish counting up

    expect(find.textContaining('until your next free drink'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Picked for you'), findsOneWidget);
    expect(find.byType(RewardsCard), findsOneWidget);
    expect(find.byType(RecentActivity), findsOneWidget);
  });

  testWidgets('Tapping the card flips it to the QR side and back', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.byType(CardBack), findsNothing);

    await tester.tap(find.text('STARBUCKS').first);
    await _settle(tester);
    expect(find.byType(CardBack), findsOneWidget);
    expect(find.text('Scan to pay'), findsOneWidget);

    await tester.tap(find.text('Scan to pay'));
    await _settle(tester);
    expect(find.byType(CardBack), findsNothing);
  });

  testWidgets('Pay sheet counts down to the next code refresh', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Pay'));
    await _settle(tester);
    int secondsLeft() {
      final text = tester
          .widget<Text>(find.textContaining('Code refreshes in'))
          .data!;
      final parts = text.split(' ').last.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    final before = secondsLeft();
    expect(before, inInclusiveRange(55, 60));

    await tester.pump(const Duration(seconds: 5));
    expect(secondsLeft(), before - 5);

    Navigator.of(tester.element(find.text('Scan to Pay'))).pop();
    await _settle(tester);
  });

  Future<void> openMenu(WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Menu'));
    await _settle(tester);
  }

  testWidgets('Search filters drinks by name and ingredient', (tester) async {
    await openMenu(tester);
    expect(find.text('8 drinks'), findsOneWidget);
    expect(find.byType(FeaturedBanner), findsOneWidget);

    // "Caramel" matches Caramel Macchiato (name) and Ember Spice Chai
    // (ingredient).
    await tester.enterText(find.byType(TextField), 'caramel');
    await _settle(tester);
    expect(find.text('2 drinks'), findsOneWidget);
    expect(find.byType(FeaturedBanner), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await _settle(tester);
    expect(find.text('No drinks found'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await _settle(tester);
    expect(find.text('8 drinks'), findsOneWidget);
  });

  testWidgets('Categories filter the grid', (tester) async {
    await openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('category-Seasonal')));
    await _settle(tester);
    expect(find.text('2 drinks'), findsOneWidget);
    expect(find.byType(FeaturedBanner), findsNothing);

    await tester.tap(find.byKey(const ValueKey('category-All')));
    await _settle(tester);
    expect(find.text('8 drinks'), findsOneWidget);
  });

  testWidgets('Hearts add drinks to the Favourites filter', (tester) async {
    await openMenu(tester);

    await tester.tap(find.byKey(const ValueKey('category-Favourites')));
    await _settle(tester);
    expect(find.text('No favourites yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('category-All')));
    await _settle(tester);
    await tester.tap(find.byType(HeartButton).first);
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('category-Favourites')));
    await _settle(tester);
    expect(find.text('1 drink'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

    // Un-favourite again so other tests start from a clean state.
    await tester.tap(find.byType(HeartButton).first);
    await _settle(tester);
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  testWidgets('Quick add flies a cup to the cart and bumps the badge', (
    tester,
  ) async {
    await openMenu(tester);
    expect(
      find.descendant(of: find.byType(CartTabIcon), matching: find.text('1')),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FlyingCup), findsOneWidget);

    await _settle(tester);
    expect(find.byType(FlyingCup), findsNothing);
    expect(
      find.descendant(of: find.byType(CartTabIcon), matching: find.text('1')),
      findsOneWidget,
    );
  });

  Future<void> openDrink(WidgetTester tester, String name) async {
    await openMenu(tester);
    // Search first so the card sits at the top of the grid.
    await tester.enterText(find.byType(TextField), name);
    await _settle(tester);
    await tester.tap(find.text(name).last);
    await _settle(tester);
  }

  testWidgets('Add-to-cart bar is pinned without scrolling', (tester) async {
    await openDrink(tester, 'Caramel Macchiato');
    expect(find.textContaining('to Cart •').hitTestable(), findsOneWidget);

    await tester.tap(find.textContaining('to Cart •'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Added to cart'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await _settle(tester); // let the label fade back
    expect(find.text('Added to cart'), findsNothing);
  });

  testWidgets('Milk and extra shots change price and become a cart line', (
    tester,
  ) async {
    await openDrink(tester, 'Caramel Macchiato');
    expect(find.text(r'$5.45'), findsWidgets);

    await _tapText(tester, 'Oat');
    expect(find.text(r'$6.15'), findsOneWidget); // +$0.70

    await tester.ensureVisible(find.text('Extra espresso shot'));
    await _settle(tester);
    final shotRow = find.ancestor(
      of: find.text('Extra espresso shot'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: shotRow.first, matching: find.byIcon(Icons.add)),
    );
    await _settle(tester);
    expect(find.text(r'$6.95'), findsOneWidget); // +$0.80 shot

    await tester.tap(find.textContaining('to Cart •'));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded));
    await _settle(tester);
    await tester.tap(find.text('Cart'));
    await _settle(tester);

    expect(find.text('Oat milk · +1 shot'), findsOneWidget);
    expect(find.text(r'Size: Grande • $6.95 each'), findsOneWidget);
  });

  testWidgets('Nutrition scales with size, shots and sweetness', (
    tester,
  ) async {
    await openDrink(tester, 'Caramel Macchiato');
    await tester.ensureVisible(find.text('Caffeine'));
    await _settle(tester);
    expect(find.text('150 mg'), findsOneWidget);
    expect(find.text('33 g'), findsOneWidget);

    await _tapText(tester, 'Venti');
    expect(find.text('188 mg'), findsOneWidget); // 150 × 1.25

    await tester.ensureVisible(find.byKey(const ValueKey('segment-None')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('segment-None')));
    await _settle(tester);
    expect(find.text('12 g'), findsOneWidget); // 33 × 1.25 × 0.3
  });

  testWidgets('Cup grows with size', (tester) async {
    await openDrink(tester, 'Caramel Macchiato');
    double cupScale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    expect(cupScale(), 0.92);
    await _tapText(tester, 'Venti');
    expect(cupScale(), 1.04);
    await _tapText(tester, 'Tall');
    expect(cupScale(), 0.8);
    expect(find.text('Tall · 354 ml'), findsOneWidget);
  });

  testWidgets('Options only appear where they apply', (tester) async {
    await openDrink(tester, 'Cold Brew');
    expect(find.text('Extra espresso shot'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Sweetness'), findsNothing);
  });

  testWidgets('Active order shows in the cart and opens the tracker', (
    tester,
  ) async {
    // The checkout test above placed an order.
    await _pumpApp(tester);
    await tester.tap(find.text('Cart'));
    await _settle(tester);
    expect(find.byType(ActiveOrderBanner), findsOneWidget);
    expect(find.textContaining('Riverside Mall'), findsOneWidget);

    await tester.tap(find.byType(ActiveOrderBanner));
    await _settle(tester);
    expect(find.byType(OrderStatusScreen), findsOneWidget);
    final countdown = tester
        .widget<Text>(find.byKey(const ValueKey('order-countdown')))
        .data!;
    expect(countdown, matches(RegExp(r'^[45]:\d\d$')));
  });

  testWidgets('Swipe removes a cart item and Undo restores it', (tester) async {
    await openMenu(tester);
    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
    await _settle(tester);
    await tester.tap(find.text('Cart'));
    await _settle(tester);

    // Count cart rows by their Remove button; the snackbar is a Dismissible
    // too, so counting Dismissibles would include it.
    int rows() => find.byTooltip('Remove').evaluate().length;
    final before = rows();
    expect(before, greaterThan(0));

    await tester.drag(find.byType(Dismissible).first, const Offset(-600, 0));
    await _settle(tester);
    expect(rows(), before - 1);
    expect(find.textContaining('removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(rows(), before);
  });

  testWidgets('Empty cart offers a way back to the menu', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Cart'));
    await _settle(tester);
    // Earlier tests may have left items in the shared cart.
    while (find.byTooltip('Remove').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Remove').first);
      await _settle(tester);
    }
    expect(find.text('Your cart is empty'), findsOneWidget);

    await tester.tap(find.text('Browse menu'));
    await _settle(tester);
    expect(find.text('Our Menu'), findsOneWidget);
  });
}
