part of '../../main.dart';

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
                          onTap: () {
                            if (cat != _selectedCat) {
                              _haptic(_Haptic.selection);
                            }
                            setState(() => _selectedCat = cat);
                          },
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
