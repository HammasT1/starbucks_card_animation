part of '../../main.dart';

double _parsePrice(String price) {
  final normalized = price.replaceAll(r'\\$', '').replaceAll(r'$', '');
  return double.tryParse(normalized.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

String _formatPrice(double value) => '\$${value.toStringAsFixed(2)}';
