import '../../../../core/utils/benin_day_range.dart';
import '../../../../core/utils/time.dart';
import '../../../../shared/enums/permission.dart';
import '../datasources/local/dashboard_local_datasource.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/services/dashboard_aggregation_service.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required DashboardLocalDatasource localDatasource,
    DashboardAggregationService? aggregation,
  })  : _local = localDatasource,
        _aggregation = aggregation ?? DashboardAggregationService();

  final DashboardLocalDatasource _local;
  final DashboardAggregationService _aggregation;

  @override
  Future<DashboardData> getDashboard({
    required int shopId,
    required Set<Permission> permissions,
    int defaultAlertThreshold = 5,
  }) async {
    final range = getBeninDayBounds();
    final threshold = await _local.resolveAlertThreshold(shopId);

    final sales = await _local.fetchTodaySales(shopId, range);
    final recentSales = await _local.fetchRecentTodaySales(shopId, range);
    final profitLines = await _local.fetchTodayProfitLines(shopId, range);
    final lowStockCount = await _local.countLowStock(shopId, threshold);
    final debts = await _local.fetchDebtSummary(shopId);

    final salesStats = _aggregation.aggregateSales(sales);
    final kpis = _aggregation.toPublicKpis(
      salesStats: salesStats,
      lowStockCount: lowStockCount,
      debtorCount: debts.debtorCount,
    );

    final canViewFinancial =
        permissions.contains(Permission.dashboardFinancial);
    final financial = canViewFinancial
        ? _aggregation.aggregateFinancial(
            salesStats: salesStats,
            profitLines: profitLines,
            debts: debts,
          )
        : null;

    return DashboardData(
      shopId: shopId,
      date: formatBeninDate(range.dayEndMs),
      kpis: kpis,
      financial: financial,
      recentSales: recentSales
          .map(
            (sale) => DashboardRecentSale(
              id: sale.id,
              totalAmount: sale.totalAmount,
              createdAt: sale.createdAt,
              customerName: sale.customerName,
              paymentMode: _aggregation.resolvePaymentMode(sale),
            ),
          )
          .toList(),
      generatedAt: nowMs(),
    );
  }
}
