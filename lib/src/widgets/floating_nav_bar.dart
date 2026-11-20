part of '../../main.dart';

class FloatingNavBar extends StatelessWidget {
  final int index;
  final int cartCount;
  final bool dark;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.index,
    required this.cartCount,
    required this.dark,
    required this.onTap,
  });

  static const _labels = ['My Cards', 'Menu', 'Cart'];

  @override
  Widget build(BuildContext context) {
    final inactive = dark ? Colors.white60 : Colors.black54;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(33),
            color: dark
                ? const Color(0xFF13241D).withAlpha(240)
                : Colors.white.withAlpha(245),
            border: Border.all(
              color: dark
                  ? Colors.white.withAlpha(25)
                  : Colors.black.withAlpha(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(dark ? 120 : 40),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (_, box) {
              final w = box.maxWidth / _labels.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    left: index * w + 6,
                    top: 6,
                    bottom: 6,
                    width: w - 12,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(27),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00A862), Color(0xFF00704A)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00704A).withAlpha(90),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _labels.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == index,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTap(i),
                              child: _item(i, i == index, inactive),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _item(int i, bool active, Color inactive) {
    final color = active ? Colors.white : inactive;
    final icon = switch (i) {
      0 => const Icon(Icons.credit_card_rounded),
      1 => const Icon(Icons.local_cafe_rounded),
      _ => CartTabIcon(key: _cartTabKey, count: cartCount),
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: active ? 1.1 : 1,
          duration: const Duration(milliseconds: 250),
          child: IconTheme(
            data: IconThemeData(color: color, size: 22),
            child: icon,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            fontFamily: 'Poppins',
            color: color,
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(_labels[i], maxLines: 1),
        ),
      ],
    );
  }
}
