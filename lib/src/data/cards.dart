part of '../../main.dart';

// ─── Card Data ────────────────────────────────────────────────────────────────

class CardData {
  final String name, tier, asset, balance, number;
  final List<Color> gradient;
  final Color accent, shimmer;

  const CardData({
    required this.name,
    required this.tier,
    required this.gradient,
    required this.asset,
    required this.balance,
    required this.number,
    required this.accent,
    required this.shimmer,
  });
}

final List<CardData> _cards = [
  CardData(
    name: 'Classic Green',
    tier: 'GREEN',
    gradient: [const Color(0xFF00704A), const Color(0xFF1E3932)],
    asset: 'images/cupGreen.png',
    balance: r'$24.50',
    number: '6042 .... .... 3841',
    accent: const Color(0xFFCBA258),
    shimmer: const Color(0xFF66BB6A),
  ),
  CardData(
    name: 'Mocha Reserve',
    tier: 'MOCHA',
    gradient: [const Color(0xFF6F4E37), const Color(0xFF2C1810)],
    asset: 'images/cupChoco.png',
    balance: r'$54.25',
    number: '6042 .... .... 7215',
    accent: const Color(0xFFFFD54F),
    shimmer: const Color(0xFFA1887F),
  ),
  CardData(
    name: 'Gold Reserve',
    tier: 'GOLD',
    gradient: [const Color(0xFFB8860B), const Color(0xFF5D4037)],
    asset: 'images/cupGreen2.png',
    balance: r'$108.75',
    number: '6042 .... .... 9963',
    accent: const Color(0xFFFFF176),
    shimmer: const Color(0xFFFFD700),
  ),
  CardData(
    name: 'Berry Bliss',
    tier: 'PINK',
    gradient: [const Color(0xFFAD1457), const Color(0xFF4A148C)],
    asset: 'images/cupPink.png',
    balance: r'$38.00',
    number: '6042 .... .... 5512',
    accent: const Color(0xFFF48FB1),
    shimmer: const Color(0xFFCE93D8),
  ),
  CardData(
    name: 'Ocean Breeze',
    tier: 'BLUE',
    gradient: [const Color(0xFF0277BD), const Color(0xFF01579B)],
    asset: 'images/cup_2.png',
    balance: r'$62.10',
    number: '6042 .... .... 8834',
    accent: const Color(0xFF81D4FA),
    shimmer: const Color(0xFF4FC3F7),
  ),
  CardData(
    name: 'Autumn Ember',
    tier: 'EMBER',
    gradient: [const Color(0xFFBF360C), const Color(0xFF4E342E)],
    asset: 'images/cup.png',
    balance: r'$91.45',
    number: '6042 .... .... 2277',
    accent: const Color(0xFFFFAB40),
    shimmer: const Color(0xFFFF7043),
  ),
];
