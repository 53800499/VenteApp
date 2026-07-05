import '../../../../core/utils/benin_period_range.dart';
import '../../domain/entities/sales_analysis_entities.dart';
import '../../domain/repositories/sales_analysis_repository.dart';
import '../../data/datasources/local/sales_analysis_local_datasource.dart';

class SalesAnalysisRepositoryImpl implements SalesAnalysisRepository {
  SalesAnalysisRepositoryImpl(this._local);

  final SalesAnalysisLocalDatasource _local;

  ResolvedReportPeriod _resolve(SalesAnalysisQuery query) {
    return resolveReportPeriod(
      preset: query.period,
      customFrom: query.customFrom,
      customTo: query.customTo,
    );
  }

  @override
  Future<List<ProductSalesSummary>> listProductSummaries({
    required int shopId,
    required SalesAnalysisQuery query,
  }) async {
    final period = _resolve(query);
    return _local.listProductSummaries(
      shopId: shopId,
      fromMs: period.fromMs,
      toMs: period.toMs,
    );
  }

  @override
  Future<ProductSalesDetail> loadProductDetail({
    required int shopId,
    required SalesAnalysisQuery query,
    int? productId,
    required String productName,
  }) async {
    final period = _resolve(query);
    return _local.loadProductDetail(
      shopId: shopId,
      fromMs: period.fromMs,
      toMs: period.toMs,
      productId: productId,
      productName: productName,
    );
  }

  @override
  Future<List<EmployeePricePerformance>> listEmployeePerformance({
    required int shopId,
    required SalesAnalysisQuery query,
  }) async {
    final period = _resolve(query);
    return _local.listEmployeePerformance(
      shopId: shopId,
      fromMs: period.fromMs,
      toMs: period.toMs,
    );
  }

  @override
  Future<List<CustomerSalesInsight>> listCustomerInsights({
    required int shopId,
    required SalesAnalysisQuery query,
  }) async {
    final period = _resolve(query);
    return _local.listCustomerInsights(
      shopId: shopId,
      fromMs: period.fromMs,
      toMs: period.toMs,
    );
  }

  @override
  Future<List<CustomerProductPriceHabit>> listCustomerPriceHabits({
    required int shopId,
    required int customerId,
  }) {
    return _local.listCustomerPriceHabits(
      shopId: shopId,
      customerId: customerId,
    );
  }

  @override
  Future<ProductSoldPriceRange> soldPriceRangeForProduct({
    required int shopId,
    required int productId,
  }) {
    return _local.soldPriceRangeForProduct(
      shopId: shopId,
      productId: productId,
    );
  }
}
