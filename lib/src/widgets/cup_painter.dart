part of '../../main.dart';

// ─── Cup Painter ──────────────────────────────────────────────────────────────

class CupPainter extends CustomPainter {
  final double fill; // 0..1
  final double wavePhase; // 0..1
  final Color liquid;
  final Color outline;

  CupPainter({
    required this.fill,
    required this.wavePhase,
    required this.liquid,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final topY = h * 0.24;
    final bottomY = h * 0.96;
    final topHalf = w * 0.34;
    final bottomHalf = w * 0.25;

    final body = Path()
      ..moveTo(cx - topHalf, topY)
      ..lineTo(cx + topHalf, topY)
      ..lineTo(cx + bottomHalf, bottomY - 8)
      ..quadraticBezierTo(
        cx + bottomHalf - 2,
        bottomY,
        cx + bottomHalf - 10,
        bottomY,
      )
      ..lineTo(cx - bottomHalf + 10, bottomY)
      ..quadraticBezierTo(
        cx - bottomHalf + 2,
        bottomY,
        cx - bottomHalf,
        bottomY - 8,
      )
      ..close();

    // Glass tint.
    canvas.drawPath(body, Paint()..color = outline.withAlpha(22));

    // Liquid with a moving wave on top.
    if (fill > 0) {
      canvas.save();
      canvas.clipPath(body);
      final level = bottomY - (bottomY - topY) * fill;
      final amplitude = fill >= 0.999 ? 0.0 : 4.0;
      final wave = Path()..moveTo(0, level);
      for (double x = 0; x <= w; x += 3) {
        wave.lineTo(
          x,
          level + sin((x / w) * 2 * pi * 1.5 + wavePhase * 2 * pi) * amplitude,
        );
      }
      wave
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        wave,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(liquid, Colors.white, 0.35)!, liquid],
          ).createShader(Rect.fromLTWH(0, level, w, bottomY - level)),
      );
      canvas.restore();
    }

    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(body, stroke);

    // Sleeve band.
    final sleeveTop = topY + (bottomY - topY) * 0.38;
    final sleeveBottom = topY + (bottomY - topY) * 0.6;
    double halfAt(double y) =>
        topHalf + (bottomHalf - topHalf) * ((y - topY) / (bottomY - topY));
    final sleeve = Path()
      ..moveTo(cx - halfAt(sleeveTop), sleeveTop)
      ..lineTo(cx + halfAt(sleeveTop), sleeveTop)
      ..lineTo(cx + halfAt(sleeveBottom), sleeveBottom)
      ..lineTo(cx - halfAt(sleeveBottom), sleeveBottom)
      ..close();
    canvas.drawPath(sleeve, Paint()..color = outline.withAlpha(70));

    // Lid and straw.
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - topHalf - 6, topY - h * 0.08, cx + topHalf + 6, topY),
      const Radius.circular(6),
    );
    canvas.drawRRect(lid, Paint()..color = outline);
    canvas.drawLine(
      Offset(cx + topHalf * 0.25, topY - h * 0.08),
      Offset(cx + topHalf * 0.6, h * 0.02),
      Paint()
        ..color = outline
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(CupPainter old) =>
      old.fill != fill ||
      old.wavePhase != wavePhase ||
      old.liquid != liquid ||
      old.outline != outline;
}
