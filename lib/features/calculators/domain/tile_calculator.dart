import 'dart:math';
import 'business_calculator.dart';

class TileCalculator implements BusinessCalculator {
  @override
  String get type => 'tile';

  @override
  String get label => 'Carrelage';

  @override
  String get icon => 'grid_on';

  @override
  CalculatorResult calculate({
    required Map<String, dynamic> inputs,
    double? unitPrice,
  }) {
    // Inputs
    final double area = inputs['area'] is num
        ? (inputs['area'] as num).toDouble()
        : 0.0;
    
    final double tileLengthCm = inputs['tileLengthCm'] is num
        ? (inputs['tileLengthCm'] as num).toDouble()
        : 60.0;

    final double tileWidthCm = inputs['tileWidthCm'] is num
        ? (inputs['tileWidthCm'] as num).toDouble()
        : 60.0;

    final double wastePercent = inputs['wastePercent'] is num
        ? (inputs['wastePercent'] as num).toDouble()
        : 10.0;

    final int piecesPerBox = inputs['piecesPerBox'] is int
        ? inputs['piecesPerBox'] as int
        : 1;

    // Calculate Tiling
    final areaWithWaste = area * (1 + (wastePercent / 100));
    final tileAreaM2 = (tileLengthCm * tileWidthCm) / 10000.0;

    // Tiles count
    final int tilesCount = tileAreaM2 > 0 ? (areaWithWaste / tileAreaM2).ceil() : 0;
    
    // Boxes count
    final int boxesCount = piecesPerBox > 0 ? (tilesCount / piecesPerBox).ceil() : 0;

    // Pricing estimation (unitPrice could be price per box or price per unit)
    final double price = unitPrice != null ? (boxesCount * unitPrice) : 0.0;

    return CalculatorResult(
      metrics: [
        CalculatorMetric(label: 'Surface brute', value: area.toStringAsFixed(2), unit: 'm²'),
        CalculatorMetric(label: 'Marge perte', value: wastePercent.toStringAsFixed(0), unit: '%'),
        CalculatorMetric(label: 'Dimension carreau', value: '${tileLengthCm.toStringAsFixed(0)}x${tileWidthCm.toStringAsFixed(0)}', unit: 'cm'),
        CalculatorMetric(label: 'Nombre de carreaux', value: tilesCount.toString(), unit: 'pcs'),
        CalculatorMetric(label: 'Nombre de cartons', value: boxesCount.toString(), unit: 'ctn'),
      ],
      estimatedPrice: price,
      recommendedQuantity: boxesCount.toDouble(),
    );
  }
}
