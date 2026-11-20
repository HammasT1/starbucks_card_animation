part of '../../main.dart';

// ─── Cart Tab Icon ────────────────────────────────────────────────────────────

class CartTabIcon extends StatefulWidget {
  final int count;

  const CartTabIcon({super.key, required this.count});

  @override
  State<CartTabIcon> createState() => _CartTabIconState();
}

class _CartTabIconState extends State<CartTabIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 30),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.35,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 70,
    ),
  ]).animate(_ctrl);

  @override
  void initState() {
    super.initState();
    _cartBump.addListener(_bump);
  }

  void _bump() => _ctrl.forward(from: 0);

  @override
  void dispose() {
    _cartBump.removeListener(_bump);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.shopping_bag_rounded),
        if (widget.count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.8),
                    end: Offset.zero,
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  '${widget.count}',
                  key: ValueKey(widget.count),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
