part of '../../main.dart';

// ─── Drink Data ───────────────────────────────────────────────────────────────

class DrinkData {
  final String name, category, description, price, origin, ingredients;

  /// Nutrition for a Grande with the default options.
  final int calories, caffeine, sugar;
  final String asset;
  final List<Color> gradient;
  final Color accent;
  final List<String> sizes;

  const DrinkData({
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.origin,
    required this.ingredients,
    required this.calories,
    required this.caffeine,
    required this.sugar,
    required this.asset,
    required this.gradient,
    required this.accent,
    required this.sizes,
  });
}
