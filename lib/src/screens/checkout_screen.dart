part of '../../main.dart';

// ─── Checkout ─────────────────────────────────────────────────────────────────

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _steps = ['Review', 'Pickup', 'Payment'];
  int _step = 0;
  bool _forward = true;
  int _storeIndex = 0;
  int _pickupIndex = 0;
  int _cardIndex = _activeCard.value;

  void _goTo(int step) {
    _haptic(_Haptic.selection);
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      _goTo(_step - 1);
    }
  }

  void _pay() {
    final items = _cart.value;
    final total = _cartTotal(items);
    final count = _cartCount(items);
    final starsEarned = (total * 2).floor();
    final now = DateTime.now();
    final order = PlacedOrder(
      number: 1000 + Random().nextInt(9000),
      items: List<CartItem>.from(items),
      total: total,
      starsEarned: starsEarned,
      store: _stores[_storeIndex],
      placedAt: now,
      readyAt: now.add(Duration(minutes: _pickupTimes[_pickupIndex].$3)),
    );
    _recordTxn(
      _cardIndex,
      'Order · $count item${count == 1 ? '' : 's'}',
      -total,
    );
    _stars.value += starsEarned;
    _cart.value = [];
    _activeOrder.value = order;
    _haptic(_Haptic.success);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: OrderStatusScreen(order: order, celebrate: true),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_isDark, _cart, _balances]),
    builder: (_, __) {
      final dark = _isDark.value;
      final items = _cart.value;
      final total = _cartTotal(items);
      final enough = _balances.value[_cardIndex] >= total;
      return PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: _sheetBg(),
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _StepIndicator(steps: _steps, current: _step, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      final incoming = child.key == ValueKey(_step);
                      final dx = (_forward == incoming) ? 0.25 : -0.25;
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(dx, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: switch (_step) {
                        0 => _buildReview(items, total),
                        1 => _buildPickup(),
                        _ => _buildPayment(total, enough),
                      },
                    ),
                  ),
                ),
                _buildBottomBar(total, enough && items.isNotEmpty),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
    child: Row(
      children: [
        IconButton(
          onPressed: _back,
          icon: Icon(Icons.arrow_back_ios_rounded, color: _sheetOn()),
        ),
        Expanded(
          child: Text(
            'Checkout',
            style: TextStyle(
              color: _sheetOn(),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          'Step ${_step + 1} of ${_steps.length}',
          style: TextStyle(color: _sheetSub(), fontSize: 12),
        ),
      ],
    ),
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        color: _sheetOn(),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  BoxDecoration _panel({bool active = false, Color? accent}) => BoxDecoration(
    borderRadius: BorderRadius.circular(18),
    color: active
        ? (accent ?? const Color(0xFF00A862)).withAlpha(28)
        : _sheetSub().withAlpha(14),
    border: Border.all(
      color: active
          ? (accent ?? const Color(0xFF00A862))
          : _sheetSub().withAlpha(35),
      width: active ? 1.8 : 1,
    ),
  );

  Widget _buildReview(List<CartItem> items, double total) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    children: [
      _heading('Your order'),
      for (var i = 0; i < items.length; i++)
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + i * 90),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - v)),
              child: child,
            ),
          ),
          child: _reviewRow(items[i]),
        ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _panel(),
        child: Column(
          children: [
            _summaryRow('Items', '${_cartCount(items)}'),
            const SizedBox(height: 6),
            _summaryRow('Stars you\'ll earn', '+${(total * 2).floor()} ★'),
            const SizedBox(height: 10),
            _summaryRow('Total', _formatPrice(total), bold: true),
          ],
        ),
      ),
    ],
  );

  Widget _reviewRow(CartItem item) {
    final summary = item.options.summary(item.drink);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _panel(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: item.drink.gradient),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              item.drink.asset,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.local_cafe, color: item.drink.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.drink.name,
                  style: TextStyle(
                    color: _sheetOn(),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  [item.size, if (summary.isNotEmpty) summary].join(' · '),
                  style: TextStyle(color: _sheetSub(), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${item.quantity} × ${_formatPrice(item.unitPrice)}',
            style: TextStyle(
              color: _sheetOn(),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickup() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    children: [
      _heading('Pickup store'),
      for (var i = 0; i < _stores.length; i++)
        GestureDetector(
          onTap: () => setState(() => _storeIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: _panel(active: i == _storeIndex),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00704A).withAlpha(40),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF00A862),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stores[i].name,
                        style: TextStyle(
                          color: _sheetOn(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_stores[i].address} · ${_stores[i].hours}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _sheetSub(), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_stores[i].distanceKm} km',
                  style: TextStyle(
                    color: _sheetOn(),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    i == _storeIndex
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(i == _storeIndex),
                    color: i == _storeIndex
                        ? const Color(0xFF00A862)
                        : _sheetSub(),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 14),
      _heading('Pickup time'),
      Row(
        children: [
          for (var i = 0; i < _pickupTimes.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _pickupIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: EdgeInsets.only(
                    right: i < _pickupTimes.length - 1 ? 10 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: _panel(active: i == _pickupIndex),
                  child: Column(
                    children: [
                      Icon(
                        i == 0 ? Icons.bolt_rounded : Icons.schedule_rounded,
                        size: 20,
                        color: i == _pickupIndex
                            ? const Color(0xFF00A862)
                            : _sheetSub(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pickupTimes[i].$1,
                        style: TextStyle(
                          color: _sheetOn(),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _pickupTimes[i].$2,
                        style: TextStyle(color: _sheetSub(), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _buildPayment(double total, bool enough) {
    final card = _cards[_cardIndex];
    final after = _balances.value[_cardIndex] - total;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _heading('Pay with'),
        _cardPicker(
          selected: _cardIndex,
          onChanged: (i) => setState(() => _cardIndex = i),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panel(),
          child: Column(
            children: [
              _summaryRow(
                'Pickup',
                '${_stores[_storeIndex].name} · ${_pickupTimes[_pickupIndex].$1}',
              ),
              const SizedBox(height: 6),
              _summaryRow('Balance after', enough ? _formatPrice(after) : '—'),
              const SizedBox(height: 10),
              _summaryRow('Total', _formatPrice(total), bold: true),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: enough
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFE53935).withAlpha(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFE53935),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Not enough balance on ${card.name}.',
                          style: TextStyle(color: _sheetOn(), fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _showAddMoneySheet(context, _cardIndex),
                        child: const Text('Add money'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(double total, bool canPay) {
    final last = _step == _steps.length - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _sheetSub().withAlpha(30))),
      ),
      child: _sheetButton(
        label: last
            ? (canPay ? 'Pay ${_formatPrice(total)}' : 'Insufficient balance')
            : 'Continue',
        color: const Color(0xFF00704A),
        onPressed: last ? (canPay ? _pay : null) : () => _goTo(_step + 1),
      ),
    );
  }
}
