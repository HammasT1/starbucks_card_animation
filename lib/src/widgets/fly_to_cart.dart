part of '../../main.dart';

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
