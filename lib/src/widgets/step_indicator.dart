part of '../../main.dart';

class _StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int current;
  final bool dark;

  const _StepIndicator({
    required this.steps,
    required this.current,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF00A862);
    final idle = dark ? Colors.white24 : Colors.black12;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  // No overshooting curve: it would push the fading shadow's
                  // blur below zero.
                  curve: Curves.easeOutCubic,
                  width: i == current ? 30 : 24,
                  height: i == current ? 30 : 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= current ? green : idle,
                    boxShadow: i == current
                        ? [
                            BoxShadow(
                              color: green.withAlpha(90),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: i < current
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i <= current ? Colors.white : _sheetSub(),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      steps[i],
                      maxLines: 1,
                      style: TextStyle(
                        color: i <= current ? _sheetOn() : _sheetSub(),
                        fontSize: 11,
                        fontWeight: i == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    // A fixed height: the fill would otherwise size itself
                    // to the unbounded height it's given.
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          Container(color: idle),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.centerLeft,
                            widthFactor: i < current ? 1 : 0,
                            heightFactor: 1,
                            child: Container(color: green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
