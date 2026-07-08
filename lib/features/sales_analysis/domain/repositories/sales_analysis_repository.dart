import '../entities/sales_analysis_entities.dart';

abstract class SalesAnalysisRepository {
  /// Invalide le cache API (changement de période, refresh).
  void clearRemoteCache();

  Future<List<ProductSalesSummary>> listProductSummaries({
    required int shopId,
    required SalesAnalysisQuery query,
  });

  Future<List<ProductSalesSummary>> listProductSummariesByCategory({
    required int shopId,
    required SalesAnalysisQuery query,
    required int? categoryId,
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

  Future<List<CategorySalesSummary>> listCategorySummaries({
    required int shopId,
    required SalesAnalysisQuery query,
  });

  Future<MarginSummary> loadMarginSummary({
    required int shopId,
    required SalesAnalysisQuery query,
  });

  Future<List<PriceDeviationLine>> listPriceDeviations({
    required int shopId,
    required SalesAnalysisQuery query,
  });

  Future<SalesTrendSummary> loadSalesTrends({
    required int shopId,
    required SalesAnalysisQuery query,
  });
}
