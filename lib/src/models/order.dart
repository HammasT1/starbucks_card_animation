part of '../../main.dart';

// ─── Orders ───────────────────────────────────────────────────────────────────

class PickupStore {
  final String name, address;
  final double distanceKm;
  final String hours;

  const PickupStore(this.name, this.address, this.distanceKm, this.hours);
}

const List<PickupStore> _stores = [
  PickupStore('Downtown Plaza', '12 Market Street', 0.4, 'Open until 10 PM'),
  PickupStore(
    'Riverside Mall',
    'Level 2, Riverside Mall',
    1.2,
    'Open until 9 PM',
  ),
  PickupStore('Central Station', 'Main concourse', 2.1, 'Open 24 hours'),
];

/// Pickup options: label and minutes until ready.
const List<(String, String, int)> _pickupTimes = [
  ('ASAP', '~5 min', 5),
  ('In 15 min', 'Scheduled', 15),
  ('In 30 min', 'Scheduled', 30),
];

class PlacedOrder {
  final int number;
  final List<CartItem> items;
  final double total;
  final int starsEarned;
  final PickupStore store;
  final DateTime placedAt, readyAt;

  const PlacedOrder({
    required this.number,
    required this.items,
    required this.total,
    required this.starsEarned,
    required this.store,
    required this.placedAt,
    required this.readyAt,
  });

  double progressAt(DateTime now) {
    final total = readyAt.difference(placedAt).inMilliseconds;
    if (total <= 0) return 1;
    return (now.difference(placedAt).inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// 0 = received, 1 = preparing, 2 = ready.
  int stageAt(DateTime now) {
    final p = progressAt(now);
    if (p >= 1) return 2;
    return p < 0.15 ? 0 : 1;
  }
}
