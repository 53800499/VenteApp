String formatFcfa(int amount) {
  return formatAmount(amount, 'XOF');
}

String formatAmount(int amount, String currencyCode) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final position = digits.length - i;
    buffer.write(digits[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write(' ');
    }
  }
  final formatted = buffer.toString();
  final suffix = _currencySuffix(currencyCode);
  return negative ? '-$formatted $suffix' : '$formatted $suffix';
}

String _currencySuffix(String currencyCode) => switch (currencyCode) {
      'XOF' => 'FCFA',
      'NGN' => 'NGN',
      'GHS' => 'GHS',
      'USD' => 'USD',
      'EUR' => 'EUR',
      _ => currencyCode,
    };
