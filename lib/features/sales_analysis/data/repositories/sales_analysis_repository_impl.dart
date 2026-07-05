import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../domain/entities/sales_analysis_entities.dart';
import '../../domain/repositories/sales_analysis_repository.dart';
import '../datasources/local/sales_analysis_local_datasource.dart';
import '../datasources/remote/sales_analysis_remote_datasource.dart';
import '../mappers/sales_analysis_mapper.dart';

class SalesAnalysisRepositoryImpl implements SalesAnalysisRepository {
  SalesAnalysisRepositoryImpl({
    required SalesAnalysisLocalDatasource local,
    required SalesAnalysisRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard;

  final SalesAnalysisLocalDatasource _local;
  final SalesAnalysisRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;

  SalesAnalysisQuery? _cachedRemoteQuery;
  SalesAnalysisRemoteBundle? _cachedRemoteBundle;
  Future<SalesAnalysisRemoteBundle?>? _inFlightRemote;

  ResolvedReportPeriod _resolve(SalesAnalysisQuery query) {
    return resolveReportPeriod(
      preset: query.period,
      customFrom: query.customFrom,
      customTo: query.customTo,
    );
  }

  Future<SalesAnalysisRemoteBundle?> _loadRemoteBundle(
    SalesAnalysisQuery query,
  ) async {
    if (_cachedRemoteQuery == query && _cachedRemoteBundle != null) {
      return _cachedRemoteBundle;
    }
    if (_inFlightRemote != null && _cachedRemoteQuery == query) {
      return _inFlightRemote;
    }

    _cachedRemoteQuery = query;
    _inFlightRemote = _fetchRemote(query);
    final bundle = await _inFlightRemote;
    _inFlightRemote = null;
    if (bundle != null) {
      _cachedRemoteBundle = bundle;
    }
    return bundle;
  }

  Future<SalesAnalysisRemoteBundle?> _fetchRemote(
    SalesAnalysisQuery query,
  ) async {
    try {
      await _apiGuard.ensureReady();
      final dto = await _remote.fetchAnalysis(
        period: query.period,
        from: query.customFrom,
        to: query.customTo,
      );
      return SalesAnalysisMapper.fromApi(dto);
    } on Failure {
      return null;
    } catch (_) {
      return null;
    }
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

  @override
  Future<List<CategorySalesSummary>> listCategorySummaries({
    required int shopId,
    required SalesAnalysisQuery query,
  }) async {
    final remote = await _loadRemoteBundle(query);
    if (remote != null) return remote.categories;

    final period = _resolve(query);
    return _local.listCategorySummaries(
      shopId: shopId,
      fromMs: period.fromMs,
      toMs: period.toMs,
    );
  }

  @override
  Future<MarginSummary> loadMarginSummary({
    required int shopId,
    required SalesAnalysisQuery query,
  }) async {
    final remote = await _loadRemoteBundle(query);
    if (remote?.margins != null) return remote!.margins!;

    final period = _resolve(query);
    return _local.loadMarginSummary(
      shopId: shopId,
      fromMs: period.fromMs,
      toMs: period.toMs,
    );
  }

  @override
  Future<List<PriceDeviationLine>> listPriceDeviations({
    required int shopId,
    required SalesAnalysisQuery query,
  }) async {
    final remote = await _loadRemoteBundle(query);
    if (remote != null) return remote.priceDeviations;

    final period = _resolve(query);
    return _local.listPriceDeviations(
      shopId: shopId,
      fromMs: period.fromMs,
      toMs: period.toMs,
    );
  }

  @override
  Future<SalesTrendSummary> loadSalesTrends({
    required int shopId,
    required SalesAnalysisQuery query,
  }) async {
    final remote = await _loadRemoteBundle(query);
    if (remote != null) return remote.trends;

    final period = _resolve(query);
    return _local.loadSalesTrends(
      shopId: shopId,
      fromMs: period.fromMs,
      toMs: period.toMs,
    );
  }
}
