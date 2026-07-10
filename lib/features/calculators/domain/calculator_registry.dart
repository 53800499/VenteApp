import 'business_calculator.dart';
import 'tile_calculator.dart';
import 'paint_calculator.dart';
import 'concrete_calculator.dart';

class CalculatorRegistry {
  CalculatorRegistry._();

  static final CalculatorRegistry instance = CalculatorRegistry._();

  final Map<String, BusinessCalculator Function()> _registry = {
    'tile': () => TileCalculator(),
    'paint': () => PaintCalculator(),
    'concrete': () => ConcreteCalculator(),
  };

  List<BusinessCalculator> getAvailableCalculators() {
    return _registry.values.map((factory) => factory()).toList();
  }

  BusinessCalculator? getCalculator(String type) {
    final factory = _registry[type];
    return factory != null ? factory() : null;
  }
}
