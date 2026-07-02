import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../../../core/utils/time.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/services/report_aggregation_service.dart';
import '../datasources/local/reports_local_datasource.dart';
import '../datasources/remote/reports_remote_datasource.dart';
import '../mappers/report_mapper.dart';

const _emptyMessage = 'Aucune vente sur cette période.';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({
    required ReportsLocalDatasource local,
    required ReportsRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
    ReportAggregationService? aggregation,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _aggregation = aggregation ?? const ReportAggregationService();

  final ReportsLocalDatasource _local;
  final ReportsRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;
  final ReportAggregationService _aggregation;

  @override
  Future<Report> getReport({
    required int activeShopId,
    required int ownerUserId,
    required ReportQuery query,
    required bool canViewFinancial,
    required bool canUseConsolidated,
    required bool includeSellerPerformance,
  }) async {
    if (query.consolidated && !canUseConsolidated) {
      throw const UnauthorizedFailure(
        'La vue consolidée est réservée au patron.',
      );
    }

    try {
      await _apiGuard.ensureReady();
      final remote = await _remote.fetchReport(
        period: query.period,
        from: query.customFrom,
        to: query.customTo,
        consolidated: query.consolidated,
        topBy: query.topBy,
        topLimit: query.topLimit,
      );
      return ReportMapper.fromApi(remote);
    } on Failure {
      // Données locales — offline-first §13.1
    } catch (_) {
      // Fallback local
    }

    return _buildLocalReport(
      activeShopId: activeShopId,
      ownerUserId: ownerUserId,
      query: query,
      canViewFinancial: canViewFinancial,
      includeSellerPerformance: includeSellerPerformance,
    );
  }

  Future<Report> _buildLocalReport({
    required int activeShopId,
    required int ownerUserId,
    required ReportQuery query,
    required bool canViewFinancial,
    required bool includeSellerPerformance,
  }) async {
    final periodRange = resolveReportPeriod(
      preset: query.period,
      customFrom: query.customFrom,
      customTo: query.customTo,
    );

    final shopIds = await _resolveShopIds(
      activeShopId: activeShopId,
      ownerUserId: ownerUserId,
      consolidated: query.consolidated,
    );

    final raw = await _local.loadPeriodData(
      shopIds: shopIds,
      fromMs: periodRange.fromMs,
      toMs: periodRange.toMs,
      includeSellerPerformance: includeSellerPerformance,
    );

    final salesKpis = _aggregation.aggregateSales(raw.sales);
    final empty = salesKpis.saleCount == 0;

    final topSorted = _aggregation
        .sortTopProducts(raw.topProducts, query.topBy, query.topLimit)
        .asMap()
        .entries
        .map(
          (e) => ReportTopProduct(
            rank: e.key + 1,
            productId: e.value.productId,
            productName: e.value.productName,
            quantitySold: e.value.quantitySold,
            revenue: e.value.revenue,
          ),
        )
        .toList();

    final financial = canViewFinancial
        ? _aggregation.aggregateFinancial(
            profitLines: raw.profitLines,
            debtRecovery: raw.debtRecovery,
          )
        : null;

    final sellers = includeSellerPerformance && raw.sellerPerformance.isNotEmpty
        ? _aggregation
            .aggregateSellerPerformance(raw.sellerPerformance)
            .map(
              (s) => ReportSellerPerformance(
                userId: s.userId,
                userName: s.userName,
                saleCount: s.saleCount,
                totalRevenue: s.totalRevenue,
              ),
            )
            .toList()
        : null;

    return Report(
      shopId: query.consolidated ? null : activeShopId,
      shopIds: shopIds,
      consolidated: query.consolidated,
      period: ReportPeriod(
        preset: periodRange.preset,
        label: periodRange.label,
        fromMs: periodRange.fromMs,
        toMs: periodRange.toMs,
      ),
      empty: empty,
      emptyMessage: empty ? _emptyMessage : null,
      sales: salesKpis,
      financial: financial,
      topProducts: empty ? const [] : topSorted,
      sellerPerformance: empty ? null : sellers,
      generatedAt: nowMs(),
    );
  }

  Future<List<int>> _resolveShopIds({
    required int activeShopId,
    required int ownerUserId,
    required bool consolidated,
  }) async {
    if (!consolidated) return [activeShopId];

    final owned = await _local.activeShopIdsForOwner(ownerUserId);
    return owned.isEmpty ? [activeShopId] : owned;
  }
}
