part of '../../main.dart';

// ─── Drink Options ────────────────────────────────────────────────────────────

const List<String> _milkTypes = ['Whole', 'Skim', 'Oat', 'Almond', 'Coconut'];
const Map<String, double> _milkCost = {
  'Whole': 0,
  'Skim': 0,
  'Oat': 0.70,
  'Almond': 0.70,
  'Coconut': 0.70,
};

/// Calories relative to whole milk, for a Grande.
const Map<String, int> _milkCalories = {
  'Whole': 0,
  'Skim': -40,
  'Oat': 20,
  'Almond': -30,
  'Coconut': -10,
};
const List<String> _sweetnessLevels = ['None', 'Light', 'Regular', 'Extra'];
const Map<String, double> _sweetFactor = {
  'None': 0.3,
  'Light': 0.65,
  'Regular': 1.0,
  'Extra': 1.35,
};
const double _shotCost = 0.80;
const int _maxExtraShots = 4;

bool _hasMilk(DrinkData d) => d.ingredients.toLowerCase().contains('milk');
bool _hasEspresso(DrinkData d) {
  final i = d.ingredients.toLowerCase();
  return i.contains('espresso') || i.contains('coffee');
}

bool _hasSugar(DrinkData d) => d.sugar > 0;
String _defaultMilk(DrinkData d) =>
    d.ingredients.contains('Coconut Milk') ? 'Coconut' : 'Whole';

class DrinkOptions {
  /// Null when the drink has no milk.
  final String? milk;
  final int extraShots;
  final String sweetness;

  const DrinkOptions({
    this.milk,
    this.extraShots = 0,
    this.sweetness = 'Regular',
  });

  factory DrinkOptions.defaultFor(DrinkData d) =>
      DrinkOptions(milk: _hasMilk(d) ? _defaultMilk(d) : null);

  DrinkOptions copyWith({String? milk, int? extraShots, String? sweetness}) =>
      DrinkOptions(
        milk: milk ?? this.milk,
        extraShots: extraShots ?? this.extraShots,
        sweetness: sweetness ?? this.sweetness,
      );

  double milkCost(DrinkData d) =>
      milk == null || milk == _defaultMilk(d) ? 0 : _milkCost[milk] ?? 0;

  double extraCost(DrinkData d) => milkCost(d) + extraShots * _shotCost;

  String get key => '${milk ?? '-'}|$extraShots|$sweetness';

  /// Short description of what differs from the default, e.g.
  /// "Oat milk · +2 shots · Light sweet". Empty when nothing changed.
  String summary(DrinkData d) => [
    if (milk != null && milk != _defaultMilk(d)) '$milk milk',
    if (extraShots > 0) '+$extraShots shot${extraShots == 1 ? '' : 's'}',
    if (sweetness == 'None') 'No sweetener',
    if (sweetness == 'Light' || sweetness == 'Extra') '$sweetness sweet',
  ].join(' · ');

  @override
  bool operator ==(Object other) => other is DrinkOptions && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class Nutrition {
  final int calories, caffeine, sugar;

  const Nutrition(this.calories, this.caffeine, this.sugar);
}

Nutrition _nutritionFor(DrinkData d, String size, DrinkOptions o) {
  final f = _sizeFactor[size] ?? 1;
  final baseSugar = d.sugar * f;
  final sugar = baseSugar * (_sweetFactor[o.sweetness] ?? 1);
  final milkCalories = o.milk == null
      ? 0
      : (_milkCalories[o.milk]! - _milkCalories[_defaultMilk(d)]!) * f;
  final calories =
      d.calories * f +
      milkCalories +
      o.extraShots * 5 +
      (sugar - baseSugar) * 4;
  final caffeine = d.caffeine * f + o.extraShots * 75;
  return Nutrition(max(0, calories.round()), caffeine.round(), sugar.round());
}

String _sizeDeltaLabel(String size) {
  final delta = _sizeDelta[size] ?? 0;
  if (delta == 0) return 'Base';
  return '${delta > 0 ? '+' : '−'}${_formatPrice(delta.abs())}';
}
