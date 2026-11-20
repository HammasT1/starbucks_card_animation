part of '../../main.dart';

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
