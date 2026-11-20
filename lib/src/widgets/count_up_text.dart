part of '../../main.dart';

// ─── Count-up Text ────────────────────────────────────────────────────────────

/// Animates from the previous value to the new one whenever [value] changes.
class CountUpText extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle style;

  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    required this.style,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: value, end: value),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (_, v, __) => Text(format(v), style: style),
  );
}
