import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

void main() => runApp(const MyApp());

// ─── Theme Mode ───────────────────────────────────────────────────────────────

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

double _parsePrice(String price) {
  final normalized = price.replaceAll(r'\\$', '').replaceAll(r'$', '');
  return double.tryParse(normalized.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

String _formatPrice(double value) => '\$${value.toStringAsFixed(2)}';

void _addToCart(
  DrinkData drink, {
  required String size,
  int quantity = 1,
  DrinkOptions? options,
}) {
  final opts = options ?? DrinkOptions.defaultFor(drink);
  final items = List<CartItem>.from(_cart.value);
  final added = CartItem(
    drink: drink,
    size: size,
    quantity: quantity,
    options: opts,
  );
  final index = items.indexWhere((item) => item.id == added.id);

  if (index >= 0) {
    final current = items[index];
    items[index] = current.copyWith(quantity: current.quantity + quantity);
  } else {
    items.add(added);
  }

  _cart.value = items;
  _cartBump.value++;
}

void _updateCartQuantity(String id, int quantity) {
  final items = List<CartItem>.from(_cart.value);
  final index = items.indexWhere((item) => item.id == id);
  if (index == -1) return;

  if (quantity <= 0) {
    items.removeAt(index);
  } else {
    items[index] = items[index].copyWith(quantity: quantity);
  }

  _cart.value = items;
}

void _removeFromCart(String id) {
  _cart.value = _cart.value.where((item) => item.id != id).toList();
}

/// Removes [item] and offers an Undo that puts it back in the same place.
void _removeWithUndo(BuildContext context, CartItem item) {
  final index = _cart.value.indexWhere((i) => i.id == item.id);
  if (index < 0) return;
  _removeFromCart(item.id);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${item.drink.name} removed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final items = List<CartItem>.from(_cart.value);
            if (items.any((i) => i.id == item.id)) return;
            items.insert(min(index, items.length), item);
            _cart.value = items;
          },
        ),
      ),
    );
}

int _cartCount(List<CartItem> items) =>
    items.fold<int>(0, (total, item) => total + item.quantity);

double _cartTotal(List<CartItem> items) =>
    items.fold<double>(0, (total, item) => total + item.totalPrice);

// ─── Size Pricing ─────────────────────────────────────────────────────────────

const Map<String, double> _sizeDelta = {
  'Tall': -0.50,
  'Grande': 0,
  'Venti': 0.50,
  'Trenta': 0.80,
};

double _priceFor(DrinkData drink, String size) =>
    _parsePrice(drink.price) + (_sizeDelta[size] ?? 0);

const Map<String, int> _sizeVolumeMl = {
  'Tall': 354,
  'Grande': 473,
  'Venti': 591,
  'Trenta': 916,
};
const Map<String, double> _sizeFactor = {
  'Tall': 0.75,
  'Grande': 1.0,
  'Venti': 1.25,
  'Trenta': 1.6,
};
const Map<String, double> _cupScale = {
  'Tall': 0.8,
  'Grande': 0.92,
  'Venti': 1.04,
  'Trenta': 1.16,
};

// ─── Drink Options ────────────────────────────────────────────────────────────

const List<String> _milkTypes = ['Whole', 'Skim', 'Oat', 'Almond', 'Coconut'];
const Map<String, double> _milkCost = {
  'Whole': 0,
  'Skim': 0,
  'Oat': 0.70,
  'Almond': 0.70,
  'Coconut': 0.70,
};

/// Calories relative to whole milk, for a Grande.
const Map<String, int> _milkCalories = {
  'Whole': 0,
  'Skim': -40,
  'Oat': 20,
  'Almond': -30,
  'Coconut': -10,
};
const List<String> _sweetnessLevels = ['None', 'Light', 'Regular', 'Extra'];
const Map<String, double> _sweetFactor = {
  'None': 0.3,
  'Light': 0.65,
  'Regular': 1.0,
  'Extra': 1.35,
};
const double _shotCost = 0.80;
const int _maxExtraShots = 4;

bool _hasMilk(DrinkData d) => d.ingredients.toLowerCase().contains('milk');
bool _hasEspresso(DrinkData d) {
  final i = d.ingredients.toLowerCase();
  return i.contains('espresso') || i.contains('coffee');
}

bool _hasSugar(DrinkData d) => d.sugar > 0;
String _defaultMilk(DrinkData d) =>
    d.ingredients.contains('Coconut Milk') ? 'Coconut' : 'Whole';

class DrinkOptions {
  /// Null when the drink has no milk.
  final String? milk;
  final int extraShots;
  final String sweetness;

  const DrinkOptions({
    this.milk,
    this.extraShots = 0,
    this.sweetness = 'Regular',
  });

  factory DrinkOptions.defaultFor(DrinkData d) =>
      DrinkOptions(milk: _hasMilk(d) ? _defaultMilk(d) : null);

  DrinkOptions copyWith({String? milk, int? extraShots, String? sweetness}) =>
      DrinkOptions(
        milk: milk ?? this.milk,
        extraShots: extraShots ?? this.extraShots,
        sweetness: sweetness ?? this.sweetness,
      );

  double milkCost(DrinkData d) =>
      milk == null || milk == _defaultMilk(d) ? 0 : _milkCost[milk] ?? 0;

  double extraCost(DrinkData d) => milkCost(d) + extraShots * _shotCost;

  String get key => '${milk ?? '-'}|$extraShots|$sweetness';

  /// Short description of what differs from the default, e.g.
  /// "Oat milk · +2 shots · Light sweet". Empty when nothing changed.
  String summary(DrinkData d) => [
    if (milk != null && milk != _defaultMilk(d)) '$milk milk',
    if (extraShots > 0) '+$extraShots shot${extraShots == 1 ? '' : 's'}',
    if (sweetness == 'None') 'No sweetener',
    if (sweetness == 'Light' || sweetness == 'Extra') '$sweetness sweet',
  ].join(' · ');

  @override
  bool operator ==(Object other) => other is DrinkOptions && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class Nutrition {
  final int calories, caffeine, sugar;

  const Nutrition(this.calories, this.caffeine, this.sugar);
}

Nutrition _nutritionFor(DrinkData d, String size, DrinkOptions o) {
  final f = _sizeFactor[size] ?? 1;
  final baseSugar = d.sugar * f;
  final sugar = baseSugar * (_sweetFactor[o.sweetness] ?? 1);
  final milkCalories = o.milk == null
      ? 0
      : (_milkCalories[o.milk]! - _milkCalories[_defaultMilk(d)]!) * f;
  final calories =
      d.calories * f +
      milkCalories +
      o.extraShots * 5 +
      (sugar - baseSugar) * 4;
  final caffeine = d.caffeine * f + o.extraShots * 75;
  return Nutrition(max(0, calories.round()), caffeine.round(), sugar.round());
}

String _sizeDeltaLabel(String size) {
  final delta = _sizeDelta[size] ?? 0;
  if (delta == 0) return 'Base';
  return '${delta > 0 ? '+' : '−'}${_formatPrice(delta.abs())}';
}

// ─── Wallet State ─────────────────────────────────────────────────────────────

class WalletTxn {
  final int cardIndex;
  final String title;
  final double amount; // positive = top-up, negative = purchase
  final DateTime time;

  const WalletTxn({
    required this.cardIndex,
    required this.title,
    required this.amount,
    required this.time,
  });
}

final ValueNotifier<int> _activeCard = ValueNotifier<int>(0);
final ValueNotifier<int> _stars = ValueNotifier<int>(315);
final ValueNotifier<List<double>> _balances = ValueNotifier<List<double>>(
  _cards.map((c) => _parsePrice(c.balance)).toList(),
);
final ValueNotifier<List<WalletTxn>> _transactions =
    ValueNotifier<List<WalletTxn>>(_seedTransactions());

List<WalletTxn> _seedTransactions() {
  final now = DateTime.now();
  final seed = <WalletTxn>[];
  for (var i = 0; i < _cards.length; i++) {
    seed.addAll([
      WalletTxn(
        cardIndex: i,
        title: 'Caramel Macchiato · Grande',
        amount: -5.45,
        time: now.subtract(Duration(days: 1 + i, hours: 3)),
      ),
      WalletTxn(
        cardIndex: i,
        title: 'Added money',
        amount: 25,
        time: now.subtract(Duration(days: 4 + i, hours: 6)),
      ),
      WalletTxn(
        cardIndex: i,
        title: 'Cold Brew · Venti',
        amount: -4.75,
        time: now.subtract(Duration(days: 7 + i, hours: 1)),
      ),
    ]);
  }
  seed.sort((a, b) => b.time.compareTo(a.time));
  return seed;
}

void _recordTxn(int cardIndex, String title, double amount) {
  final balances = List<double>.from(_balances.value);
  balances[cardIndex] = balances[cardIndex] + amount;
  _balances.value = balances;
  _transactions.value = [
    WalletTxn(
      cardIndex: cardIndex,
      title: title,
      amount: amount,
      time: DateTime.now(),
    ),
    ..._transactions.value,
  ];
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatTxnTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${_monthNames[t.month - 1]} ${t.day} · $hh:$mm';
}

// ─── Bottom Sheets ────────────────────────────────────────────────────────────

Color _sheetBg() =>
    _isDark.value ? const Color(0xFF14231D) : const Color(0xFFFAFDFB);
Color _sheetOn() => _isDark.value ? Colors.white : const Color(0xFF15231A);
Color _sheetSub() => _isDark.value ? Colors.white60 : Colors.black54;

Future<T?> _showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _sheetBg(),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _sheetSub().withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: _sheetOn(),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: _sheetSub(), fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            builder(sheetContext),
          ],
        ),
      ),
    ),
  );
}

Widget _sheetButton({
  required String label,
  required Color color,
  required VoidCallback? onPressed,
  Color foreground = Colors.white,
}) => SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: foreground,
      disabledBackgroundColor: _sheetSub().withAlpha(40),
      disabledForegroundColor: _sheetSub(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  ),
);

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
}

Future<void> _showAddMoneySheet(BuildContext context, int cardIndex) {
  final card = _cards[cardIndex];
  const amounts = [10.0, 25.0, 50.0, 100.0];
  var selected = 25.0;
  return _showAppSheet(
    context,
    title: 'Add Money',
    subtitle:
        '${card.name} · balance ${_formatPrice(_balances.value[cardIndex])}',
    builder: (sheetContext) => StatefulBuilder(
      builder: (_, setSheet) => Column(
        children: [
          Row(
            children: amounts.map((a) {
              final active = a == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setSheet(() => selected = a),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: active
                          ? LinearGradient(colors: card.gradient)
                          : null,
                      color: active ? null : _sheetSub().withAlpha(20),
                      border: Border.all(
                        color: active ? card.accent : _sheetSub().withAlpha(50),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '\$${a.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: active ? Colors.white : _sheetOn(),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          _sheetButton(
            label: 'Add ${_formatPrice(selected)} to ${card.name}',
            color: card.gradient[0],
            onPressed: () {
              _recordTxn(cardIndex, 'Added money', selected);
              Navigator.of(sheetContext).pop();
              _showSnack(
                context,
                '${_formatPrice(selected)} added to ${card.name}',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _showPaySheet(BuildContext context, int cardIndex) =>
    _showAppSheet(
      context,
      title: 'Scan to Pay',
      subtitle: 'Show this code to the barista at the register',
      builder: (_) => PaySheetBody(cardIndex: cardIndex),
    );

Future<void> _showHistorySheet(BuildContext context, int cardIndex) {
  final card = _cards[cardIndex];
  return _showAppSheet(
    context,
    title: 'History',
    subtitle: card.name,
    builder: (_) => ValueListenableBuilder<List<WalletTxn>>(
      valueListenable: _transactions,
      builder: (_, all, __) {
        final txns = all.where((t) => t.cardIndex == cardIndex).toList();
        if (txns.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(color: _sheetSub()),
              ),
            ),
          );
        }
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: txns.length,
            separatorBuilder: (_, __) =>
                Divider(color: _sheetSub().withAlpha(30), height: 1),
            itemBuilder: (_, i) {
              final t = txns[i];
              final topUp = t.amount > 0;
              final color = topUp ? const Color(0xFF2E7D32) : _sheetOn();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (topUp ? const Color(0xFF2E7D32) : card.accent)
                            .withAlpha(35),
                      ),
                      child: Icon(
                        topUp
                            ? Icons.add_card_rounded
                            : Icons.local_cafe_rounded,
                        size: 19,
                        color: topUp ? const Color(0xFF43A047) : card.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            style: TextStyle(
                              color: _sheetOn(),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatTxnTime(t.time),
                            style: TextStyle(color: _sheetSub(), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${topUp ? '+' : '−'}${_formatPrice(t.amount.abs())}',
                      style: TextStyle(
                        color: topUp ? const Color(0xFF43A047) : color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

Widget _cardPicker({
  required int selected,
  required ValueChanged<int> onChanged,
}) => SizedBox(
  height: 108,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: _cards.length,
    separatorBuilder: (_, __) => const SizedBox(width: 10),
    itemBuilder: (_, i) {
      final c = _cards[i];
      final active = i == selected;
      return GestureDetector(
        key: ValueKey('pay-card-$i'),
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: c.gradient),
            border: Border.all(
              color: active ? c.accent : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: c.gradient[0].withAlpha(120),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (active)
                    Icon(Icons.check_circle_rounded, color: c.accent, size: 16),
                ],
              ),
              Text(
                _formatPrice(_balances.value[i]),
                style: TextStyle(
                  color: c.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);

Widget _summaryRow(String label, String value, {bool bold = false}) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: bold ? _sheetOn() : _sheetSub(),
          fontSize: bold ? 18 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
    ),
    const SizedBox(width: 12),
    Text(
      value,
      style: TextStyle(
        color: bold ? const Color(0xFFCBA258) : _sheetOn(),
        fontSize: bold ? 22 : 13,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
      ),
    ),
  ],
);

Widget _buildThemeToggle() => ValueListenableBuilder<bool>(
  valueListenable: _isDark,
  builder: (_, dark, __) => GestureDetector(
    onTap: () => _isDark.value = !dark,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      width: 54,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark ? const Color(0xFF263238) : const Color(0xFFFFF8E1),
        border: Border.all(
          color: dark
              ? Colors.white.withAlpha(60)
              : const Color(0xFFFFB300).withAlpha(180),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? const Color(0xFF3F51B5).withAlpha(100)
                : const Color(0xFFFFB300).withAlpha(100),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? const Color(0xFF5C6BC0) : const Color(0xFFFFB300),
            boxShadow: [
              BoxShadow(
                color: dark
                    ? const Color(0xFF5C6BC0).withAlpha(160)
                    : const Color(0xFFFFB300).withAlpha(160),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            color: Colors.white,
            size: 13,
          ),
        ),
      ),
    ),
  ),
);

// ─── App ──────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _isDark,
    builder: (_, dark, __) => MaterialApp(
      title: 'Starbucks',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00704A),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00704A),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainShell(),
    ),
  );
}

// ─── Shell ────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    _currentTab.value = 0; // the app always opens on My Cards
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_isDark, _cart, _currentTab]),
      builder: (_, __) {
        final dark = _isDark.value;
        final cartCount = _cartCount(_cart.value);
        final tab = _currentTab.value;
        return Scaffold(
          body: IndexedStack(
            index: tab,
            children: const [StarbucksCardScreen(), MenuScreen(), CartScreen()],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? [const Color(0xFF1E3932), const Color(0xFF00704A)]
                    : [const Color(0xFF43A047), const Color(0xFF81C784)],
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: tab,
              onTap: (i) => _currentTab.value = i,
              backgroundColor: Colors.transparent,
              selectedItemColor: const Color(0xFFCBA258),
              unselectedItemColor: dark ? Colors.white54 : Colors.black45,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.credit_card_rounded),
                  label: 'My Cards',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.local_cafe_rounded),
                  label: 'Menu',
                ),
                BottomNavigationBarItem(
                  icon: CartTabIcon(key: _cartTabKey, count: cartCount),
                  label: 'Cart',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Card Data ────────────────────────────────────────────────────────────────

class CardData {
  final String name, tier, asset, balance, number;
  final List<Color> gradient;
  final Color accent, shimmer;

  const CardData({
    required this.name,
    required this.tier,
    required this.gradient,
    required this.asset,
    required this.balance,
    required this.number,
    required this.accent,
    required this.shimmer,
  });
}

final List<CardData> _cards = [
  CardData(
    name: 'Classic Green',
    tier: 'GREEN',
    gradient: [const Color(0xFF00704A), const Color(0xFF1E3932)],
    asset: 'images/cupGreen.png',
    balance: r'$24.50',
    number: '6042 .... .... 3841',
    accent: const Color(0xFFCBA258),
    shimmer: const Color(0xFF66BB6A),
  ),
  CardData(
    name: 'Mocha Reserve',
    tier: 'MOCHA',
    gradient: [const Color(0xFF6F4E37), const Color(0xFF2C1810)],
    asset: 'images/cupChoco.png',
    balance: r'$54.25',
    number: '6042 .... .... 7215',
    accent: const Color(0xFFFFD54F),
    shimmer: const Color(0xFFA1887F),
  ),
  CardData(
    name: 'Gold Reserve',
    tier: 'GOLD',
    gradient: [const Color(0xFFB8860B), const Color(0xFF5D4037)],
    asset: 'images/cupGreen2.png',
    balance: r'$108.75',
    number: '6042 .... .... 9963',
    accent: const Color(0xFFFFF176),
    shimmer: const Color(0xFFFFD700),
  ),
  CardData(
    name: 'Berry Bliss',
    tier: 'PINK',
    gradient: [const Color(0xFFAD1457), const Color(0xFF4A148C)],
    asset: 'images/cupPink.png',
    balance: r'$38.00',
    number: '6042 .... .... 5512',
    accent: const Color(0xFFF48FB1),
    shimmer: const Color(0xFFCE93D8),
  ),
  CardData(
    name: 'Ocean Breeze',
    tier: 'BLUE',
    gradient: [const Color(0xFF0277BD), const Color(0xFF01579B)],
    asset: 'images/cup_2.png',
    balance: r'$62.10',
    number: '6042 .... .... 8834',
    accent: const Color(0xFF81D4FA),
    shimmer: const Color(0xFF4FC3F7),
  ),
  CardData(
    name: 'Autumn Ember',
    tier: 'EMBER',
    gradient: [const Color(0xFFBF360C), const Color(0xFF4E342E)],
    asset: 'images/cup.png',
    balance: r'$91.45',
    number: '6042 .... .... 2277',
    accent: const Color(0xFFFFAB40),
    shimmer: const Color(0xFFFF7043),
  ),
];

// ─── Drink Data ───────────────────────────────────────────────────────────────

class DrinkData {
  final String name, category, description, price, origin, ingredients;

  /// Nutrition for a Grande with the default options.
  final int calories, caffeine, sugar;
  final String asset;
  final List<Color> gradient;
  final Color accent;
  final List<String> sizes;

  const DrinkData({
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.origin,
    required this.ingredients,
    required this.calories,
    required this.caffeine,
    required this.sugar,
    required this.asset,
    required this.gradient,
    required this.accent,
    required this.sizes,
  });
}

class CartItem {
  final DrinkData drink;
  final String size;
  final int quantity;
  final DrinkOptions options;

  const CartItem({
    required this.drink,
    required this.size,
    required this.quantity,
    required this.options,
  });

  String get id => '${drink.name}::$size::${options.key}';
  double get unitPrice => _priceFor(drink, size) + options.extraCost(drink);
  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
    drink: drink,
    size: size,
    quantity: quantity ?? this.quantity,
    options: options,
  );
}

final List<DrinkData> _drinks = [
  const DrinkData(
    name: 'Caramel Macchiato',
    category: 'Hot',
    description:
        'Freshly steamed milk with vanilla syrup, marked with espresso and finished with a rich caramel drizzle for a sweet, layered taste.',
    price: r'$5.45',
    origin: 'Italy',
    ingredients: 'Milk, Espresso Shots, Vanilla Syrup, Caramel Sauce',
    calories: 250,
    caffeine: 150,
    sugar: 33,
    asset: 'images/cupGreen.png',
    gradient: [Color(0xFF6F4E37), Color(0xFF3E2723)],
    accent: Color(0xFFFFD54F),
    sizes: ['Tall', 'Grande', 'Venti'],
  ),
  const DrinkData(
    name: 'Mocha Frappuccino',
    category: 'Cold',
    description:
        'Coffee, mocha sauce and milk blended with ice, topped with whipped cream. The ultimate chilled chocolate coffee.',
    price: r'$5.95',
    origin: 'USA',
    ingredients: 'Ice, Milk, Coffee, Mocha Sauce, Whipped Cream',
    calories: 420,
    caffeine: 110,
    sugar: 61,
    asset: 'images/cupChoco.png',
    gradient: [Color(0xFF3E2723), Color(0xFF1A0A00)],
    accent: Color(0xFFA1887F),
    sizes: ['Tall', 'Grande', 'Venti'],
  ),
  const DrinkData(
    name: 'Green Tea Latte',
    category: 'Hot',
    description:
        'Matcha green tea blended with steamed milk and a touch of sweetness. A serene sip of Japan in every cup.',
    price: r'$4.75',
    origin: 'Japan',
    ingredients: 'Milk, Matcha Powder, Sugar',
    calories: 190,
    caffeine: 80,
    sugar: 32,
    asset: 'images/cupGreen2.png',
    gradient: [Color(0xFF1B5E20), Color(0xFF004D40)],
    accent: Color(0xFF69F0AE),
    sizes: ['Tall', 'Grande', 'Venti'],
  ),
  const DrinkData(
    name: 'Cold Brew',
    category: 'Cold',
    description:
        'Steeped for 20 hours in cold water, this smooth and lightly sweet coffee needs no heat — beautifully bold flavor.',
    price: r'$4.25',
    origin: 'Ethiopia',
    ingredients: 'Cold Brew Coffee Blend, Water',
    calories: 5,
    caffeine: 205,
    sugar: 0,
    asset: 'images/mocha_cup.png',
    gradient: [Color(0xFF1C1C1C), Color(0xFF37474F)],
    accent: Color(0xFFB0BEC5),
    sizes: ['Tall', 'Grande', 'Venti', 'Trenta'],
  ),
  const DrinkData(
    name: 'Pumpkin Spice Latte',
    category: 'Seasonal',
    description:
        'Classic fall spices — cinnamon, nutmeg, clove — layered with steamed milk and espresso. Autumn in a cup.',
    price: r'$5.75',
    origin: 'USA',
    ingredients: 'Milk, Espresso, Pumpkin Spice Sauce, Whipped Cream',
    calories: 380,
    caffeine: 150,
    sugar: 50,
    asset: 'images/cupChoco.png',
    gradient: [Color(0xFFE65100), Color(0xFFBF360C)],
    accent: Color(0xFFFFCC80),
    sizes: ['Tall', 'Grande', 'Venti'],
  ),
  const DrinkData(
    name: 'Strawberry Açaí',
    category: 'Cold',
    description:
        'Sweet strawberry flavors and passion fruit combined with açaí notes and real strawberry pieces over ice.',
    price: r'$5.25',
    origin: 'Brazil',
    ingredients: 'Water, Strawberry Juice, Açaí Powder, Ice, Lemonade',
    calories: 140,
    caffeine: 45,
    sugar: 28,
    asset: 'images/cupPink.png',
    gradient: [Color(0xFFAD1457), Color(0xFF880E4F)],
    accent: Color(0xFFF48FB1),
    sizes: ['Tall', 'Grande', 'Venti', 'Trenta'],
  ),
  const DrinkData(
    name: 'Blue Sky Refresher',
    category: 'Cold',
    description:
        'A vibrant blue spirulina cooler with coconut milk, lemonade, and real blueberry pieces over ice.',
    price: r'$5.45',
    origin: 'Thailand',
    ingredients: 'Coconut Milk, Lemonade, Spirulina, Blueberry, Ice',
    calories: 120,
    caffeine: 45,
    sugar: 24,
    asset: 'images/cup_2.png',
    gradient: [Color(0xFF0277BD), Color(0xFF01579B)],
    accent: Color(0xFF81D4FA),
    sizes: ['Tall', 'Grande', 'Venti'],
  ),
  const DrinkData(
    name: 'Ember Spice Chai',
    category: 'Seasonal',
    description:
        'Bold chai spices infused in steamed milk with a hint of smoked vanilla and a caramel rim. Warming and bold.',
    price: r'$5.65',
    origin: 'India',
    ingredients: 'Milk, Chai Concentrate, Smoked Vanilla, Caramel',
    calories: 310,
    caffeine: 95,
    sugar: 42,
    asset: 'images/cup.png',
    gradient: [Color(0xFFBF360C), Color(0xFF4E342E)],
    accent: Color(0xFFFFAB40),
    sizes: ['Tall', 'Grande', 'Venti'],
  ),
];

// ─── Cards Screen ─────────────────────────────────────────────────────────────

class StarbucksCardScreen extends StatefulWidget {
  const StarbucksCardScreen({super.key});

  @override
  State<StarbucksCardScreen> createState() => _StarbucksCardScreenState();
}

class _StarbucksCardScreenState extends State<StarbucksCardScreen>
    with TickerProviderStateMixin {
  int _current = 0;
  double _pageOffset = 0;
  late final PageController _pageCtrl;
  late final AnimationController _logoCtrl,
      _bobCtrl,
      _glowCtrl,
      _particleCtrl,
      _bgCtrl,
      _entryCtrl,
      _shimmerCtrl,
      _flipCtrl;
  late Animation<double> _logoAngle, _bobOffset, _glowAlpha, _entry, _shimmer;
  late Animation<Color?> _bg1, _bg2;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88)
      ..addListener(() => setState(() => _pageOffset = _pageCtrl.page ?? 0));

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _logoAngle = Tween<double>(begin: 0, end: 2 * pi).animate(_logoCtrl);

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _bobOffset = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAlpha = Tween<double>(
      begin: 0.25,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bg1 = ColorTween(
      begin: _cards[0].gradient[0],
      end: _cards[0].gradient[0],
    ).animate(_bgCtrl);
    _bg2 = ColorTween(
      begin: _cards[0].gradient[1],
      end: _cards[0].gradient[1],
    ).animate(_bgCtrl);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entry = CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut);
    _entryCtrl.forward();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _shimmer = Tween<double>(
      begin: -1.5,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  void _toggleFlip(int idx) {
    if (idx != _current) {
      _pageCtrl.animateToPage(
        idx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_flipCtrl.value > 0.5) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
  }

  void _onPageChanged(int idx) {
    final prev = _current;
    _activeCard.value = idx;
    _flipCtrl.value = 0;
    setState(() => _current = idx);
    _bg1 = ColorTween(
      begin: _cards[prev].gradient[0],
      end: _cards[idx].gradient[0],
    ).animate(_bgCtrl);
    _bg2 = ColorTween(
      begin: _cards[prev].gradient[1],
      end: _cards[idx].gradient[1],
    ).animate(_bgCtrl);
    _bgCtrl.forward(from: 0);
    _entryCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _logoCtrl,
      _bobCtrl,
      _glowCtrl,
      _particleCtrl,
      _bgCtrl,
      _entryCtrl,
      _shimmerCtrl,
      _flipCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgCtrl,
          _logoCtrl,
          _bobCtrl,
          _glowCtrl,
          _particleCtrl,
          _entryCtrl,
          _shimmerCtrl,
          _isDark,
          _balances,
          _stars,
          _transactions,
          _flipCtrl,
        ]),
        builder: (ctx, _) {
          final dark = _isDark.value;
          final c = _cards[_current];
          final bg1 = _bg1.value ?? c.gradient[0];
          final bg2 = _bg2.value ?? c.gradient[1];
          final lbg1 = Color.lerp(bg1, const Color(0xFFF0F4F0), 0.72)!;
          final lbg2 = Color.lerp(bg2, const Color(0xFFFFFFFF), 0.72)!;
          final screenH = MediaQuery.of(ctx).size.height;
          final heroCardHeight = (screenH * 0.34).clamp(220.0, 320.0);

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [bg1, bg2, bg2.withAlpha(230)]
                    : [lbg1, lbg2, lbg2.withAlpha(230)],
                stops: const [0, 0.6, 1],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: screenH * 0.18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            c.shimmer.withAlpha(
                              (_glowAlpha.value * 60).toInt(),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ..._buildParticles(ctx, c),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: heroCardHeight,
                        child: ScaleTransition(
                          scale: _entry,
                          child: PageView.builder(
                            controller: _pageCtrl,
                            onPageChanged: _onPageChanged,
                            itemCount: _cards.length,
                            itemBuilder: (_, i) => _buildCard(i),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDots(),
                      const SizedBox(height: 6),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _flipCtrl.value > 0.5 ? 0 : 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 13,
                              color: dark ? Colors.white54 : Colors.black45,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap card to show your pay code',
                              style: TextStyle(
                                color: dark ? Colors.white54 : Colors.black45,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            children: [
                              _buildStats(c),
                              const SizedBox(height: 12),
                              _buildActions(c),
                              const SizedBox(height: 16),
                              RewardsCard(
                                stars: _stars.value,
                                accent: c.accent,
                                dark: dark,
                              ),
                              const SizedBox(height: 18),
                              _sectionHeader(
                                'Recent activity',
                                dark: dark,
                                action: 'See all',
                                onAction: () =>
                                    _showHistorySheet(context, _current),
                              ),
                              RecentActivity(cardIndex: _current, dark: dark),
                              const SizedBox(height: 18),
                              _sectionHeader('Picked for you', dark: dark),
                              PickedForYou(dark: dark),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildParticles(BuildContext ctx, CardData c) {
    final size = MediaQuery.of(ctx).size;
    final rng = Random(42);
    return List.generate(18, (i) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final pSize = rng.nextDouble() * 7 + 2;
      final speed = rng.nextDouble() * 0.25 + 0.08;
      final t = (_particleCtrl.value * speed * 6 + i * 0.7) % 1.0;
      final alpha = (sin(t * pi) * 0.45).clamp(0.0, 1.0);
      final yShift = (t - 0.5) * 80;
      return Positioned(
        left: x,
        top: baseY + yShift,
        child: Opacity(
          opacity: alpha,
          child: Container(
            width: pSize,
            height: pSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.shimmer,
              boxShadow: [
                BoxShadow(
                  color: c.shimmer.withAlpha(120),
                  blurRadius: pSize * 2,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader() {
    final dark = _isDark.value;
    final onBg = dark ? Colors.white : const Color(0xFF1B1B1B);
    final onBgSub = dark
        ? Colors.white.withAlpha(140)
        : Colors.black.withAlpha(150);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome back',
                  style: TextStyle(color: onBgSub, fontSize: 12),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'My Starbucks',
                    style: TextStyle(
                      color: onBg,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeToggle(),
              const SizedBox(width: 12),
              AnimatedBuilder(
                animation: _logoAngle,
                builder: (_, __) => Transform.rotate(
                  angle: _logoAngle.value,
                  child: AnimatedBuilder(
                    animation: _glowAlpha,
                    builder: (_, __) => Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withAlpha(
                              (_glowAlpha.value * 80).toInt(),
                            ),
                            blurRadius: 16,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_cafe,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(int idx) {
    final card = _cards[idx];
    final delta = idx - _pageOffset;
    final tilt = delta * 0.07;
    final scale = (1.0 - delta.abs() * 0.07).clamp(0.84, 1.0);
    final cupTilt = sin(_logoAngle.value + idx * 0.7) * 0.08;
    final cupScale = 0.96 + _glowAlpha.value * 0.08;
    final flipAngle = idx == _current
        ? Curves.easeInOutCubic.transform(_flipCtrl.value) * pi
        : 0.0;
    final showBack = flipAngle > pi / 2;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateY(tilt + flipAngle);
    matrix.multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
    return Transform(
      transform: matrix,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _toggleFlip(idx),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(pi),
                  child: CardBack(card: card),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: card.gradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: card.gradient[0].withAlpha(160),
                        blurRadius: 36,
                        spreadRadius: 6,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -50,
                          top: -50,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(12),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -40,
                          bottom: -60,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(8),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _shimmer,
                          builder: (_, __) => Positioned.fill(
                            child: ShaderMask(
                              blendMode: BlendMode.srcATop,
                              shaderCallback: (rect) => LinearGradient(
                                begin: Alignment(_shimmer.value - 0.6, -0.5),
                                end: Alignment(_shimmer.value + 0.6, 0.5),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withAlpha(30),
                                  Colors.transparent,
                                ],
                              ).createShader(rect),
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withAlpha(40),
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            'images/logo.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.local_cafe,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'STARBUCKS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _tierBadge(card),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Center(
                                  child: AnimatedBuilder(
                                    animation: _bobOffset,
                                    builder: (_, __) => Transform.translate(
                                      offset: Offset(0, _bobOffset.value),
                                      child: AnimatedBuilder(
                                        animation: _glowAlpha,
                                        builder: (_, __) => Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            ...List.generate(3, (orbitIndex) {
                                              final angle =
                                                  _logoAngle.value +
                                                  orbitIndex * 2.1;
                                              return Positioned(
                                                left: cos(angle) * 34,
                                                top: sin(angle) * 18,
                                                child: Container(
                                                  width: 10 + orbitIndex * 3,
                                                  height: 10 + orbitIndex * 3,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: card.accent
                                                        .withAlpha(
                                                          90 - orbitIndex * 18,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: card.accent
                                                            .withAlpha(90),
                                                        blurRadius: 12,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                            Transform.rotate(
                                              angle: cupTilt,
                                              child: Transform.scale(
                                                scale: cupScale,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: card.accent
                                                            .withAlpha(
                                                              (_glowAlpha.value *
                                                                      140)
                                                                  .toInt(),
                                                            ),
                                                        blurRadius: 40,
                                                        spreadRadius: 8,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Image.asset(
                                                    card.asset,
                                                    height: 92,
                                                    fit: BoxFit.contain,
                                                    errorBuilder:
                                                        (_, __, ___) => Icon(
                                                          Icons.local_cafe,
                                                          color: Colors.white
                                                              .withAlpha(180),
                                                          size: 56,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                card.number,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(160),
                                  fontSize: 12,
                                  letterSpacing: 2.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'BALANCE',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(120),
                                          fontSize: 9,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      CountUpText(
                                        value: _balances.value[idx],
                                        format: _formatPrice,
                                        style: TextStyle(
                                          color: card.accent,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        Icons.star,
                                        size: 15,
                                        color: i < 3
                                            ? card.accent
                                            : Colors.white.withAlpha(50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _tierBadge(CardData c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: c.accent.withAlpha(40),
      border: Border.all(color: c.accent.withAlpha(120)),
    ),
    child: Text(
      c.tier,
      style: TextStyle(
        color: c.accent,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    ),
  );

  Widget _buildDots() {
    final dark = _isDark.value;
    final dotActive = dark ? Colors.white : const Color(0xFF1B1B1B);
    final dotInactive = dark
        ? Colors.white.withAlpha(70)
        : Colors.black.withAlpha(60);
    final dotGlow = dark
        ? Colors.white.withAlpha(130)
        : Colors.black.withAlpha(80);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_cards.length, (i) {
        final active = i == _current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 26 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active ? dotActive : dotInactive,
            boxShadow: active
                ? [BoxShadow(color: dotGlow, blurRadius: 10)]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildStats(CardData c) {
    final dark = _isDark.value;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_current),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: dark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(8),
          border: Border.all(
            color: dark
                ? Colors.white.withAlpha(35)
                : Colors.black.withAlpha(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _stat('Balance', _balances.value[_current], _formatPrice, c.accent),
            _divider(),
            _stat(
              'Stars',
              _stars.value.toDouble(),
              (v) => '${v.round()} ★',
              Colors.yellowAccent,
            ),
            _divider(),
            _stat('Tier', 0, (_) => c.tier, c.accent),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    String label,
    double value,
    String Function(double) format,
    Color color,
  ) {
    final dark = _isDark.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: dark
                ? Colors.white.withAlpha(120)
                : Colors.black.withAlpha(130),
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        CountUpText(
          value: value,
          format: format,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 32,
    color: _isDark.value
        ? Colors.white.withAlpha(40)
        : Colors.black.withAlpha(25),
  );

  Widget _buildActions(CardData c) {
    final iconClr = _isDark.value ? Colors.white : const Color(0xFF1B1B1B);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _actionBtn(
            'Add Money',
            Icons.add_card_rounded,
            c.accent,
            () => _showAddMoneySheet(context, _current),
          ),
          const SizedBox(width: 10),
          _actionBtn(
            'Pay',
            Icons.qr_code_2_rounded,
            iconClr,
            () => _showPaySheet(context, _current),
          ),
          const SizedBox(width: 10),
          _actionBtn(
            'History',
            Icons.receipt_long_rounded,
            iconClr,
            () => _showHistorySheet(context, _current),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    final dark = _isDark.value;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: dark
                  ? Colors.white.withAlpha(20)
                  : Colors.black.withAlpha(8),
              border: Border.all(
                color: dark
                    ? Colors.white.withAlpha(35)
                    : Colors.black.withAlpha(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: dark
                        ? Colors.white.withAlpha(200)
                        : Colors.black.withAlpha(200),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Menu Screen ──────────────────────────────────────────────────────────────

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  static const _categories = ['All', 'Hot', 'Cold', 'Seasonal', 'Favourites'];
  String _selectedCat = 'All';
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<DrinkData> get _filtered {
    final q = _query.trim().toLowerCase();
    return _drinks.where((d) {
      final inCategory = switch (_selectedCat) {
        'All' => true,
        'Favourites' => _favourites.value.contains(d.name),
        _ => d.category == _selectedCat,
      };
      if (!inCategory) return false;
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.ingredients.toLowerCase().contains(q) ||
          d.category.toLowerCase().contains(q);
    }).toList();
  }

  bool get _showBanner => _selectedCat == 'All' && _query.trim().isEmpty;

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_isDark, _favourites]),
      builder: (_, __) {
        final dark = _isDark.value;
        final drinks = _filtered;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF1E3932),
                      Color(0xFF0D2113),
                      Color(0xFF000000),
                    ]
                  : const [
                      Color(0xFFE8F5E9),
                      Color(0xFFF1F8F1),
                      Color(0xFFFFFFFF),
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMenuHeader(dark, drinks.length),
                const SizedBox(height: 14),
                _buildSearch(dark),
                const SizedBox(height: 12),
                _buildCategories(dark),
                const SizedBox(height: 14),
                Expanded(child: _buildDrinkGrid(dark, drinks)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuHeader(bool dark, int count) {
    final onBg = dark ? Colors.white : const Color(0xFF1B1B1B);
    final onBgSub = dark
        ? Colors.white.withAlpha(140)
        : Colors.black.withAlpha(150);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          Image.asset(
            'images/logo.png',
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_cafe,
              color: Color(0xFF00704A),
              size: 36,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Starbucks',
                  style: TextStyle(color: onBgSub, fontSize: 12),
                ),
                Text(
                  'Our Menu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onBg,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildThemeToggle(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF00704A).withAlpha(60),
              border: Border.all(color: const Color(0xFF00704A).withAlpha(120)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                '$count drink${count == 1 ? '' : 's'}',
                key: ValueKey(count),
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF00704A),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool dark) {
    final onBg = dark ? Colors.white : const Color(0xFF1B1B1B);
    final sub = dark ? Colors.white54 : Colors.black45;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _searchFocus,
        builder: (_, __) {
          final focused = _searchFocus.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: dark ? Colors.white.withAlpha(16) : Colors.white,
              border: Border.all(
                color: focused
                    ? const Color(0xFF00A862)
                    : dark
                    ? Colors.white.withAlpha(35)
                    : Colors.black.withAlpha(18),
                width: focused ? 1.6 : 1,
              ),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00A862).withAlpha(60),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: focused ? const Color(0xFF00A862) : sub,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    cursorColor: const Color(0xFF00A862),
                    style: TextStyle(color: onBg, fontSize: 14),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Search drinks or ingredients',
                      hintStyle: TextStyle(color: sub, fontSize: 14),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: _query.isEmpty
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: _clearSearch,
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: sub,
                            semanticLabel: 'Clear search',
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategories(bool dark) {
    final index = _categories.indexOf(_selectedCat);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          color: dark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(7),
          border: Border.all(
            color: dark
                ? Colors.white.withAlpha(30)
                : Colors.black.withAlpha(14),
          ),
        ),
        child: LayoutBuilder(
          builder: (_, box) {
            final w = box.maxWidth / _categories.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  left: index * w,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00A862), Color(0xFF00704A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00704A).withAlpha(90),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final cat in _categories)
                      Expanded(
                        child: GestureDetector(
                          key: ValueKey('category-$cat'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _selectedCat = cat),
                          child: Center(
                            child: _categoryLabel(
                              cat,
                              cat == _selectedCat,
                              dark,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _categoryLabel(String cat, bool active, bool dark) {
    final color = active
        ? Colors.white
        : dark
        ? Colors.white60
        : Colors.black54;
    if (cat == 'Favourites') {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(active),
          size: 18,
          color: active ? Colors.white : const Color(0xFFFF5A79),
          semanticLabel: 'Favourites',
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 220),
        style: TextStyle(
          fontFamily: 'Poppins',
          color: color,
          fontSize: 12.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
        child: Text(cat, maxLines: 1),
      ),
    );
  }

  Widget _buildDrinkGrid(bool dark, List<DrinkData> drinks) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: CustomScrollView(
        key: ValueKey(_selectedCat),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: _showBanner
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
                      child: FeaturedBanner(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          if (drinks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyResults(dark),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => KeyedSubtree(
                    key: ValueKey(drinks[i].name),
                    child: _buildDrinkCard(ctx, drinks[i], i, dark),
                  ),
                  childCount: drinks.length,
                  findChildIndexCallback: (key) {
                    final name = (key as ValueKey<String>).value;
                    final i = drinks.indexWhere((d) => d.name == name);
                    return i < 0 ? null : i;
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyResults(bool dark) {
    final favourites = _selectedCat == 'Favourites' && _query.trim().isEmpty;
    final onBg = dark ? Colors.white : const Color(0xFF1B1B1B);
    final sub = dark ? Colors.white60 : Colors.black54;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              favourites
                  ? Icons.favorite_border_rounded
                  : Icons.search_off_rounded,
              size: 56,
              color: favourites ? const Color(0xFFFF5A79) : sub,
            ),
            const SizedBox(height: 14),
            Text(
              favourites ? 'No favourites yet' : 'No drinks found',
              style: TextStyle(
                color: onBg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              favourites
                  ? 'Tap the heart on any drink to save it here.'
                  : 'Try another name or ingredient.',
              textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontSize: 13),
            ),
            if (_query.isNotEmpty) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: _clearSearch,
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrinkCard(BuildContext ctx, DrinkData d, int i, bool dark) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 400 + i * 80),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Transform.translate(
          offset: Offset(0, 30 * (1 - v)),
          child: Transform.scale(
            scale: 0.94 + 0.06 * v,
            child: Opacity(opacity: v, child: child),
          ),
        ),
        child: Builder(
          builder: (cardCtx) => GestureDetector(
            onTap: () => Navigator.of(ctx).push(
              PageRouteBuilder(
                pageBuilder: (_, anim, __) => FadeTransition(
                  opacity: anim,
                  child: DrinkDetailScreen(drink: d),
                ),
                transitionDuration: const Duration(milliseconds: 350),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: d.gradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: d.gradient[0].withAlpha(120),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: d.accent.withAlpha(40),
                                  border: Border.all(
                                    color: d.accent.withAlpha(100),
                                  ),
                                ),
                                child: Text(
                                  d.category,
                                  style: TextStyle(
                                    color: d.accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              HeartButton(drink: d, size: 20),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Center(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: -0.08, end: 0.08),
                                duration: Duration(milliseconds: 1800 + i * 90),
                                curve: Curves.easeInOut,
                                builder: (_, angle, __) => Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            d.accent.withAlpha(55),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Transform.rotate(
                                      angle: angle,
                                      child: Hero(
                                        tag: 'drink-${d.name}',
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: d.accent.withAlpha(80),
                                                blurRadius: 20,
                                                spreadRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Image.asset(
                                            d.asset,
                                            height: 86,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.local_cafe,
                                              color: d.accent,
                                              size: 56,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              // Cards are dark in both themes.
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                d.price,
                                style: TextStyle(
                                  color: d.accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _flyToCart(cardCtx, d),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: d.accent.withAlpha(40),
                                      ),
                                      child: Icon(
                                        Icons.add_shopping_cart_rounded,
                                        color: d.accent,
                                        size: 14,
                                        semanticLabel: 'Quick add ${d.name}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: d.accent.withAlpha(40),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: d.accent,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// ─── Cart Screen ──────────────────────────────────────────────────────────────

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_isDark, _cart, _activeOrder]),
      builder: (_, __) {
        final dark = _isDark.value;
        final items = _cart.value;
        final total = _cartTotal(items);
        final onBg = dark ? Colors.white : const Color(0xFF15231A);
        final subBg = dark ? Colors.white70 : Colors.black54;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF12241E),
                      Color(0xFF09140F),
                      Color(0xFF000000),
                    ]
                  : const [
                      Color(0xFFF4FBF6),
                      Color(0xFFE8F5E9),
                      Color(0xFFFFFFFF),
                    ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready to order',
                              style: TextStyle(color: subBg, fontSize: 12),
                            ),
                            Text(
                              'Your Cart',
                              style: TextStyle(
                                color: onBg,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildThemeToggle(),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: _activeOrder.value == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: ActiveOrderBanner(
                            order: _activeOrder.value!,
                            dark: dark,
                          ),
                        ),
                ),
                if (items.isEmpty)
                  Expanded(child: EmptyCart(dark: dark))
                else
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final item = items[index];
                              return Dismissible(
                                key: ValueKey(item.id),
                                direction: DismissDirection.endToStart,
                                background: _swipeBackground(),
                                onDismissed: (_) =>
                                    _removeWithUndo(context, item),
                                child: _CartTile(item: item, dark: dark),
                              );
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: dark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(6),
                            border: Border.all(
                              color: dark
                                  ? Colors.white.withAlpha(16)
                                  : Colors.black.withAlpha(12),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Items',
                                    style: TextStyle(
                                      color: subBg,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${_cartCount(items)}',
                                    style: TextStyle(
                                      color: onBg,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      color: onBg,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  CountUpText(
                                    value: total,
                                    format: _formatPrice,
                                    style: const TextStyle(
                                      color: Color(0xFFCBA258),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const CheckoutScreen(),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00704A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    'Checkout • ${_formatPrice(total)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _swipeBackground() => Container(
  alignment: Alignment.centerRight,
  padding: const EdgeInsets.symmetric(horizontal: 24),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    gradient: const LinearGradient(
      colors: [Color(0x00E53935), Color(0xFFE53935)],
    ),
  ),
  child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Remove',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      SizedBox(width: 8),
      Icon(Icons.delete_outline_rounded, color: Colors.white),
    ],
  ),
);

class _CartTile extends StatelessWidget {
  final CartItem item;
  final bool dark;

  const _CartTile({required this.item, required this.dark});

  @override
  Widget build(BuildContext context) {
    final onBg = dark ? Colors.white : const Color(0xFF15231A);
    final subBg = dark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: dark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
        border: Border.all(
          color: dark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(12),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            item.drink.asset,
            height: 70,
            width: 70,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.local_cafe, color: item.drink.accent, size: 46),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.drink.name,
                  style: TextStyle(
                    color: onBg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Size: ${item.size} • ${_formatPrice(item.unitPrice)} each',
                  style: TextStyle(color: subBg, fontSize: 12),
                ),
                if (item.options.summary(item.drink).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.options.summary(item.drink),
                      style: TextStyle(
                        color: item.drink.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () => item.quantity == 1
                          ? _removeWithUndo(context, item)
                          : _updateCartQuantity(item.id, item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          color: onBg,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () =>
                          _updateCartQuantity(item.id, item.quantity + 1),
                    ),
                    const Spacer(),
                    Text(
                      _formatPrice(item.totalPrice),
                      style: TextStyle(
                        color: item.drink.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeWithUndo(context, item),
            icon: Icon(
              Icons.close_rounded,
              color: dark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF00704A).withAlpha(24),
        border: Border.all(color: const Color(0xFF00704A).withAlpha(60)),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF00704A)),
    ),
  );
}

// ─── Drink Detail Screen ──────────────────────────────────────────────────────

class DrinkDetailScreen extends StatefulWidget {
  final DrinkData drink;
  final String? heroTag;

  const DrinkDetailScreen({super.key, required this.drink, this.heroTag});

  @override
  State<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends State<DrinkDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bob;
  late String _selectedSize;
  late DrinkOptions _options;
  int _quantity = 1;
  bool _justAdded = false;
  Timer? _addedTimer;

  DrinkData get _drink => widget.drink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _bob = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _selectedSize = _drink.sizes.contains('Grande')
        ? 'Grande'
        : _drink.sizes.first;
    _options = DrinkOptions.defaultFor(_drink);
  }

  @override
  void dispose() {
    _addedTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    _addToCart(
      _drink,
      size: _selectedSize,
      quantity: _quantity,
      options: _options,
    );
    setState(() => _justAdded = true);
    _addedTimer?.cancel();
    _addedTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _justAdded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _drink;
    final unitPrice = _priceFor(d, _selectedSize) + _options.extraCost(d);
    final totalPrice = unitPrice * _quantity;
    final nutrition = _nutritionFor(d, _selectedSize, _options);
    final customisable = _hasMilk(d) || _hasEspresso(d) || _hasSugar(d);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [...d.gradient, Colors.black],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(d),
              Expanded(flex: 3, child: _buildCup(d)),
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  // Keep scrolled content inside the rounded top edge.
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(130),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitleRow(d, unitPrice),
                              const SizedBox(height: 8),
                              _buildMeta(d, nutrition),
                              const SizedBox(height: 16),
                              Text(
                                d.description,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(190),
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _sectionLabel('Ingredients', d.accent),
                              const SizedBox(height: 10),
                              _ingredientsChips(d),
                              const SizedBox(height: 22),
                              _sectionLabel('Choose Size', d.accent),
                              const SizedBox(height: 10),
                              _sizePicker(d),
                              if (customisable) ...[
                                const SizedBox(height: 22),
                                _sectionLabel('Customise', d.accent),
                                const SizedBox(height: 12),
                                _buildCustomise(d),
                              ],
                              const SizedBox(height: 22),
                              _sectionLabel('Nutrition', d.accent),
                              const SizedBox(height: 4),
                              Text(
                                'Per $_selectedSize · ${_sizeVolumeMl[_selectedSize]} ml, '
                                'with your choices',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(120),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildNutrition(d, nutrition),
                            ],
                          ),
                        ),
                      ),
                      _buildAddBar(d, totalPrice),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(DrinkData d) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Spacer(),
        HeartButton(drink: d, size: 24, idleColor: Colors.white70),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: d.accent.withAlpha(30),
            border: Border.all(color: d.accent.withAlpha(80)),
          ),
          child: Text(
            d.category,
            style: TextStyle(
              color: d.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildCup(DrinkData d) => Column(
    children: [
      Expanded(
        child: AnimatedBuilder(
          animation: _bob,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _bob.value),
            child: Transform.rotate(
              angle: sin(_ctrl.value * pi * 2) * 0.05,
              child: child,
            ),
          ),
          child: Center(
            child: AnimatedScale(
              scale: _cupScale[_selectedSize] ?? 1,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: d.accent.withAlpha(100),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: Hero(
                  tag: widget.heroTag ?? 'drink-${d.name}',
                  child: Image.asset(
                    d.asset,
                    height: 170,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.local_cafe, color: d.accent, size: 120),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withAlpha(60),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Row(
              key: ValueKey(_selectedSize),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_drink_rounded, size: 14, color: d.accent),
                const SizedBox(width: 6),
                Text(
                  '$_selectedSize · ${_sizeVolumeMl[_selectedSize]} ml',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildTitleRow(DrinkData d, double unitPrice) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          d.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
      const SizedBox(width: 10),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: Text(
          _formatPrice(unitPrice),
          key: ValueKey(unitPrice),
          style: TextStyle(
            color: d.accent,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );

  Widget _buildMeta(DrinkData d, Nutrition n) {
    final style = TextStyle(color: d.accent.withAlpha(200), fontSize: 12);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_rounded, color: d.accent, size: 14),
            const SizedBox(width: 4),
            Text('Origin: ${d.origin}', style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: d.accent,
              size: 14,
            ),
            const SizedBox(width: 4),
            CountUpText(
              value: n.calories.toDouble(),
              format: (v) => '${v.round()} cal',
              style: style,
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, Color color) => Row(
    children: [
      Container(
        width: 4,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _subLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withAlpha(150),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _ingredientsChips(DrinkData d) {
    final items = d.ingredients.split(',').map((s) => s.trim()).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: d.accent.withAlpha(25),
                border: Border.all(color: d.accent.withAlpha(80)),
              ),
              child: Text(
                item,
                style: TextStyle(color: d.accent.withAlpha(220), fontSize: 12),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _optionChip({
    required String title,
    required String subtitle,
    required bool active,
    required VoidCallback onTap,
    required Color accent,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: active
            ? LinearGradient(colors: [accent, accent.withAlpha(180)])
            : null,
        color: active ? null : Colors.white.withAlpha(15),
        border: Border.all(color: active ? accent : Colors.white.withAlpha(40)),
        boxShadow: active
            ? [BoxShadow(color: accent.withAlpha(80), blurRadius: 12)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: active ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: active ? Colors.black54 : Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sizePicker(DrinkData d) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final s in d.sizes)
          _optionChip(
            title: s,
            subtitle: _sizeDeltaLabel(s),
            active: s == _selectedSize,
            onTap: () => setState(() => _selectedSize = s),
            accent: d.accent,
          ),
      ],
    ),
  );

  Widget _buildCustomise(DrinkData d) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_hasMilk(d)) ...[
        _subLabel('Milk'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final m in _milkTypes)
                _optionChip(
                  title: m,
                  subtitle: m == _defaultMilk(d) || _milkCost[m] == 0
                      ? 'Included'
                      : '+${_formatPrice(_milkCost[m]!)}',
                  active: m == _options.milk,
                  onTap: () =>
                      setState(() => _options = _options.copyWith(milk: m)),
                  accent: d.accent,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (_hasEspresso(d)) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withAlpha(10),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Row(
            children: [
              Icon(Icons.coffee_rounded, color: d.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Extra espresso shot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '+${_formatPrice(_shotCost)} each · +75 mg caffeine',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              _QtyButton(
                icon: Icons.remove,
                onTap: () {
                  if (_options.extraShots == 0) return;
                  setState(
                    () => _options = _options.copyWith(
                      extraShots: _options.extraShots - 1,
                    ),
                  );
                },
              ),
              SizedBox(
                width: 34,
                child: Center(child: _animatedCount(_options.extraShots, 15)),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () {
                  if (_options.extraShots >= _maxExtraShots) return;
                  setState(
                    () => _options = _options.copyWith(
                      extraShots: _options.extraShots + 1,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (_hasSugar(d)) ...[
        _subLabel('Sweetness'),
        _slidingSegments(
          options: _sweetnessLevels,
          selected: _options.sweetness,
          accent: d.accent,
          onChanged: (v) =>
              setState(() => _options = _options.copyWith(sweetness: v)),
        ),
      ],
    ],
  );

  Widget _slidingSegments({
    required List<String> options,
    required String selected,
    required Color accent,
    required ValueChanged<String> onChanged,
  }) => Container(
    height: 42,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(21),
      color: Colors.white.withAlpha(12),
      border: Border.all(color: Colors.white.withAlpha(25)),
    ),
    child: LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth / options.length;
        final index = options.indexOf(selected);
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              left: index * w,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: accent,
                  boxShadow: [
                    BoxShadow(color: accent.withAlpha(90), blurRadius: 10),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final o in options)
                  Expanded(
                    child: GestureDetector(
                      key: ValueKey('segment-$o'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(o),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: o == selected
                                ? Colors.black
                                : Colors.white60,
                            fontSize: 12,
                            fontWeight: o == selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(o, maxLines: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _buildNutrition(DrinkData d, Nutrition n) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: Colors.white.withAlpha(10),
      border: Border.all(color: Colors.white.withAlpha(20)),
    ),
    child: Column(
      children: [
        _nutritionRow('Calories', n.calories, 'kcal', 600, d.accent, null),
        const SizedBox(height: 14),
        _nutritionRow(
          'Caffeine',
          n.caffeine,
          'mg',
          400,
          d.accent,
          'of the 400 mg daily limit',
        ),
        const SizedBox(height: 14),
        _nutritionRow(
          'Sugar',
          n.sugar,
          'g',
          50,
          d.accent,
          'of the 50 g daily guideline',
        ),
      ],
    ),
  );

  Widget _nutritionRow(
    String label,
    int value,
    String unit,
    int reference,
    Color accent,
    String? referenceNote,
  ) {
    final fraction = value / reference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            CountUpText(
              value: value.toDouble(),
              format: (v) => '${v.round()} $unit',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: fraction),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) {
            final over = v >= 1;
            final barColor = over ? const Color(0xFFFF6B6B) : accent;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white.withAlpha(20),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: v.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [barColor.withAlpha(160), barColor],
                        ),
                      ),
                    ),
                  ),
                ),
                if (referenceNote != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${(v * 100).round()}% $referenceNote',
                    style: TextStyle(
                      color: over
                          ? const Color(0xFFFF8A80)
                          : Colors.white.withAlpha(110),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _animatedCount(int value, double fontSize) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    transitionBuilder: (child, anim) =>
        ScaleTransition(scale: anim, child: child),
    child: Text(
      '$value',
      key: ValueKey(value),
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _buildAddBar(DrinkData d, double totalPrice) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(120),
      border: Border(top: BorderSide(color: Colors.white.withAlpha(22))),
    ),
    child: Row(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withAlpha(12),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () {
                  if (_quantity == 1) return;
                  setState(() => _quantity -= 1);
                },
              ),
              SizedBox(
                width: 32,
                child: Center(child: _animatedCount(_quantity, 16)),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () => setState(() => _quantity += 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _add,
              style: ElevatedButton.styleFrom(
                backgroundColor: _justAdded
                    ? const Color(0xFF2E7D32)
                    : d.accent,
                foregroundColor: _justAdded ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 8,
                shadowColor: d.accent.withAlpha(120),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: _justAdded
                    ? const FittedBox(
                        key: ValueKey('added'),
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Added to cart',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FittedBox(
                        key: const ValueKey('add'),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Add $_quantity to Cart • ${_formatPrice(totalPrice)}',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Count-up Text ────────────────────────────────────────────────────────────

/// Animates from the previous value to the new one whenever [value] changes.
class CountUpText extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle style;

  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    required this.style,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: value, end: value),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (_, v, __) => Text(format(v), style: style),
  );
}

// ─── Rewards Ring ─────────────────────────────────────────────────────────────

const int _starsPerReward = 400;

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: 3 * pi / 2,
          colors: [color.withAlpha(140), color],
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class RewardsCard extends StatelessWidget {
  final int stars;
  final Color accent;
  final bool dark;

  const RewardsCard({
    super.key,
    required this.stars,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = dark ? Colors.white : const Color(0xFF1B1B1B);
    final sub = dark ? Colors.white.withAlpha(150) : Colors.black54;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: stars.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        final progress = (v % _starsPerReward) / _starsPerReward;
        final toGo = _starsPerReward - (v.round() % _starsPerReward);
        final ready = v.round() ~/ _starsPerReward;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: _glassBox(dark),
          child: Row(
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress,
                    color: accent,
                    track: dark
                        ? Colors.white.withAlpha(30)
                        : Colors.black.withAlpha(20),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${v.round()}',
                          style: TextStyle(
                            color: onBg,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          '★',
                          style: TextStyle(color: accent, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rewards',
                      style: TextStyle(
                        color: onBg,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$toGo★ until your next free drink',
                      style: TextStyle(color: sub, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: ready > 0
                          ? Container(
                              key: const ValueKey('ready'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: accent.withAlpha(45),
                                border: Border.all(
                                  color: accent.withAlpha(120),
                                ),
                              ),
                              child: Text(
                                '🎁 $ready free drink${ready == 1 ? '' : 's'} ready',
                                style: TextStyle(
                                  color: onBg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Text(
                              key: const ValueKey('earn'),
                              'Earn 2★ for every \$1 spent',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

BoxDecoration _glassBox(bool dark) => BoxDecoration(
  borderRadius: BorderRadius.circular(22),
  color: dark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(8),
  border: Border.all(
    color: dark ? Colors.white.withAlpha(35) : Colors.black.withAlpha(20),
  ),
);

// ─── Section Header ───────────────────────────────────────────────────────────

Widget _sectionHeader(
  String title, {
  required bool dark,
  String? action,
  VoidCallback? onAction,
}) => Padding(
  padding: const EdgeInsets.fromLTRB(24, 0, 16, 6),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1B1B1B),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: dark ? Colors.white70 : Colors.black54,
          ),
          child: Text(action, style: const TextStyle(fontSize: 12)),
        ),
    ],
  ),
);

// ─── Recent Activity ──────────────────────────────────────────────────────────

class RecentActivity extends StatelessWidget {
  final int cardIndex;
  final bool dark;

  const RecentActivity({
    super.key,
    required this.cardIndex,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final card = _cards[cardIndex];
    final txns = _transactions.value
        .where((t) => t.cardIndex == cardIndex)
        .take(3)
        .toList();
    final onBg = dark ? Colors.white : const Color(0xFF1B1B1B);
    final sub = dark ? Colors.white.withAlpha(140) : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: _glassBox(dark),
      child: txns.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('No activity yet', style: TextStyle(color: sub)),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < txns.length; i++)
                  TweenAnimationBuilder<double>(
                    key: ValueKey(
                      '$cardIndex-${txns[i].time.microsecondsSinceEpoch}',
                    ),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 350 + i * 120),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(24 * (1 - v), 0),
                        child: child,
                      ),
                    ),
                    child: _activityRow(
                      txns[i],
                      card,
                      onBg,
                      sub,
                      last: i == txns.length - 1,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _activityRow(
    WalletTxn t,
    CardData card,
    Color onBg,
    Color sub, {
    required bool last,
  }) {
    final topUp = t.amount > 0;
    const green = Color(0xFF43A047);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: sub.withAlpha(40))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (topUp ? green : card.accent).withAlpha(40),
            ),
            child: Icon(
              topUp ? Icons.add_card_rounded : Icons.local_cafe_rounded,
              size: 16,
              color: topUp ? green : card.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onBg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTxnTime(t.time),
                  style: TextStyle(color: sub, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${topUp ? '+' : '−'}${_formatPrice(t.amount.abs())}',
            style: TextStyle(
              color: topUp ? green : onBg,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Picked For You ───────────────────────────────────────────────────────────

class PickedForYou extends StatelessWidget {
  final bool dark;

  const PickedForYou({super.key, required this.dark});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
    valueListenable: _favourites,
    builder: (_, favs, __) => _buildList(favs),
  );

  Widget _buildList(Set<String> favs) {
    final drinks = [
      ..._drinks.where((d) => favs.contains(d.name)),
      ..._drinks.where((d) => !favs.contains(d.name)),
    ];
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: drinks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final d = drinks[i];
          final fav = favs.contains(d.name);
          final heroTag = 'pick-${d.name}';
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 90),
            curve: Curves.easeOutBack,
            builder: (_, v, child) =>
                Transform.scale(scale: 0.8 + 0.2 * v, child: child),
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).push(
                PageRouteBuilder(
                  pageBuilder: (_, anim, __) => FadeTransition(
                    opacity: anim,
                    child: DrinkDetailScreen(drink: d, heroTag: heroTag),
                  ),
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              ),
              child: Container(
                width: 112,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: d.gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: d.gradient[0].withAlpha(dark ? 110 : 70),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Center(
                              child: Hero(
                                tag: heroTag,
                                child: Image.asset(
                                  d.asset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(Icons.local_cafe, color: d.accent),
                                ),
                              ),
                            ),
                          ),
                          if (fav)
                            const Positioned(
                              top: -2,
                              right: -2,
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 16,
                                color: Color(0xFFFF5A79),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      d.price,
                      style: TextStyle(
                        color: d.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Card Back (QR) ───────────────────────────────────────────────────────────

String _cardQrData(CardData card, [int refresh = 0]) =>
    'SBUX-CARD|${card.tier}|${card.number}|$refresh';

Widget _styledQr(CardData card, double size, [int refresh = 0]) => QrImageView(
  data: _cardQrData(card, refresh),
  version: QrVersions.auto,
  size: size,
  padding: EdgeInsets.zero,
  backgroundColor: Colors.white,
  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.circle, color: card.gradient[1]),
  dataModuleStyle: QrDataModuleStyle(
    dataModuleShape: QrDataModuleShape.circle,
    color: card.gradient[1],
  ),
);

class CardBack extends StatelessWidget {
  final CardData card;

  const CardBack({super.key, required this.card});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: card.gradient,
      ),
      boxShadow: [
        BoxShadow(
          color: card.gradient[0].withAlpha(160),
          blurRadius: 36,
          spreadRadius: 6,
          offset: const Offset(0, 18),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          const SizedBox(height: 22),
          // Magnetic stripe
          Container(height: 34, color: Colors.black.withAlpha(150)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: LayoutBuilder(
                builder: (_, box) {
                  final qr = min(box.maxHeight - 16, 130.0).clamp(60.0, 130.0);
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _styledQr(card, qr),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Scan to pay',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                card.number,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(180),
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 14,
                                  color: card.accent,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Tap to flip back',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: card.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Pay Sheet ────────────────────────────────────────────────────────────────

const int _payCodeSeconds = 60;

class PaySheetBody extends StatefulWidget {
  final int cardIndex;

  const PaySheetBody({super.key, required this.cardIndex});

  @override
  State<PaySheetBody> createState() => _PaySheetBodyState();
}

class _PaySheetBodyState extends State<PaySheetBody> {
  Timer? _timer;
  int _secondsLeft = _payCodeSeconds;
  int _refresh = 0;

  @override
  void initState() {
    super.initState();
    _setBrightness(boost: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsLeft -= 1;
        if (_secondsLeft <= 0) {
          _secondsLeft = _payCodeSeconds;
          _refresh += 1;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _setBrightness(boost: false);
    super.dispose();
  }

  /// Not every platform supports brightness control (e.g. Linux, web).
  Future<void> _setBrightness({required bool boost}) async {
    try {
      if (boost) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[widget.cardIndex];
    final mm = _secondsLeft ~/ 60;
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: card.gradient[0].withAlpha(90),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(_refresh),
                child: _styledQr(card, 200, _refresh),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.wb_sunny_rounded, size: 14, color: _sheetSub()),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Code refreshes in $mm:$ss',
                style: TextStyle(color: _sheetSub(), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _secondsLeft / _payCodeSeconds),
            duration: const Duration(milliseconds: 950),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              color: card.gradient[0],
              backgroundColor: _sheetSub().withAlpha(30),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: card.gradient),
          ),
          child: Row(
            children: [
              const Icon(Icons.credit_card_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      card.number,
                      style: TextStyle(
                        color: Colors.white.withAlpha(170),
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatPrice(_balances.value[widget.cardIndex]),
                style: TextStyle(
                  color: card.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Heart Button ─────────────────────────────────────────────────────────────

class HeartButton extends StatefulWidget {
  final DrinkData drink;
  final double size;
  final Color? idleColor;

  const HeartButton({
    super.key,
    required this.drink,
    this.size = 20,
    this.idleColor,
  });

  @override
  State<HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<HeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.5,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.5,
        end: 0.88,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.88,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
  ]).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
    valueListenable: _favourites,
    builder: (_, favs, __) {
      final fav = favs.contains(widget.drink.name);
      return Semantics(
        button: true,
        label: fav ? 'Remove from favourites' : 'Add to favourites',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _toggleFavourite(widget.drink.name);
            _ctrl.forward(from: 0);
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(fav),
                  size: widget.size,
                  color: fav
                      ? const Color(0xFFFF5A79)
                      : widget.idleColor ?? Colors.white.withAlpha(200),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ─── Cart Tab Icon ────────────────────────────────────────────────────────────

class CartTabIcon extends StatefulWidget {
  final int count;

  const CartTabIcon({super.key, required this.count});

  @override
  State<CartTabIcon> createState() => _CartTabIconState();
}

class _CartTabIconState extends State<CartTabIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 30),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.35,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 70,
    ),
  ]).animate(_ctrl);

  @override
  void initState() {
    super.initState();
    _cartBump.addListener(_bump);
  }

  void _bump() => _ctrl.forward(from: 0);

  @override
  void dispose() {
    _cartBump.removeListener(_bump);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.shopping_bag_rounded),
        if (widget.count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.8),
                    end: Offset.zero,
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  '${widget.count}',
                  key: ValueKey(widget.count),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ─── Fly To Cart ──────────────────────────────────────────────────────────────

/// Flies the drink's cup from its menu card to the Cart tab, then adds it.
void _flyToCart(BuildContext cardContext, DrinkData drink) {
  final size = drink.sizes.contains('Grande') ? 'Grande' : drink.sizes.first;
  final overlay = Overlay.of(cardContext, rootOverlay: true);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  final cardBox = cardContext.findRenderObject() as RenderBox?;
  if (overlayBox == null || cardBox == null || !cardBox.attached) {
    _addToCart(drink, size: size);
    return;
  }

  final cardOrigin = cardBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final start =
      cardOrigin + Offset(cardBox.size.width / 2, cardBox.size.height * 0.42);

  final cartBox = _cartTabKey.currentContext?.findRenderObject() as RenderBox?;
  final end = cartBox != null && cartBox.attached
      ? cartBox.localToGlobal(
          cartBox.size.center(Offset.zero),
          ancestor: overlayBox,
        )
      : Offset(overlayBox.size.width * 5 / 6, overlayBox.size.height - 40);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => FlyingCup(
      start: start,
      end: end,
      drink: drink,
      onDone: () {
        entry.remove();
        _addToCart(drink, size: size);
      },
    ),
  );
  overlay.insert(entry);
}

class FlyingCup extends StatefulWidget {
  final Offset start, end;
  final DrinkData drink;
  final VoidCallback onDone;

  const FlyingCup({
    super.key,
    required this.start,
    required this.end,
    required this.drink,
    required this.onDone,
  });

  @override
  State<FlyingCup> createState() => _FlyingCupState();
}

class _FlyingCupState extends State<FlyingCup>
    with SingleTickerProviderStateMixin {
  static const double _size = 84;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.start;
    final b = widget.end;
    // Control point above both ends gives the flight a nice arc.
    final c = Offset((a.dx + b.dx) / 2, min(a.dy, b.dy) - 140);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = Curves.easeInOutCubic.transform(_ctrl.value);
          final u = 1 - t;
          final p = a * (u * u) + c * (2 * u * t) + b * (t * t);
          final scale = 1.0 - 0.75 * t;
          final opacity = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15);
          return Stack(
            children: [
              Positioned(
                left: p.dx - _size / 2,
                top: p.dy - _size / 2,
                width: _size,
                height: _size,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: t * 0.8,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.drink.accent.withAlpha(140),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          widget.drink.asset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.local_cafe,
                            color: widget.drink.accent,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Featured Banner ──────────────────────────────────────────────────────────

const _featuredNames = [
  'Pumpkin Spice Latte',
  'Ember Spice Chai',
  'Blue Sky Refresher',
];

class FeaturedBanner extends StatefulWidget {
  const FeaturedBanner({super.key});

  @override
  State<FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<FeaturedBanner> {
  final PageController _ctrl = PageController();
  late final List<DrinkData> _items = _featuredNames
      .map((n) => _drinks.firstWhere((d) => d.name == n))
      .toList();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_ctrl.hasClients) return;
      _ctrl.animateToPage(
        (_page + 1) % _items.length,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 156,
        child: NotificationListener<ScrollStartNotification>(
          // Restart the timer after a manual swipe so it doesn't jump right away.
          onNotification: (n) {
            if (n.dragDetails != null) _startAutoPlay();
            return false;
          },
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (ctx, i) => AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) {
                final page = _ctrl.hasClients && _ctrl.position.haveDimensions
                    ? _ctrl.page ?? _page.toDouble()
                    : _page.toDouble();
                return _bannerItem(ctx, _items[i], i - page);
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_items.length, (i) {
          final active = i == _page;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: active
                  ? _items[_page].accent
                  : (_isDark.value ? Colors.white30 : Colors.black26),
            ),
          );
        }),
      ),
    ],
  );

  Widget _bannerItem(BuildContext ctx, DrinkData d, double offset) {
    final heroTag = 'banner-${d.name}';
    final seasonal = d.category == 'Seasonal';
    return GestureDetector(
      onTap: () => Navigator.of(ctx).push(
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => FadeTransition(
            opacity: anim,
            child: DrinkDetailScreen(drink: d, heroTag: heroTag),
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: d.gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: d.gradient[0].withAlpha(100),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                bottom: -40,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.black.withAlpha(50),
                            ),
                            child: Text(
                              seasonal ? 'SEASONAL SPECIAL' : 'NEW',
                              style: TextStyle(
                                color: d.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(190),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Order now',
                                style: TextStyle(
                                  color: d.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: d.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Parallax: the cup drifts slower than the card.
                    Transform.translate(
                      offset: Offset(offset * 70, 0),
                      child: Hero(
                        tag: heroTag,
                        child: Image.asset(
                          d.asset,
                          height: 118,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.local_cafe, color: d.accent, size: 60),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Orders ───────────────────────────────────────────────────────────────────

class PickupStore {
  final String name, address;
  final double distanceKm;
  final String hours;

  const PickupStore(this.name, this.address, this.distanceKm, this.hours);
}

const List<PickupStore> _stores = [
  PickupStore('Downtown Plaza', '12 Market Street', 0.4, 'Open until 10 PM'),
  PickupStore(
    'Riverside Mall',
    'Level 2, Riverside Mall',
    1.2,
    'Open until 9 PM',
  ),
  PickupStore('Central Station', 'Main concourse', 2.1, 'Open 24 hours'),
];

/// Pickup options: label and minutes until ready.
const List<(String, String, int)> _pickupTimes = [
  ('ASAP', '~5 min', 5),
  ('In 15 min', 'Scheduled', 15),
  ('In 30 min', 'Scheduled', 30),
];

class PlacedOrder {
  final int number;
  final List<CartItem> items;
  final double total;
  final int starsEarned;
  final PickupStore store;
  final DateTime placedAt, readyAt;

  const PlacedOrder({
    required this.number,
    required this.items,
    required this.total,
    required this.starsEarned,
    required this.store,
    required this.placedAt,
    required this.readyAt,
  });

  double progressAt(DateTime now) {
    final total = readyAt.difference(placedAt).inMilliseconds;
    if (total <= 0) return 1;
    return (now.difference(placedAt).inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// 0 = received, 1 = preparing, 2 = ready.
  int stageAt(DateTime now) {
    final p = progressAt(now);
    if (p >= 1) return 2;
    return p < 0.15 ? 0 : 1;
  }
}

final ValueNotifier<PlacedOrder?> _activeOrder = ValueNotifier<PlacedOrder?>(
  null,
);

String _formatCountdown(Duration d) {
  if (d.isNegative) return '0:00';
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Rebuilds once a second, for countdowns.
class _Ticker extends StatefulWidget {
  final Widget Function(BuildContext context, DateTime now) builder;

  const _Ticker({required this.builder});

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

// ─── Cup Painter ──────────────────────────────────────────────────────────────

class CupPainter extends CustomPainter {
  final double fill; // 0..1
  final double wavePhase; // 0..1
  final Color liquid;
  final Color outline;

  CupPainter({
    required this.fill,
    required this.wavePhase,
    required this.liquid,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final topY = h * 0.24;
    final bottomY = h * 0.96;
    final topHalf = w * 0.34;
    final bottomHalf = w * 0.25;

    final body = Path()
      ..moveTo(cx - topHalf, topY)
      ..lineTo(cx + topHalf, topY)
      ..lineTo(cx + bottomHalf, bottomY - 8)
      ..quadraticBezierTo(
        cx + bottomHalf - 2,
        bottomY,
        cx + bottomHalf - 10,
        bottomY,
      )
      ..lineTo(cx - bottomHalf + 10, bottomY)
      ..quadraticBezierTo(
        cx - bottomHalf + 2,
        bottomY,
        cx - bottomHalf,
        bottomY - 8,
      )
      ..close();

    // Glass tint.
    canvas.drawPath(body, Paint()..color = outline.withAlpha(22));

    // Liquid with a moving wave on top.
    if (fill > 0) {
      canvas.save();
      canvas.clipPath(body);
      final level = bottomY - (bottomY - topY) * fill;
      final amplitude = fill >= 0.999 ? 0.0 : 4.0;
      final wave = Path()..moveTo(0, level);
      for (double x = 0; x <= w; x += 3) {
        wave.lineTo(
          x,
          level + sin((x / w) * 2 * pi * 1.5 + wavePhase * 2 * pi) * amplitude,
        );
      }
      wave
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        wave,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(liquid, Colors.white, 0.35)!, liquid],
          ).createShader(Rect.fromLTWH(0, level, w, bottomY - level)),
      );
      canvas.restore();
    }

    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(body, stroke);

    // Sleeve band.
    final sleeveTop = topY + (bottomY - topY) * 0.38;
    final sleeveBottom = topY + (bottomY - topY) * 0.6;
    double halfAt(double y) =>
        topHalf + (bottomHalf - topHalf) * ((y - topY) / (bottomY - topY));
    final sleeve = Path()
      ..moveTo(cx - halfAt(sleeveTop), sleeveTop)
      ..lineTo(cx + halfAt(sleeveTop), sleeveTop)
      ..lineTo(cx + halfAt(sleeveBottom), sleeveBottom)
      ..lineTo(cx - halfAt(sleeveBottom), sleeveBottom)
      ..close();
    canvas.drawPath(sleeve, Paint()..color = outline.withAlpha(70));

    // Lid and straw.
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - topHalf - 6, topY - h * 0.08, cx + topHalf + 6, topY),
      const Radius.circular(6),
    );
    canvas.drawRRect(lid, Paint()..color = outline);
    canvas.drawLine(
      Offset(cx + topHalf * 0.25, topY - h * 0.08),
      Offset(cx + topHalf * 0.6, h * 0.02),
      Paint()
        ..color = outline
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(CupPainter old) =>
      old.fill != fill ||
      old.wavePhase != wavePhase ||
      old.liquid != liquid ||
      old.outline != outline;
}

// ─── Empty Cart ───────────────────────────────────────────────────────────────

class EmptyCart extends StatefulWidget {
  final bool dark;

  const EmptyCart({super.key, required this.dark});

  @override
  State<EmptyCart> createState() => _EmptyCartState();
}

class _EmptyCartState extends State<EmptyCart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final onBg = dark ? Colors.white : const Color(0xFF15231A);
    final sub = dark ? Colors.white70 : Colors.black54;
    const green = Color(0xFF00A862);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final t = Curves.easeInOut.transform(_ctrl.value);
                return SizedBox(
                  width: 150,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Shadow shrinks as the cup rises.
                      Container(
                        width: 70 + 20 * (1 - t),
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.black.withAlpha(
                            (dark ? 90 : 35) + (30 * (1 - t)).round(),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 14 + 14 * t,
                        child: Transform.rotate(
                          angle: (t - 0.5) * 0.12,
                          child: CustomPaint(
                            size: const Size(110, 140),
                            painter: CupPainter(
                              fill: 0,
                              wavePhase: 0,
                              liquid: green,
                              outline: green,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Your cart is empty',
              style: TextStyle(
                color: onBg,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your next favourite drink is one tap away.',
              textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontSize: 13),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => _currentTab.value = 1,
              icon: const Icon(Icons.local_cafe_rounded, size: 18),
              label: const Text(
                'Browse menu',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00704A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Checkout ─────────────────────────────────────────────────────────────────

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _steps = ['Review', 'Pickup', 'Payment'];
  int _step = 0;
  bool _forward = true;
  int _storeIndex = 0;
  int _pickupIndex = 0;
  int _cardIndex = _activeCard.value;

  void _goTo(int step) => setState(() {
    _forward = step > _step;
    _step = step;
  });

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      _goTo(_step - 1);
    }
  }

  void _pay() {
    final items = _cart.value;
    final total = _cartTotal(items);
    final count = _cartCount(items);
    final starsEarned = (total * 2).floor();
    final now = DateTime.now();
    final order = PlacedOrder(
      number: 1000 + Random().nextInt(9000),
      items: List<CartItem>.from(items),
      total: total,
      starsEarned: starsEarned,
      store: _stores[_storeIndex],
      placedAt: now,
      readyAt: now.add(Duration(minutes: _pickupTimes[_pickupIndex].$3)),
    );
    _recordTxn(
      _cardIndex,
      'Order · $count item${count == 1 ? '' : 's'}',
      -total,
    );
    _stars.value += starsEarned;
    _cart.value = [];
    _activeOrder.value = order;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: OrderStatusScreen(order: order, celebrate: true),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_isDark, _cart, _balances]),
    builder: (_, __) {
      final dark = _isDark.value;
      final items = _cart.value;
      final total = _cartTotal(items);
      final enough = _balances.value[_cardIndex] >= total;
      return PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: _sheetBg(),
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _StepIndicator(steps: _steps, current: _step, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      final incoming = child.key == ValueKey(_step);
                      final dx = (_forward == incoming) ? 0.25 : -0.25;
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(dx, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: switch (_step) {
                        0 => _buildReview(items, total),
                        1 => _buildPickup(),
                        _ => _buildPayment(total, enough),
                      },
                    ),
                  ),
                ),
                _buildBottomBar(total, enough && items.isNotEmpty),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
    child: Row(
      children: [
        IconButton(
          onPressed: _back,
          icon: Icon(Icons.arrow_back_ios_rounded, color: _sheetOn()),
        ),
        Expanded(
          child: Text(
            'Checkout',
            style: TextStyle(
              color: _sheetOn(),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          'Step ${_step + 1} of ${_steps.length}',
          style: TextStyle(color: _sheetSub(), fontSize: 12),
        ),
      ],
    ),
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        color: _sheetOn(),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  BoxDecoration _panel({bool active = false, Color? accent}) => BoxDecoration(
    borderRadius: BorderRadius.circular(18),
    color: active
        ? (accent ?? const Color(0xFF00A862)).withAlpha(28)
        : _sheetSub().withAlpha(14),
    border: Border.all(
      color: active
          ? (accent ?? const Color(0xFF00A862))
          : _sheetSub().withAlpha(35),
      width: active ? 1.8 : 1,
    ),
  );

  Widget _buildReview(List<CartItem> items, double total) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    children: [
      _heading('Your order'),
      for (var i = 0; i < items.length; i++)
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + i * 90),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - v)),
              child: child,
            ),
          ),
          child: _reviewRow(items[i]),
        ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _panel(),
        child: Column(
          children: [
            _summaryRow('Items', '${_cartCount(items)}'),
            const SizedBox(height: 6),
            _summaryRow('Stars you\'ll earn', '+${(total * 2).floor()} ★'),
            const SizedBox(height: 10),
            _summaryRow('Total', _formatPrice(total), bold: true),
          ],
        ),
      ),
    ],
  );

  Widget _reviewRow(CartItem item) {
    final summary = item.options.summary(item.drink);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _panel(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: item.drink.gradient),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              item.drink.asset,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.local_cafe, color: item.drink.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.drink.name,
                  style: TextStyle(
                    color: _sheetOn(),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  [item.size, if (summary.isNotEmpty) summary].join(' · '),
                  style: TextStyle(color: _sheetSub(), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${item.quantity} × ${_formatPrice(item.unitPrice)}',
            style: TextStyle(
              color: _sheetOn(),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickup() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    children: [
      _heading('Pickup store'),
      for (var i = 0; i < _stores.length; i++)
        GestureDetector(
          onTap: () => setState(() => _storeIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: _panel(active: i == _storeIndex),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00704A).withAlpha(40),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF00A862),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stores[i].name,
                        style: TextStyle(
                          color: _sheetOn(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_stores[i].address} · ${_stores[i].hours}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _sheetSub(), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_stores[i].distanceKm} km',
                  style: TextStyle(
                    color: _sheetOn(),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    i == _storeIndex
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(i == _storeIndex),
                    color: i == _storeIndex
                        ? const Color(0xFF00A862)
                        : _sheetSub(),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 14),
      _heading('Pickup time'),
      Row(
        children: [
          for (var i = 0; i < _pickupTimes.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _pickupIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: EdgeInsets.only(
                    right: i < _pickupTimes.length - 1 ? 10 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: _panel(active: i == _pickupIndex),
                  child: Column(
                    children: [
                      Icon(
                        i == 0 ? Icons.bolt_rounded : Icons.schedule_rounded,
                        size: 20,
                        color: i == _pickupIndex
                            ? const Color(0xFF00A862)
                            : _sheetSub(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pickupTimes[i].$1,
                        style: TextStyle(
                          color: _sheetOn(),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _pickupTimes[i].$2,
                        style: TextStyle(color: _sheetSub(), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _buildPayment(double total, bool enough) {
    final card = _cards[_cardIndex];
    final after = _balances.value[_cardIndex] - total;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _heading('Pay with'),
        _cardPicker(
          selected: _cardIndex,
          onChanged: (i) => setState(() => _cardIndex = i),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panel(),
          child: Column(
            children: [
              _summaryRow(
                'Pickup',
                '${_stores[_storeIndex].name} · ${_pickupTimes[_pickupIndex].$1}',
              ),
              const SizedBox(height: 6),
              _summaryRow('Balance after', enough ? _formatPrice(after) : '—'),
              const SizedBox(height: 10),
              _summaryRow('Total', _formatPrice(total), bold: true),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: enough
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFE53935).withAlpha(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFE53935),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Not enough balance on ${card.name}.',
                          style: TextStyle(color: _sheetOn(), fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _showAddMoneySheet(context, _cardIndex),
                        child: const Text('Add money'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(double total, bool canPay) {
    final last = _step == _steps.length - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _sheetSub().withAlpha(30))),
      ),
      child: _sheetButton(
        label: last
            ? (canPay ? 'Pay ${_formatPrice(total)}' : 'Insufficient balance')
            : 'Continue',
        color: const Color(0xFF00704A),
        onPressed: last ? (canPay ? _pay : null) : () => _goTo(_step + 1),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int current;
  final bool dark;

  const _StepIndicator({
    required this.steps,
    required this.current,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF00A862);
    final idle = dark ? Colors.white24 : Colors.black12;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  // No overshooting curve: it would push the fading shadow's
                  // blur below zero.
                  curve: Curves.easeOutCubic,
                  width: i == current ? 30 : 24,
                  height: i == current ? 30 : 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= current ? green : idle,
                    boxShadow: i == current
                        ? [
                            BoxShadow(
                              color: green.withAlpha(90),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: i < current
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i <= current ? Colors.white : _sheetSub(),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      steps[i],
                      maxLines: 1,
                      style: TextStyle(
                        color: i <= current ? _sheetOn() : _sheetSub(),
                        fontSize: 11,
                        fontWeight: i == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    // A fixed height: the fill would otherwise size itself
                    // to the unbounded height it's given.
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          Container(color: idle),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.centerLeft,
                            widthFactor: i < current ? 1 : 0,
                            heightFactor: 1,
                            child: Container(color: green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Order Status ─────────────────────────────────────────────────────────────

class OrderStatusScreen extends StatefulWidget {
  final PlacedOrder order;

  /// Plays the cup-filling celebration first (right after paying).
  final bool celebrate;

  const OrderStatusScreen({
    super.key,
    required this.order,
    this.celebrate = false,
  });

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late final Animation<double> _fill = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.65, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _check = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 0.8, curve: Curves.elasticOut),
  );
  late final Animation<double> _details = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    if (widget.celebrate) {
      _intro.forward();
    } else {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    const coffee = Color(0xFF9C6B3F);
    const green = Color(0xFF00A862);
    return Scaffold(
      backgroundColor: _sheetBg(),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _wave]),
          builder: (_, __) => Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: _sheetOn()),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 180,
                        height: 210,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: CupPainter(
                                  fill: 0.82 * _fill.value,
                                  wavePhase: _wave.value,
                                  liquid: coffee,
                                  outline: green,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              bottom: 10,
                              child: Transform.scale(
                                scale: _check.value,
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: green,
                                    border: Border.all(
                                      color: _sheetBg(),
                                      width: 4,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: _details.value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - _details.value)),
                          child: _buildDetails(order),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: _details.value,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: _sheetButton(
                    label: 'Done',
                    color: const Color(0xFF00704A),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(PlacedOrder order) => Column(
    children: [
      Text(
        widget.celebrate ? 'Order placed!' : 'Order #${order.number}',
        style: TextStyle(
          color: _sheetOn(),
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        widget.celebrate
            ? 'Order #${order.number} · You earned ${order.starsEarned} ★'
            : 'Pickup at ${order.store.name}',
        style: TextStyle(color: _sheetSub(), fontSize: 13),
      ),
      const SizedBox(height: 22),
      OrderTracker(order: order),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _sheetSub().withAlpha(14),
          border: Border.all(color: _sheetSub().withAlpha(35)),
        ),
        child: Column(
          children: [
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _summaryRow(
                  '${item.quantity}× ${item.drink.name} (${item.size})',
                  _formatPrice(item.totalPrice),
                ),
              ),
            const SizedBox(height: 4),
            _summaryRow('Paid', _formatPrice(order.total), bold: true),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}

class OrderTracker extends StatelessWidget {
  final PlacedOrder order;

  const OrderTracker({super.key, required this.order});

  @override
  Widget build(BuildContext context) => _Ticker(
    builder: (_, now) {
      const green = Color(0xFF00A862);
      final stage = order.stageAt(now);
      final progress = order.progressAt(now);
      final remaining = order.readyAt.difference(now);
      const labels = ['Received', 'Preparing', 'Ready'];
      const icons = [
        Icons.receipt_long_rounded,
        Icons.coffee_maker_rounded,
        Icons.shopping_bag_rounded,
      ];
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [green.withAlpha(40), green.withAlpha(12)],
          ),
          border: Border.all(color: green.withAlpha(90)),
        ),
        child: Column(
          children: [
            Text(
              stage == 2 ? 'Ready for pickup!' : 'Ready in',
              style: TextStyle(color: _sheetSub(), fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              stage == 2 ? order.store.name : _formatCountdown(remaining),
              key: const ValueKey('order-countdown'),
              style: TextStyle(
                color: _sheetOn(),
                fontSize: stage == 2 ? 22 : 40,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _stageDot(icons[i], labels[i], i, stage),
                  if (i < 2)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: i == 0
                                ? (stage >= 1 ? 1 : progress / 0.15)
                                : (stage >= 2
                                      ? 1
                                      : ((progress - 0.15) / 0.85).clamp(
                                          0.0,
                                          1.0,
                                        )),
                            color: green,
                            backgroundColor: _sheetSub().withAlpha(40),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _stageDot(IconData icon, String label, int index, int stage) {
    const green = Color(0xFF00A862);
    final done = index < stage || stage == 2;
    final current = index == stage && stage != 2;
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          _Pulse(
            active: current,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || current ? green : _sheetSub().withAlpha(40),
              ),
              child: Icon(
                done && !current ? Icons.check_rounded : icon,
                color: done || current ? Colors.white : _sheetSub(),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: done || current ? _sheetOn() : _sheetSub(),
              fontSize: 11,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gently pulses its child while [active].
class _Pulse extends StatefulWidget {
  final bool active;
  final Widget child;

  const _Pulse({required this.active, required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween<double>(
      begin: 1,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

// ─── Active Order Banner ──────────────────────────────────────────────────────

class ActiveOrderBanner extends StatelessWidget {
  final PlacedOrder order;
  final bool dark;

  const ActiveOrderBanner({super.key, required this.order, required this.dark});

  @override
  Widget build(BuildContext context) => _Ticker(
    builder: (_, now) {
      const green = Color(0xFF00A862);
      final stage = order.stageAt(now);
      final onBg = dark ? Colors.white : const Color(0xFF15231A);
      final sub = dark ? Colors.white70 : Colors.black54;
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderStatusScreen(order: order),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [green.withAlpha(60), green.withAlpha(20)],
            ),
            border: Border.all(color: green.withAlpha(110)),
          ),
          child: Row(
            children: [
              _Pulse(
                active: stage < 2,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: green,
                  ),
                  child: Icon(
                    stage == 2
                        ? Icons.shopping_bag_rounded
                        : Icons.coffee_maker_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.number} · ${['Received', 'Preparing', 'Ready'][stage]}',
                      style: TextStyle(
                        color: onBg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      stage == 2
                          ? 'Ready at ${order.store.name}'
                          : 'Ready in ${_formatCountdown(order.readyAt.difference(now))} · ${order.store.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sub, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: order.progressAt(now),
                        minHeight: 3,
                        color: green,
                        backgroundColor: sub.withAlpha(40),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => _activeOrder.value = null,
                icon: Icon(Icons.close_rounded, color: sub, size: 18),
              ),
            ],
          ),
        ),
      );
    },
  );
}
