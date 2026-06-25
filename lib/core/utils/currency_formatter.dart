String formatFcfa(int amount) {
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
  return negative ? '-$formatted FCFA' : '$formatted FCFA';
}
