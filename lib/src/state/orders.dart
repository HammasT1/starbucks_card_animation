part of '../../main.dart';

final ValueNotifier<PlacedOrder?> _activeOrder = ValueNotifier<PlacedOrder?>(
  null,
);

String _formatCountdown(Duration d) {
  if (d.isNegative) return '0:00';
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
