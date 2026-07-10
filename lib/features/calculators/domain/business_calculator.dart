abstract class BusinessCalculator {
  String get type;
  String get label;
  String get icon;

  CalculatorResult calculate({
    required Map<String, dynamic> inputs,
    double? unitPrice,
  });
}

class CalculatorMetric {
  const CalculatorMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  String toString() => '$label: $value $unit';
}

class CalculatorResult {
  const CalculatorResult({
    required this.metrics,
    this.estimatedPrice = 0.0,
    this.recommendedQuantity = 0.0,
  });

  final List<CalculatorMetric> metrics;
  final double estimatedPrice;
  final double recommendedQuantity; // e.g. number of boxes, buckets, bags
}
