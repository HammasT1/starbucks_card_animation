part of '../../main.dart';

// ─── Empty Cart ───────────────────────────────────────────────────────────────

class EmptyCart extends StatefulWidget {
  final bool dark;

  const EmptyCart({super.key, required this.dark});

  @override
  State<EmptyCart> createState() => _EmptyCartState();
}

class _EmptyCartState extends State<EmptyCart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final onBg = dark ? Colors.white : const Color(0xFF15231A);
    final sub = dark ? Colors.white70 : Colors.black54;
    const green = Color(0xFF00A862);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final t = Curves.easeInOut.transform(_ctrl.value);
                return SizedBox(
                  width: 150,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Shadow shrinks as the cup rises.
                      Container(
                        width: 70 + 20 * (1 - t),
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.black.withAlpha(
                            (dark ? 90 : 35) + (30 * (1 - t)).round(),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 14 + 14 * t,
                        child: Transform.rotate(
                          angle: (t - 0.5) * 0.12,
                          child: CustomPaint(
                            size: const Size(110, 140),
                            painter: CupPainter(
                              fill: 0,
                              wavePhase: 0,
                              liquid: green,
                              outline: green,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
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
              'Your next favourite drink is one tap away.',
              textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontSize: 13),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => _currentTab.value = 1,
              icon: const Icon(Icons.local_cafe_rounded, size: 18),
              label: const Text(
                'Browse menu',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00704A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
