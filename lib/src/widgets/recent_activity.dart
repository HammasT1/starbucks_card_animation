part of '../../main.dart';

// ─── Recent Activity ──────────────────────────────────────────────────────────

class RecentActivity extends StatelessWidget {
  final int cardIndex;
  final bool dark;

  const RecentActivity({
    super.key,
    required this.cardIndex,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final card = _cards[cardIndex];
    final txns = _transactions.value
        .where((t) => t.cardIndex == cardIndex)
        .take(3)
        .toList();
    final onBg = dark ? Colors.white : const Color(0xFF1B1B1B);
    final sub = dark ? Colors.white.withAlpha(140) : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: _glassBox(dark),
      child: txns.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('No activity yet', style: TextStyle(color: sub)),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < txns.length; i++)
                  TweenAnimationBuilder<double>(
                    key: ValueKey(
                      '$cardIndex-${txns[i].time.microsecondsSinceEpoch}',
                    ),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 350 + i * 120),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(24 * (1 - v), 0),
                        child: child,
                      ),
                    ),
                    child: _activityRow(
                      txns[i],
                      card,
                      onBg,
                      sub,
                      last: i == txns.length - 1,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _activityRow(
    WalletTxn t,
    CardData card,
    Color onBg,
    Color sub, {
    required bool last,
  }) {
    final topUp = t.amount > 0;
    const green = Color(0xFF43A047);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: sub.withAlpha(40))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (topUp ? green : card.accent).withAlpha(40),
            ),
            child: Icon(
              topUp ? Icons.add_card_rounded : Icons.local_cafe_rounded,
              size: 16,
              color: topUp ? green : card.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onBg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTxnTime(t.time),
                  style: TextStyle(color: sub, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${topUp ? '+' : '−'}${_formatPrice(t.amount.abs())}',
            style: TextStyle(
              color: topUp ? green : onBg,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
