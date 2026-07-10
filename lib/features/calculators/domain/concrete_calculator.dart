import 'business_calculator.dart';

class ConcreteCalculator implements BusinessCalculator {
  @override
  String get type => 'concrete';

  @override
  String get label => 'Béton & Mortier';

  @override
  String get icon => 'layers';

  @override
  CalculatorResult calculate({
    required Map<String, dynamic> inputs,
    double? unitPrice,
  }) {
    // Inputs
    final double volume = inputs['volume'] is num
        ? (inputs['volume'] as num).toDouble()
        : 0.0;

    final double cementDosage = inputs['cementDosage'] is num
        ? (inputs['cementDosage'] as num).toDouble()
        : 350.0; // default 350kg/m³ for structural concrete

    final double bagWeight = inputs['bagWeight'] is num
        ? (inputs['bagWeight'] as num).toDouble()
        : 50.0; // default 50kg bags (standard in Benin)

    final double sandProportion = inputs['sandProportion'] is num
        ? (inputs['sandProportion'] as num).toDouble()
        : 400.0; // default 400 L/m³

    final double gravelProportion = inputs['gravelProportion'] is num
        ? (inputs['gravelProportion'] as num).toDouble()
        : 800.0; // default 800 L/m³

    final double wastePercent = inputs['wastePercent'] is num
        ? (inputs['wastePercent'] as num).toDouble()
        : 5.0; // default 5% waste

    // Calculate quantities
    final volumeWithWaste = volume * (1 + (wastePercent / 100));

    final totalCementKg = volumeWithWaste * cementDosage;
    final int cementBags = bagWeight > 0 ? (totalCementKg / bagWeight).ceil() : 0;

    final double totalSandM3 = (volumeWithWaste * sandProportion) / 1000.0; // L to m³
    final double totalGravelM3 = (volumeWithWaste * gravelProportion) / 1000.0; // L to m³

    // Price is estimated on the primary recommended product (cement bags)
    final double price = unitPrice != null ? (cementBags * unitPrice) : 0.0;

    return CalculatorResult(
      metrics: [
        CalculatorMetric(label: 'Volume de béton', value: volume.toStringAsFixed(2), unit: 'm³'),
        CalculatorMetric(label: 'Dosage ciment', value: cementDosage.toStringAsFixed(0), unit: 'kg/m³'),
        CalculatorMetric(label: 'Sacs de ciment (50kg)', value: cementBags.toString(), unit: 'sacs'),
        CalculatorMetric(label: 'Volume de sable', value: totalSandM3.toStringAsFixed(2), unit: 'm³'),
        CalculatorMetric(label: 'Volume de gravier', value: totalGravelM3.toStringAsFixed(2), unit: 'm³'),
      ],
      estimatedPrice: price,
      recommendedQuantity: cementBags.toDouble(),
    );
  }
}
