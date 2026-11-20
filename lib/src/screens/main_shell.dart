part of '../../main.dart';

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
          // Screens draw behind the floating bar; their SafeArea keeps
          // content above it.
          extendBody: true,
          body: IndexedStack(
            index: tab,
            children: const [StarbucksCardScreen(), MenuScreen(), CartScreen()],
          ),
          bottomNavigationBar: FloatingNavBar(
            index: tab,
            cartCount: cartCount,
            dark: dark,
            onTap: (i) {
              if (i != tab) _haptic(_Haptic.selection);
              _currentTab.value = i;
            },
          ),
        );
      },
    );
  }
}
