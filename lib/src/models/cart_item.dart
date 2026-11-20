part of '../../main.dart';

class CartItem {
  final DrinkData drink;
  final String size;
  final int quantity;
  final DrinkOptions options;

  const CartItem({
    required this.drink,
    required this.size,
    required this.quantity,
    required this.options,
  });

  String get id => '${drink.name}::$size::${options.key}';
  double get unitPrice => _priceFor(drink, size) + options.extraCost(drink);
  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
    drink: drink,
    size: size,
    quantity: quantity ?? this.quantity,
    options: options,
  );
}
