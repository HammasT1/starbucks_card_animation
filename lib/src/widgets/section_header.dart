part of '../../main.dart';

// ─── Section Header ───────────────────────────────────────────────────────────

Widget _sectionHeader(
  String title, {
  required bool dark,
  String? action,
  VoidCallback? onAction,
}) => Padding(
  padding: const EdgeInsets.fromLTRB(24, 0, 16, 6),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1B1B1B),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: dark ? Colors.white70 : Colors.black54,
          ),
          child: Text(action, style: const TextStyle(fontSize: 12)),
        ),
    ],
  ),
);
