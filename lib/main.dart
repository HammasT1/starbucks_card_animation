import 'dart:math';
import 'package:flutter/material.dart';

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
        fontFamily: 'sans-serif',
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00704A),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'sans-serif',
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
  double get unitPrice => _parsePrice(drink.price);
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
    name: 'Vanilla Latte',
    category: 'Hot',
    description:
        'Dark espresso balanced with creamy steamed milk and sweet vanilla syrup. Smooth, timeless, perfect.',
    price: r'$5.15',
    origin: 'Italy',
    ingredients: 'Milk, Espresso, Vanilla Syrup',
    calories: 280,
    asset: 'images/cupGreen.png',
    gradient: [Color(0xFF5D4037), Color(0xFF3E2723)],
    accent: Color(0xFFFFF9C4),
    sizes: ['Tall', 'Grande', 'Venti'],
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
    price: r'\$5.25',
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
    price: r'\$5.45',
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
    price: r'\$5.65',
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
      _shimmerCtrl;
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
  }

  void _onPageChanged(int idx) {
    final prev = _current;
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
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            children: [
                              _buildStats(c),
                              const SizedBox(height: 12),
                              _buildActions(c),
                              const SizedBox(height: 6),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(color: onBgSub, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                'My Starbucks',
                style: TextStyle(
                  color: onBg,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateY(tilt);
    matrix.multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
    return Transform(
      transform: matrix,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    errorBuilder: (_, __, ___) => const Icon(
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
                                          _logoAngle.value + orbitIndex * 2.1;
                                      return Positioned(
                                        left: cos(angle) * 34,
                                        top: sin(angle) * 18,
                                        child: Container(
                                          width: 10 + orbitIndex * 3,
                                          height: 10 + orbitIndex * 3,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: card.accent.withAlpha(
                                              90 - orbitIndex * 18,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: card.accent.withAlpha(
                                                  90,
                                                ),
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
                                                color: card.accent.withAlpha(
                                                  (_glowAlpha.value * 140)
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
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.local_cafe,
                                              color: Colors.white.withAlpha(
                                                180,
                                              ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              Text(
                                card.balance,
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
            _stat('Balance', c.balance, c.accent),
            _divider(),
            _stat('Stars', '315 *', Colors.yellowAccent),
            _divider(),
            _stat('Tier', c.tier, c.accent),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
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
        Text(
          value,
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
          _actionBtn('Add Money', Icons.add_card_rounded, c.accent),
          const SizedBox(width: 10),
          _actionBtn('Pay', Icons.nfc_rounded, iconClr),
          const SizedBox(width: 10),
          _actionBtn('History', Icons.receipt_long_rounded, iconClr),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color iconColor) {
    final dark = _isDark.value;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
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
                                  onPressed: () {},
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
          Hero(
            tag: 'drink-${item.drink.name}',
            child: Image.asset(
              item.drink.asset,
              height: 70,
              width: 70,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.local_cafe, color: item.drink.accent, size: 46),
            ),
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

  const DrinkDetailScreen({super.key, required this.drink});

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
    final totalPrice = _parsePrice(d.price) * _quantity;
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
                            tag: 'drink-${d.name}',
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
                            Text(
                              d.price,
                              style: TextStyle(
                                color: d.accent,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${d.name} x$_quantity added to cart',
                                  ),
                                  duration: const Duration(milliseconds: 1200),
                                ),
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
            child: Text(
              s,
              style: TextStyle(
                color: active ? Colors.black : Colors.white60,
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w400,
              ),
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
