part of '../../main.dart';

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      _haptic(_Haptic.selection);
      onTap();
    },
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF00704A).withAlpha(24),
        border: Border.all(color: const Color(0xFF00704A).withAlpha(60)),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF00704A)),
    ),
  );
}
