part of '../../main.dart';

// ─── Cart Screen ──────────────────────────────────────────────────────────────

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_isDark, _cart, _activeOrder]),
      builder: (_, __) {
        final dark = _isDark.value;
        final items = _cart.value;
        final total = _cartTotal(items);
        final onBg = dark ? Colors.white : const Color(0xFF15231A);
        final subBg = dark ? Colors.white70 : Colors.black54;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF12241E),
                      Color(0xFF09140F),
                      Color(0xFF000000),
                    ]
                  : const [
                      Color(0xFFF4FBF6),
                      Color(0xFFE8F5E9),
                      Color(0xFFFFFFFF),
                    ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready to order',
                              style: TextStyle(color: subBg, fontSize: 12),
                            ),
                            Text(
                              'Your Cart',
                              style: TextStyle(
                                color: onBg,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildThemeToggle(),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: _activeOrder.value == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: ActiveOrderBanner(
                            order: _activeOrder.value!,
                            dark: dark,
                          ),
                        ),
                ),
                if (items.isEmpty)
                  Expanded(child: EmptyCart(dark: dark))
                else
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final item = items[index];
                              return Dismissible(
                                key: ValueKey(item.id),
                                direction: DismissDirection.endToStart,
                                background: _swipeBackground(),
                                onDismissed: (_) =>
                                    _removeWithUndo(context, item),
                                child: _CartTile(item: item, dark: dark),
                              );
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: dark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(6),
                            border: Border.all(
                              color: dark
                                  ? Colors.white.withAlpha(16)
                                  : Colors.black.withAlpha(12),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Items',
                                    style: TextStyle(
                                      color: subBg,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${_cartCount(items)}',
                                    style: TextStyle(
                                      color: onBg,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      color: onBg,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  CountUpText(
                                    value: total,
                                    format: _formatPrice,
                                    style: TextStyle(
                                      color: _ink(
                                        const Color(0xFFCBA258),
                                        dark,
                                      ),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const CheckoutScreen(),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00704A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    'Checkout • ${_formatPrice(total)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _swipeBackground() => Container(
  alignment: Alignment.centerRight,
  padding: const EdgeInsets.symmetric(horizontal: 24),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    gradient: const LinearGradient(
      colors: [Color(0x00E53935), Color(0xFFE53935)],
    ),
  ),
  child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Remove',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      SizedBox(width: 8),
      Icon(Icons.delete_outline_rounded, color: Colors.white),
    ],
  ),
);

class _CartTile extends StatelessWidget {
  final CartItem item;
  final bool dark;

  const _CartTile({required this.item, required this.dark});

  @override
  Widget build(BuildContext context) {
    final onBg = dark ? Colors.white : const Color(0xFF15231A);
    final subBg = dark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: dark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
        border: Border.all(
          color: dark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(12),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            item.drink.asset,
            height: 70,
            width: 70,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.local_cafe, color: item.drink.accent, size: 46),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.drink.name,
                  style: TextStyle(
                    color: onBg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Size: ${item.size} • ${_formatPrice(item.unitPrice)} each',
                  style: TextStyle(color: subBg, fontSize: 12),
                ),
                if (item.options.summary(item.drink).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.options.summary(item.drink),
                      style: TextStyle(
                        color: _ink(item.drink.accent, dark),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () => item.quantity == 1
                          ? _removeWithUndo(context, item)
                          : _updateCartQuantity(item.id, item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          color: onBg,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () =>
                          _updateCartQuantity(item.id, item.quantity + 1),
                    ),
                    const Spacer(),
                    Text(
                      _formatPrice(item.totalPrice),
                      style: TextStyle(
                        color: _ink(item.drink.accent, dark),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeWithUndo(context, item),
            icon: Icon(
              Icons.close_rounded,
              color: dark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
