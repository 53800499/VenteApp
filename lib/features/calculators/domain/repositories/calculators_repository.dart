import '../entities/calculator_entities.dart';

abstract class CalculatorsRepository {
  Future<bool> isModuleEnabled({required int shopId});
  Future<void> toggleModule({required int shopId, required bool enabled});
  Future<List<CalculatorProductData>> getProductConfigs({required int shopId});
  Future<CalculatorProductData?> getProductConfig({required int shopId, required int productId});
  Future<void> saveProductConfig({required CalculatorProductData config});
  Future<List<CalculatorHistoryEntry>> getHistory({required int shopId});
  Future<CalculatorHistoryEntry> saveCalculation({required CalculatorHistoryEntry entry});
  Future<void> syncFromRemote({required int shopId});
}
