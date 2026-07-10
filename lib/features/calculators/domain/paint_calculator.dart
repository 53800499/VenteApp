import 'business_calculator.dart';

class PaintCalculator implements BusinessCalculator {
  @override
  String get type => 'paint';

  @override
  String get label => 'Peinture';

  @override
  String get icon => 'format_paint';

  @override
  CalculatorResult calculate({
    required Map<String, dynamic> inputs,
    double? unitPrice,
  }) {
    // Inputs
    final double area = inputs['area'] is num
        ? (inputs['area'] as num).toDouble()
        : 0.0;

    final double coveragePerLiter = inputs['coveragePerLiter'] is num
        ? (inputs['coveragePerLiter'] as num).toDouble()
        : 10.0; // default: 10 m² per liter

    final int coatsCount = inputs['coatsCount'] is int
        ? inputs['coatsCount'] as int
        : 2; // default: 2 coats

    final double bucketVolume = inputs['bucketVolume'] is num
        ? (inputs['bucketVolume'] as num).toDouble()
        : 15.0; // default: 15L bucket

    final double wastePercent = inputs['wastePercent'] is num
        ? (inputs['wastePercent'] as num).toDouble()
        : 5.0; // default: 5% waste

    // Calculate paint
    final totalAreaToPaint = area * coatsCount;
    final areaWithWaste = totalAreaToPaint * (1 + (wastePercent / 100));

    final double totalLiters = coveragePerLiter > 0 ? (areaWithWaste / coveragePerLiter) : 0.0;
    final int bucketsCount = bucketVolume > 0 ? (totalLiters / bucketVolume).ceil() : 0;

    final double price = unitPrice != null ? (bucketsCount * unitPrice) : 0.0;

    return CalculatorResult(
      metrics: [
        CalculatorMetric(label: 'Surface murale', value: area.toStringAsFixed(2), unit: 'm²'),
        CalculatorMetric(label: 'Nombre de couches', value: coatsCount.toString(), unit: ''),
        CalculatorMetric(label: 'Rendement estimé', value: coveragePerLiter.toStringAsFixed(0), unit: 'm²/L'),
        CalculatorMetric(label: 'Volume de peinture requis', value: totalLiters.toStringAsFixed(1), unit: 'L'),
        CalculatorMetric(label: 'Nombre de pots/fûts', value: bucketsCount.toString(), unit: 'u'),
      ],
      estimatedPrice: price,
      recommendedQuantity: bucketsCount.toDouble(),
    );
  }
}
