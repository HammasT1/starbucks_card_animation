part of '../../main.dart';

// ─── Size Pricing ─────────────────────────────────────────────────────────────

const Map<String, double> _sizeDelta = {
  'Tall': -0.50,
  'Grande': 0,
  'Venti': 0.50,
  'Trenta': 0.80,
};

double _priceFor(DrinkData drink, String size) =>
    _parsePrice(drink.price) + (_sizeDelta[size] ?? 0);

const Map<String, int> _sizeVolumeMl = {
  'Tall': 354,
  'Grande': 473,
  'Venti': 591,
  'Trenta': 916,
};
const Map<String, double> _sizeFactor = {
  'Tall': 0.75,
  'Grande': 1.0,
  'Venti': 1.25,
  'Trenta': 1.6,
};
const Map<String, double> _cupScale = {
  'Tall': 0.8,
  'Grande': 0.92,
  'Venti': 1.04,
  'Trenta': 1.16,
};
