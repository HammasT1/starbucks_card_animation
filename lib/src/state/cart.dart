part of '../../main.dart';

void _addToCart(
  DrinkData drink, {
  required String size,
  int quantity = 1,
  DrinkOptions? options,
}) {
  final opts = options ?? DrinkOptions.defaultFor(drink);
  final items = List<CartItem>.from(_cart.value);
  final added = CartItem(
    drink: drink,
    size: size,
    quantity: quantity,
    options: opts,
  );
  final index = items.indexWhere((item) => item.id == added.id);

  if (index >= 0) {
    final current = items[index];
    items[index] = current.copyWith(quantity: current.quantity + quantity);
  } else {
    items.add(added);
  }

  _cart.value = items;
  _cartBump.value++;
  _haptic(_Haptic.light);
}

void _updateCartQuantity(String id, int quantity) {
  final items = List<CartItem>.from(_cart.value);
  final index = items.indexWhere((item) => item.id == id);
  if (index == -1) return;

  if (quantity <= 0) {
    items.removeAt(index);
  } else {
    items[index] = items[index].copyWith(quantity: quantity);
  }

  _cart.value = items;
}

void _removeFromCart(String id) {
  _cart.value = _cart.value.where((item) => item.id != id).toList();
}

/// Removes [item] and offers an Undo that puts it back in the same place.
void _removeWithUndo(BuildContext context, CartItem item) {
  final index = _cart.value.indexWhere((i) => i.id == item.id);
  if (index < 0) return;
  _removeFromCart(item.id);
  _haptic(_Haptic.medium);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${item.drink.name} removed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final items = List<CartItem>.from(_cart.value);
            if (items.any((i) => i.id == item.id)) return;
            items.insert(min(index, items.length), item);
            _cart.value = items;
          },
        ),
      ),
    );
}

int _cartCount(List<CartItem> items) =>
    items.fold<int>(0, (total, item) => total + item.quantity);

double _cartTotal(List<CartItem> items) =>
    items.fold<double>(0, (total, item) => total + item.totalPrice);
