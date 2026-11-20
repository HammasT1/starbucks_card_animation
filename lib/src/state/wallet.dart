part of '../../main.dart';

// ─── Wallet State ─────────────────────────────────────────────────────────────

class WalletTxn {
  final int cardIndex;
  final String title;
  final double amount; // positive = top-up, negative = purchase
  final DateTime time;

  const WalletTxn({
    required this.cardIndex,
    required this.title,
    required this.amount,
    required this.time,
  });
}

final ValueNotifier<int> _activeCard = ValueNotifier<int>(0);
final ValueNotifier<int> _stars = ValueNotifier<int>(315);
final ValueNotifier<List<double>> _balances = ValueNotifier<List<double>>(
  _cards.map((c) => _parsePrice(c.balance)).toList(),
);
final ValueNotifier<List<WalletTxn>> _transactions =
    ValueNotifier<List<WalletTxn>>(_seedTransactions());

List<WalletTxn> _seedTransactions() {
  final now = DateTime.now();
  final seed = <WalletTxn>[];
  for (var i = 0; i < _cards.length; i++) {
    seed.addAll([
      WalletTxn(
        cardIndex: i,
        title: 'Caramel Macchiato · Grande',
        amount: -5.45,
        time: now.subtract(Duration(days: 1 + i, hours: 3)),
      ),
      WalletTxn(
        cardIndex: i,
        title: 'Added money',
        amount: 25,
        time: now.subtract(Duration(days: 4 + i, hours: 6)),
      ),
      WalletTxn(
        cardIndex: i,
        title: 'Cold Brew · Venti',
        amount: -4.75,
        time: now.subtract(Duration(days: 7 + i, hours: 1)),
      ),
    ]);
  }
  seed.sort((a, b) => b.time.compareTo(a.time));
  return seed;
}

void _recordTxn(int cardIndex, String title, double amount) {
  final balances = List<double>.from(_balances.value);
  balances[cardIndex] = balances[cardIndex] + amount;
  _balances.value = balances;
  _transactions.value = [
    WalletTxn(
      cardIndex: cardIndex,
      title: title,
      amount: amount,
      time: DateTime.now(),
    ),
    ..._transactions.value,
  ];
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatTxnTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${_monthNames[t.month - 1]} ${t.day} · $hh:$mm';
}
