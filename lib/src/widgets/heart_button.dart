part of '../../main.dart';

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
            _haptic(_Haptic.light);
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
