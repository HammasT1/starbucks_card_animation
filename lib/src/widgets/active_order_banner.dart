part of '../../main.dart';

// ─── Active Order Banner ──────────────────────────────────────────────────────

class ActiveOrderBanner extends StatelessWidget {
  final PlacedOrder order;
  final bool dark;

  const ActiveOrderBanner({super.key, required this.order, required this.dark});

  @override
  Widget build(BuildContext context) => _Ticker(
    builder: (_, now) {
      const green = Color(0xFF00A862);
      final stage = order.stageAt(now);
      final onBg = dark ? Colors.white : const Color(0xFF15231A);
      final sub = dark ? Colors.white70 : Colors.black54;
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderStatusScreen(order: order),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [green.withAlpha(60), green.withAlpha(20)],
            ),
            border: Border.all(color: green.withAlpha(110)),
          ),
          child: Row(
            children: [
              _Pulse(
                active: stage < 2,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: green,
                  ),
                  child: Icon(
                    stage == 2
                        ? Icons.shopping_bag_rounded
                        : Icons.coffee_maker_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.number} · ${['Received', 'Preparing', 'Ready'][stage]}',
                      style: TextStyle(
                        color: onBg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      stage == 2
                          ? 'Ready at ${order.store.name}'
                          : 'Ready in ${_formatCountdown(order.readyAt.difference(now))} · ${order.store.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sub, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: order.progressAt(now),
                        minHeight: 3,
                        color: green,
                        backgroundColor: sub.withAlpha(40),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => _activeOrder.value = null,
                icon: Icon(Icons.close_rounded, color: sub, size: 18),
              ),
            ],
          ),
        ),
      );
    },
  );
}
