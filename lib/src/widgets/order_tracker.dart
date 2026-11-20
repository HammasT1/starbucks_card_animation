part of '../../main.dart';

class OrderTracker extends StatelessWidget {
  final PlacedOrder order;

  const OrderTracker({super.key, required this.order});

  @override
  Widget build(BuildContext context) => _Ticker(
    builder: (_, now) {
      const green = Color(0xFF00A862);
      final stage = order.stageAt(now);
      final progress = order.progressAt(now);
      final remaining = order.readyAt.difference(now);
      const labels = ['Received', 'Preparing', 'Ready'];
      const icons = [
        Icons.receipt_long_rounded,
        Icons.coffee_maker_rounded,
        Icons.shopping_bag_rounded,
      ];
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [green.withAlpha(40), green.withAlpha(12)],
          ),
          border: Border.all(color: green.withAlpha(90)),
        ),
        child: Column(
          children: [
            Text(
              stage == 2 ? 'Ready for pickup!' : 'Ready in',
              style: TextStyle(color: _sheetSub(), fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              stage == 2 ? order.store.name : _formatCountdown(remaining),
              key: const ValueKey('order-countdown'),
              style: TextStyle(
                color: _sheetOn(),
                fontSize: stage == 2 ? 22 : 40,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _stageDot(icons[i], labels[i], i, stage),
                  if (i < 2)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: i == 0
                                ? (stage >= 1 ? 1 : progress / 0.15)
                                : (stage >= 2
                                      ? 1
                                      : ((progress - 0.15) / 0.85).clamp(
                                          0.0,
                                          1.0,
                                        )),
                            color: green,
                            backgroundColor: _sheetSub().withAlpha(40),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _stageDot(IconData icon, String label, int index, int stage) {
    const green = Color(0xFF00A862);
    final done = index < stage || stage == 2;
    final current = index == stage && stage != 2;
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          _Pulse(
            active: current,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || current ? green : _sheetSub().withAlpha(40),
              ),
              child: Icon(
                done && !current ? Icons.check_rounded : icon,
                color: done || current ? Colors.white : _sheetSub(),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: done || current ? _sheetOn() : _sheetSub(),
              fontSize: 11,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
