class FxRateFraction {
  const FxRateFraction({
    required this.numerator,
    required this.denominator,
  });

  final int numerator;
  final int denominator;
}

class FxCalculationService {
  const FxCalculationService();

  int computeForeignFromFcfa(int fcfaAmount, FxRateFraction sellRate) {
    return (fcfaAmount * sellRate.denominator) ~/ sellRate.numerator;
  }

  int computeFcfaFromForeign(int foreignAmount, FxRateFraction buyRate) {
    return (foreignAmount * buyRate.numerator) ~/ buyRate.denominator;
  }

  int computeSellMarginFcfa(
    int fcfaReceived,
    int foreignDelivered,
    FxRateFraction buyRate,
  ) {
    final costAtBuyRate = computeFcfaFromForeign(foreignDelivered, buyRate);
    return fcfaReceived - costAtBuyRate;
  }

  int computeBuyMarginFcfa(
    int foreignReceived,
    int fcfaPaid,
    FxRateFraction sellRate,
  ) {
    final revenueAtSellRate = computeFcfaFromForeign(foreignReceived, sellRate);
    return revenueAtSellRate - fcfaPaid;
  }

  String formatRateLabel(String quoteCurrency, FxRateFraction rate) {
    return '${_formatInt(rate.denominator)} $quoteCurrency = ${_formatInt(rate.numerator)} FCFA';
  }

  String _formatInt(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final position = digits.length - i;
      buffer.write(digits[i]);
      if (position > 1 && position % 3 == 1) buffer.write(' ');
    }
    return buffer.toString();
  }
}
