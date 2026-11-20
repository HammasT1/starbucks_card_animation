part of '../../main.dart';

// ─── Bottom Sheets ────────────────────────────────────────────────────────────

Color _sheetBg() =>
    _isDark.value ? const Color(0xFF14231D) : const Color(0xFFFAFDFB);
Color _sheetOn() => _isDark.value ? Colors.white : const Color(0xFF15231A);
Color _sheetSub() => _isDark.value ? Colors.white60 : Colors.black54;

Future<T?> _showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _sheetBg(),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _sheetSub().withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: _sheetOn(),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: _sheetSub(), fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            builder(sheetContext),
          ],
        ),
      ),
    ),
  );
}

Widget _sheetButton({
  required String label,
  required Color color,
  required VoidCallback? onPressed,
  Color foreground = Colors.white,
}) => SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: foreground,
      disabledBackgroundColor: _sheetSub().withAlpha(40),
      disabledForegroundColor: _sheetSub(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  ),
);

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
}

Future<void> _showAddMoneySheet(BuildContext context, int cardIndex) {
  final card = _cards[cardIndex];
  const amounts = [10.0, 25.0, 50.0, 100.0];
  var selected = 25.0;
  return _showAppSheet(
    context,
    title: 'Add Money',
    subtitle:
        '${card.name} · balance ${_formatPrice(_balances.value[cardIndex])}',
    builder: (sheetContext) => StatefulBuilder(
      builder: (_, setSheet) => Column(
        children: [
          Row(
            children: amounts.map((a) {
              final active = a == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setSheet(() => selected = a),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: active
                          ? LinearGradient(colors: card.gradient)
                          : null,
                      color: active ? null : _sheetSub().withAlpha(20),
                      border: Border.all(
                        color: active ? card.accent : _sheetSub().withAlpha(50),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '\$${a.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: active ? Colors.white : _sheetOn(),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          _sheetButton(
            label: 'Add ${_formatPrice(selected)} to ${card.name}',
            color: card.gradient[0],
            onPressed: () {
              _recordTxn(cardIndex, 'Added money', selected);
              _haptic(_Haptic.medium);
              Navigator.of(sheetContext).pop();
              _showSnack(
                context,
                '${_formatPrice(selected)} added to ${card.name}',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _showPaySheet(BuildContext context, int cardIndex) =>
    _showAppSheet(
      context,
      title: 'Scan to Pay',
      subtitle: 'Show this code to the barista at the register',
      builder: (_) => PaySheetBody(cardIndex: cardIndex),
    );

Future<void> _showHistorySheet(BuildContext context, int cardIndex) {
  final card = _cards[cardIndex];
  return _showAppSheet(
    context,
    title: 'History',
    subtitle: card.name,
    builder: (_) => ValueListenableBuilder<List<WalletTxn>>(
      valueListenable: _transactions,
      builder: (_, all, __) {
        final txns = all.where((t) => t.cardIndex == cardIndex).toList();
        if (txns.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(color: _sheetSub()),
              ),
            ),
          );
        }
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: txns.length,
            separatorBuilder: (_, __) =>
                Divider(color: _sheetSub().withAlpha(30), height: 1),
            itemBuilder: (_, i) {
              final t = txns[i];
              final topUp = t.amount > 0;
              final color = topUp ? const Color(0xFF2E7D32) : _sheetOn();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (topUp ? const Color(0xFF2E7D32) : card.accent)
                            .withAlpha(35),
                      ),
                      child: Icon(
                        topUp
                            ? Icons.add_card_rounded
                            : Icons.local_cafe_rounded,
                        size: 19,
                        color: topUp ? const Color(0xFF43A047) : card.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            style: TextStyle(
                              color: _sheetOn(),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatTxnTime(t.time),
                            style: TextStyle(color: _sheetSub(), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${topUp ? '+' : '−'}${_formatPrice(t.amount.abs())}',
                      style: TextStyle(
                        color: topUp ? const Color(0xFF43A047) : color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

Widget _cardPicker({
  required int selected,
  required ValueChanged<int> onChanged,
}) => SizedBox(
  height: 108,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: _cards.length,
    separatorBuilder: (_, __) => const SizedBox(width: 10),
    itemBuilder: (_, i) {
      final c = _cards[i];
      final active = i == selected;
      return GestureDetector(
        key: ValueKey('pay-card-$i'),
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: c.gradient),
            border: Border.all(
              color: active ? c.accent : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: c.gradient[0].withAlpha(120),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (active)
                    Icon(Icons.check_circle_rounded, color: c.accent, size: 16),
                ],
              ),
              Text(
                _formatPrice(_balances.value[i]),
                style: TextStyle(
                  color: c.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);

Widget _summaryRow(String label, String value, {bool bold = false}) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: bold ? _sheetOn() : _sheetSub(),
          fontSize: bold ? 18 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
    ),
    const SizedBox(width: 12),
    Text(
      value,
      style: TextStyle(
        color: bold ? _ink(const Color(0xFFCBA258), _isDark.value) : _sheetOn(),
        fontSize: bold ? 22 : 13,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
      ),
    ),
  ],
);
