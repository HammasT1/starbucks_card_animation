part of '../../main.dart';

Widget _buildThemeToggle() => ValueListenableBuilder<bool>(
  valueListenable: _isDark,
  builder: (_, dark, __) => GestureDetector(
    onTap: () {
      _haptic(_Haptic.light);
      _isDark.value = !dark;
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      width: 54,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark ? const Color(0xFF263238) : const Color(0xFFFFF8E1),
        border: Border.all(
          color: dark
              ? Colors.white.withAlpha(60)
              : const Color(0xFFFFB300).withAlpha(180),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? const Color(0xFF3F51B5).withAlpha(100)
                : const Color(0xFFFFB300).withAlpha(100),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? const Color(0xFF5C6BC0) : const Color(0xFFFFB300),
            boxShadow: [
              BoxShadow(
                color: dark
                    ? const Color(0xFF5C6BC0).withAlpha(160)
                    : const Color(0xFFFFB300).withAlpha(160),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            color: Colors.white,
            size: 13,
          ),
        ),
      ),
    ),
  ),
);
