import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

void main() => runApp(const MyApp());

// ─── Theme Mode ───────────────────────────────────────────────────────────────

final ValueNotifier<bool> _isDark = ValueNotifier<bool>(true);
final ValueNotifier<List<CartItem>> _cart = ValueNotifier<List<CartItem>>([]);

double _parsePrice(String price) {
  final normalized = price.replaceAll(r'\\$', '').replaceAll(r'$', '');
  return double.tryParse(normalized.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

String _formatPrice(double value) => '\$${value.toStringAsFixed(2)}';

void _addToCart(DrinkData drink, {required String size, int quantity = 1}) {
  final items = List<CartItem>.from(_cart.value);
  final index = items.indexWhere(
    (item) => item.drink.name == drink.name && item.size == size,
  );

  if (index >= 0) {
    final current = items[index];
    items[index] = current.copyWith(quantity: current.quantity + quantity);
  } else {
    items.add(CartItem(drink: drink, size: size, quantity: quantity));
  }

  _cart.value = items;
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

Future<void> _showCheckoutSheet(BuildContext context) {
  var cardIndex = _activeCard.value;
  return _showAppSheet(
    context,
    title: 'Checkout',
    subtitle: 'Choose a card to pay with',
    builder: (sheetContext) => AnimatedBuilder(
      animation: Listenable.merge([_balances, _cart]),
      builder: (_, __) => StatefulBuilder(
        builder: (_, setSheet) {
          final items = _cart.value;
          final total = _cartTotal(items);
          final balance = _balances.value[cardIndex];
          final enough = balance >= total;
          final starsEarned = (total * 2).floor();
          final card = _cards[cardIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cards.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final c = _cards[i];
                    final active = i == cardIndex;
                    return GestureDetector(
                      onTap: () => setSheet(() => cardIndex = i),
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
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: c.accent,
                                    size: 16,
                                  ),
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
              ),
              const SizedBox(height: 20),
              _summaryRow('Items', '${_cartCount(items)}'),
              const SizedBox(height: 6),
              _summaryRow('Stars you\'ll earn', '+$starsEarned ★'),
              const SizedBox(height: 6),
              _summaryRow('Total', _formatPrice(total), bold: true),
              if (!enough) ...[
                const SizedBox(height: 14),
                Container(
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
                            _showAddMoneySheet(sheetContext, cardIndex),
                        child: const Text('Add money'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _sheetButton(
                label: enough
                    ? 'Pay ${_formatPrice(total)}'
                    : 'Insufficient balance',
                color: const Color(0xFF00704A),
                onPressed: enough && items.isNotEmpty
                    ? () {
                        final count = _cartCount(items);
                        _recordTxn(
                          cardIndex,
                          'Order · $count item${count == 1 ? '' : 's'}',
                          -total,
                        );
                        _stars.value += starsEarned;
                        _cart.value = [];
                        Navigator.of(sheetContext).pop();
                        _showOrderPlacedDialog(context, starsEarned);
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    ),
  );
}

Widget _summaryRow(String label, String value, {bool bold = false}) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      label,
      style: TextStyle(
        color: bold ? _sheetOn() : _sheetSub(),
        fontSize: bold ? 18 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      ),
    ),
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

Future<void> _showOrderPlacedDialog(BuildContext context, int starsEarned) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: _sheetBg(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF00704A),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Order placed!',
            style: TextStyle(
              color: _sheetOn(),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your drinks will be ready in about 5 minutes.\nYou earned $starsEarned ★',
            textAlign: TextAlign.center,
            style: TextStyle(color: _sheetSub(), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          _sheetButton(
            label: 'Done',
            color: const Color(0xFF00704A),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    ),
  );
}

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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_isDark, _cart]),
      builder: (_, __) {
        final dark = _isDark.value;
        final cartCount = _cartCount(_cart.value);
        return Scaffold(
          body: IndexedStack(
            index: _tab,
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
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
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
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_bag_rounded),
                      if (cartCount > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$cartCount',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
  final int calories;
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

  const CartItem({
    required this.drink,
    required this.size,
    required this.quantity,
  });

  String get id => '${drink.name}::$size';
  double get unitPrice => _priceFor(drink, size);
  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({DrinkData? drink, String? size, int? quantity}) =>
      CartItem(
        drink: drink ?? this.drink,
        size: size ?? this.size,
        quantity: quantity ?? this.quantity,
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

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCat = 'All';
  static const _categories = ['All', 'Hot', 'Cold', 'Seasonal'];
  late final AnimationController _animCtrl;

  void _quickAddToCart(BuildContext context, DrinkData drink) {
    final size = drink.sizes.contains('Grande') ? 'Grande' : drink.sizes.first;
    _addToCart(drink, size: size);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${drink.name} added to cart'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  List<DrinkData> get _filtered => _selectedCat == 'All'
      ? _drinks
      : _drinks.where((d) => d.category == _selectedCat).toList();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDark,
      builder: (_, dark, __) => Container(
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
              _buildMenuHeader(),
              const SizedBox(height: 12),
              _buildCategories(),
              const SizedBox(height: 14),
              Expanded(child: _buildDrinkGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuHeader() {
    final dark = _isDark.value;
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
            child: Text(
              '${_drinks.length} drinks',
              style: TextStyle(
                color: dark ? Colors.white70 : const Color(0xFF00704A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final dark = _isDark.value;
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final active = cat == _selectedCat;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCat = cat);
              _animCtrl.forward(from: 0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFF00704A), Color(0xFF1E3932)],
                      )
                    : null,
                color: active
                    ? null
                    : dark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(8),
                border: Border.all(
                  color: active
                      ? const Color(0xFF00704A)
                      : dark
                      ? Colors.white.withAlpha(40)
                      : Colors.black.withAlpha(20),
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00704A).withAlpha(80),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: active
                      ? Colors.white
                      : dark
                      ? Colors.white60
                      : Colors.black54,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrinkGrid() {
    final drinks = _filtered;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: GridView.builder(
        key: ValueKey(_selectedCat),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: drinks.length,
        itemBuilder: (ctx, i) => _buildDrinkCard(ctx, drinks[i], i),
      ),
    );
  }

  Widget _buildDrinkCard(BuildContext ctx, DrinkData d, int i) =>
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
        child: GestureDetector(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: d.accent.withAlpha(40),
                            border: Border.all(color: d.accent.withAlpha(100)),
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
                        const SizedBox(height: 10),
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
                          style: TextStyle(
                            color: _isDark.value
                                ? Colors.white
                                : const Color(0xFF132018),
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
                                  onTap: () => _quickAddToCart(ctx, d),
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
      );
}

// ─── Cart Screen ──────────────────────────────────────────────────────────────

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_isDark, _cart]),
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
                if (items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF00704A).withAlpha(60),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Color(0xFF00704A),
                              size: 54,
                            ),
                          ),
                          const SizedBox(height: 14),
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
                            'Add drinks from the menu and adjust quantity here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subBg, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
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
                              return _CartTile(item: item, dark: dark);
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
                                  Text(
                                    _formatPrice(total),
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
                                  onPressed: () => _showCheckoutSheet(context),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () =>
                          _updateCartQuantity(item.id, item.quantity - 1),
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
            onPressed: () => _removeFromCart(item.id),
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
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _bob = Tween<double>(
      begin: -12,
      end: 12,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _selectedSize = widget.drink.sizes.contains('Grande')
        ? 'Grande'
        : widget.drink.sizes.first;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drink;
    final unitPrice = _priceFor(d, _selectedSize);
    final totalPrice = unitPrice * _quantity;
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
              ),
              Expanded(
                flex: 3,
                child: AnimatedBuilder(
                  animation: _bob,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _bob.value),
                    child: Center(
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
                        child: Transform.rotate(
                          angle: sin(_ctrl.value * pi * 2) * 0.06,
                          child: Hero(
                            tag: widget.heroTag ?? 'drink-${d.name}',
                            child: Image.asset(
                              d.asset,
                              height: 180,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.local_cafe,
                                color: d.accent,
                                size: 130,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(130),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
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
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.place_rounded,
                                  color: d.accent,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Origin: ${d.origin}',
                                  style: TextStyle(
                                    color: d.accent.withAlpha(200),
                                    fontSize: 12,
                                  ),
                                ),
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
                                Text(
                                  '${d.calories} cal',
                                  style: TextStyle(
                                    color: d.accent.withAlpha(200),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                        const SizedBox(height: 22),
                        _sectionLabel('Quantity', d.accent),
                        const SizedBox(height: 10),
                        _quantityPicker(d),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _addToCart(
                                d,
                                size: _selectedSize,
                                quantity: _quantity,
                              );
                              _showSnack(
                                context,
                                '${d.name} ($_selectedSize) x$_quantity added to cart',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: d.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 8,
                              shadowColor: d.accent.withAlpha(120),
                            ),
                            child: Text(
                              'Add $_quantity to Cart • ${_formatPrice(totalPrice)}',
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
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _sizePicker(DrinkData d) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: d.sizes.map((s) {
        final active = s == _selectedSize;
        return GestureDetector(
          onTap: () => setState(() => _selectedSize = s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: active
                  ? LinearGradient(colors: [d.accent, d.accent.withAlpha(180)])
                  : null,
              color: active ? null : Colors.white.withAlpha(15),
              border: Border.all(
                color: active ? d.accent : Colors.white.withAlpha(40),
              ),
              boxShadow: active
                  ? [BoxShadow(color: d.accent.withAlpha(80), blurRadius: 12)]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s,
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white60,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
                Text(
                  _sizeDeltaLabel(s),
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
      }).toList(),
    ),
  );

  Widget _quantityPicker(DrinkData d) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withAlpha(10),
      border: Border.all(color: Colors.white.withAlpha(18)),
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
        Expanded(
          child: Center(
            child: Text(
              '$_quantity',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _QtyButton(
          icon: Icons.add,
          onTap: () => setState(() => _quantity += 1),
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
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _drinks.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (ctx, i) {
        final d = _drinks[i];
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
