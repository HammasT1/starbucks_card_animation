part of '../../main.dart';

// ─── Rewards Ring ─────────────────────────────────────────────────────────────

const int _starsPerReward = 400;

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: 3 * pi / 2,
          colors: [color.withAlpha(140), color],
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class RewardsCard extends StatelessWidget {
  final int stars;
  final Color accent;
  final bool dark;

  const RewardsCard({
    super.key,
    required this.stars,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = dark ? Colors.white : const Color(0xFF1B1B1B);
    final sub = dark ? Colors.white.withAlpha(150) : Colors.black54;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: stars.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        final progress = (v % _starsPerReward) / _starsPerReward;
        final toGo = _starsPerReward - (v.round() % _starsPerReward);
        final ready = v.round() ~/ _starsPerReward;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: _glassBox(dark),
          child: Row(
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress,
                    color: accent,
                    track: dark
                        ? Colors.white.withAlpha(30)
                        : Colors.black.withAlpha(20),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${v.round()}',
                          style: TextStyle(
                            color: onBg,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          '★',
                          style: TextStyle(
                            color: _ink(accent, dark),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rewards',
                      style: TextStyle(
                        color: onBg,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$toGo★ until your next free drink',
                      style: TextStyle(color: sub, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: ready > 0
                          ? Container(
                              key: const ValueKey('ready'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: accent.withAlpha(45),
                                border: Border.all(
                                  color: accent.withAlpha(120),
                                ),
                              ),
                              child: Text(
                                '🎁 $ready free drink${ready == 1 ? '' : 's'} ready',
                                style: TextStyle(
                                  color: onBg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Text(
                              key: const ValueKey('earn'),
                              'Earn 2★ for every \$1 spent',
                              style: TextStyle(
                                color: _ink(accent, dark),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
    );
  }
}

BoxDecoration _glassBox(bool dark) => BoxDecoration(
  borderRadius: BorderRadius.circular(22),
  color: dark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(8),
  border: Border.all(
    color: dark ? Colors.white.withAlpha(35) : Colors.black.withAlpha(20),
  ),
);
