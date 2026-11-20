part of '../../main.dart';

// ─── Haptics ──────────────────────────────────────────────────────────────────

enum _Haptic { selection, light, medium, success }

/// Small vibration feedback. Ignored on platforms without haptics.
void _haptic(_Haptic kind) {
  switch (kind) {
    case _Haptic.selection:
      HapticFeedback.selectionClick();
    case _Haptic.light:
      HapticFeedback.lightImpact();
    case _Haptic.medium:
      HapticFeedback.mediumImpact();
    case _Haptic.success:
      HapticFeedback.heavyImpact();
  }
}
