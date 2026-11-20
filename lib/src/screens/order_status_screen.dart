part of '../../main.dart';

// ─── Order Status ─────────────────────────────────────────────────────────────

class OrderStatusScreen extends StatefulWidget {
  final PlacedOrder order;

  /// Plays the cup-filling celebration first (right after paying).
  final bool celebrate;

  const OrderStatusScreen({
    super.key,
    required this.order,
    this.celebrate = false,
  });

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late final Animation<double> _fill = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.65, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _check = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 0.8, curve: Curves.elasticOut),
  );
  late final Animation<double> _details = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    if (widget.celebrate) {
      _intro.forward();
    } else {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    const coffee = Color(0xFF9C6B3F);
    const green = Color(0xFF00A862);
    return Scaffold(
      backgroundColor: _sheetBg(),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _wave]),
          builder: (_, __) => Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: _sheetOn()),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 180,
                        height: 210,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: CupPainter(
                                  fill: 0.82 * _fill.value,
                                  wavePhase: _wave.value,
                                  liquid: coffee,
                                  outline: green,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              bottom: 10,
                              child: Transform.scale(
                                scale: _check.value,
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: green,
                                    border: Border.all(
                                      color: _sheetBg(),
                                      width: 4,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: _details.value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - _details.value)),
                          child: _buildDetails(order),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: _details.value,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: _sheetButton(
                    label: 'Done',
                    color: const Color(0xFF00704A),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(PlacedOrder order) => Column(
    children: [
      Text(
        widget.celebrate ? 'Order placed!' : 'Order #${order.number}',
        style: TextStyle(
          color: _sheetOn(),
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        widget.celebrate
            ? 'Order #${order.number} · You earned ${order.starsEarned} ★'
            : 'Pickup at ${order.store.name}',
        style: TextStyle(color: _sheetSub(), fontSize: 13),
      ),
      const SizedBox(height: 22),
      OrderTracker(order: order),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _sheetSub().withAlpha(14),
          border: Border.all(color: _sheetSub().withAlpha(35)),
        ),
        child: Column(
          children: [
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _summaryRow(
                  '${item.quantity}× ${item.drink.name} (${item.size})',
                  _formatPrice(item.totalPrice),
                ),
              ),
            const SizedBox(height: 4),
            _summaryRow('Paid', _formatPrice(order.total), bold: true),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}
