part of '../../main.dart';

// ─── App State ────────────────────────────────────────────────────────────────

final ValueNotifier<bool> _isDark = ValueNotifier<bool>(true);
final ValueNotifier<List<CartItem>> _cart = ValueNotifier<List<CartItem>>([]);
final ValueNotifier<Set<String>> _favourites = ValueNotifier<Set<String>>({});

/// Selected bottom-navigation tab (0 = My Cards, 1 = Menu, 2 = Cart).
final ValueNotifier<int> _currentTab = ValueNotifier<int>(0);

/// Incremented whenever something lands in the cart, to bounce the tab badge.
final ValueNotifier<int> _cartBump = ValueNotifier<int>(0);

/// Marks the Cart tab icon so the fly-to-cart animation knows where to land.
final GlobalKey _cartTabKey = GlobalKey();

void _toggleFavourite(String name) {
  final next = Set<String>.from(_favourites.value);
  if (!next.remove(name)) next.add(name);
  _favourites.value = next;
}
