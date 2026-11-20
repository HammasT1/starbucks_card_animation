part of '../../main.dart';

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
    _haptic(_Haptic.light);
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
            _stat(
              'Balance',
              _balances.value[_current],
              _formatPrice,
              _ink(c.accent, dark),
            ),
            _divider(),
            _stat(
              'Stars',
              _stars.value.toDouble(),
              (v) => '${v.round()} ★',
              dark ? Colors.yellowAccent : const Color(0xFF9A6B00),
            ),
            _divider(),
            _stat('Tier', 0, (_) => c.tier, _ink(c.accent, dark)),
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
            _ink(c.accent, _isDark.value),
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
