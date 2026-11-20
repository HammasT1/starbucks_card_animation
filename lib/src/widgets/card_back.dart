part of '../../main.dart';

// ─── Card Back (QR) ───────────────────────────────────────────────────────────

String _cardQrData(CardData card, [int refresh = 0]) =>
    'SBUX-CARD|${card.tier}|${card.number}|$refresh';

Widget _styledQr(CardData card, double size, [int refresh = 0]) => QrImageView(
  data: _cardQrData(card, refresh),
  version: QrVersions.auto,
  size: size,
  padding: EdgeInsets.zero,
  backgroundColor: Colors.white,
  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.circle, color: card.gradient[1]),
  dataModuleStyle: QrDataModuleStyle(
    dataModuleShape: QrDataModuleShape.circle,
    color: card.gradient[1],
  ),
);

class CardBack extends StatelessWidget {
  final CardData card;

  const CardBack({super.key, required this.card});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: card.gradient,
      ),
      boxShadow: [
        BoxShadow(
          color: card.gradient[0].withAlpha(160),
          blurRadius: 36,
          spreadRadius: 6,
          offset: const Offset(0, 18),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          const SizedBox(height: 22),
          // Magnetic stripe
          Container(height: 34, color: Colors.black.withAlpha(150)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: LayoutBuilder(
                builder: (_, box) {
                  final qr = min(box.maxHeight - 16, 130.0).clamp(60.0, 130.0);
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _styledQr(card, qr),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Scan to pay',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                card.number,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(180),
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 14,
                                  color: card.accent,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Tap to flip back',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: card.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
