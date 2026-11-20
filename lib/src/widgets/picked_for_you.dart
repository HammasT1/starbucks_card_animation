part of '../../main.dart';

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
