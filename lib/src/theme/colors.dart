part of '../../main.dart';

// ─── Theme Helpers ────────────────────────────────────────────────────────────

/// Accent colours are tuned for dark backgrounds; darken them on light ones so
/// text stays readable.
Color _ink(Color accent, bool dark) =>
    dark ? accent : Color.lerp(accent, Colors.black, 0.45)!;
