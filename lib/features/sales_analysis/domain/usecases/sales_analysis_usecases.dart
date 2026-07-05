import '../entities/sales_analysis_entities.dart';
import '../repositories/sales_analysis_repository.dart';

class ListProductSalesAnalysis {
  const ListProductSalesAnalysis(this._repository);

  final SalesAnalysisRepository _repository;

  Future<List<ProductSalesSummary>> call({
    required int shopId,
    SalesAnalysisQuery query = const SalesAnalysisQuery(),
  }) {
    return _repository.listProductSummaries(shopId: shopId, query: query);
  }
}

class GetProductSalesDetail {
  const GetProductSalesDetail(this._repository);

  final SalesAnalysisRepository _repository;

  Future<ProductSalesDetail> call({
    required int shopId,
    required SalesAnalysisQuery query,
    int? productId,
    required String productName,
  }) {
    return _repository.loadProductDetail(
      shopId: shopId,
      query: query,
      productId: productId,
      productName: productName,
    );
  }
}

class ListEmployeePriceAnalysis {
  const ListEmployeePriceAnalysis(this._repository);

  final SalesAnalysisRepository _repository;

  Future<List<EmployeePricePerformance>> call({
    required int shopId,
    SalesAnalysisQuery query = const SalesAnalysisQuery(),
  }) {
    return _repository.listEmployeePerformance(shopId: shopId, query: query);
  }
}

class ListCustomerSalesInsights {
  const ListCustomerSalesInsights(this._repository);

  final SalesAnalysisRepository _repository;

  Future<List<CustomerSalesInsight>> call({
    required int shopId,
    SalesAnalysisQuery query = const SalesAnalysisQuery(),
  }) {
    return _repository.listCustomerInsights(shopId: shopId, query: query);
  }
}

class GetCustomerPriceHabits {
  const GetCustomerPriceHabits(this._repository);

  final SalesAnalysisRepository _repository;

  Future<List<CustomerProductPriceHabit>> call({
    required int shopId,
    required int customerId,
  }) {
    return _repository.listCustomerPriceHabits(
      shopId: shopId,
      customerId: customerId,
    );
  }
}

class GetProductSoldPriceRange {
  const GetProductSoldPriceRange(this._repository);

  final SalesAnalysisRepository _repository;

  Future<ProductSoldPriceRange> call({
    required int shopId,
    required int productId,
  }) {
    return _repository.soldPriceRangeForProduct(
      shopId: shopId,
      productId: productId,
    );
  }
}
