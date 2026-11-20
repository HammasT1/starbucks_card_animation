part of '../../main.dart';

// ─── Pay Sheet ────────────────────────────────────────────────────────────────

const int _payCodeSeconds = 60;

class PaySheetBody extends StatefulWidget {
  final int cardIndex;

  const PaySheetBody({super.key, required this.cardIndex});

  @override
  State<PaySheetBody> createState() => _PaySheetBodyState();
}

class _PaySheetBodyState extends State<PaySheetBody> {
  Timer? _timer;
  int _secondsLeft = _payCodeSeconds;
  int _refresh = 0;

  @override
  void initState() {
    super.initState();
    _setBrightness(boost: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsLeft -= 1;
        if (_secondsLeft <= 0) {
          _secondsLeft = _payCodeSeconds;
          _refresh += 1;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _setBrightness(boost: false);
    super.dispose();
  }

  /// Not every platform supports brightness control (e.g. Linux, web).
  Future<void> _setBrightness({required bool boost}) async {
    try {
      if (boost) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[widget.cardIndex];
    final mm = _secondsLeft ~/ 60;
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: card.gradient[0].withAlpha(90),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(_refresh),
                child: _styledQr(card, 200, _refresh),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.wb_sunny_rounded, size: 14, color: _sheetSub()),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Code refreshes in $mm:$ss',
                style: TextStyle(color: _sheetSub(), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _secondsLeft / _payCodeSeconds),
            duration: const Duration(milliseconds: 950),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              color: card.gradient[0],
              backgroundColor: _sheetSub().withAlpha(30),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: card.gradient),
          ),
          child: Row(
            children: [
              const Icon(Icons.credit_card_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      card.number,
                      style: TextStyle(
                        color: Colors.white.withAlpha(170),
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatPrice(_balances.value[widget.cardIndex]),
                style: TextStyle(
                  color: card.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
