part of '../../main.dart';

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
    onTap: () {
      if (!active) _haptic(_Haptic.selection);
      onTap();
    },
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
                      onTap: () {
                        if (o != selected) _haptic(_Haptic.selection);
                        onChanged(o);
                      },
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
