import '../entities/sales_analysis_entities.dart';

abstract class SalesAnalysisRepository {
  Future<List<ProductSalesSummary>> listProductSummaries({
    required int shopId,
    required SalesAnalysisQuery query,
  });

  Future<ProductSalesDetail> loadProductDetail({
    required int shopId,
    required SalesAnalysisQuery query,
    int? productId,
    required String productName,
  });

  Future<List<EmployeePricePerformance>> listEmployeePerformance({
    required int shopId,
    required SalesAnalysisQuery query,
  });

  Future<List<CustomerSalesInsight>> listCustomerInsights({
    required int shopId,
    required SalesAnalysisQuery query,
  });

  Future<List<CustomerProductPriceHabit>> listCustomerPriceHabits({
    required int shopId,
    required int customerId,
  });

  Future<ProductSoldPriceRange> soldPriceRangeForProduct({
    required int shopId,
    required int productId,
  });
}
