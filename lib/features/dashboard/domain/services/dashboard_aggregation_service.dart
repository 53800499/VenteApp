import '../entities/dashboard_entities.dart';

class DashboardAggregationService {
  DashboardSalesStats aggregateSales(List<TodaySaleRow> sales) {
    if (sales.isEmpty) {
      return const DashboardSalesStats(
        totalRevenue: 0,
        saleCount: 0,
        totalCash: 0,
        totalMomo: 0,
        totalCredit: 0,
      );
    }

    var totalRevenue = 0;
    var totalCash = 0;
    var totalMomo = 0;
    var totalCredit = 0;

    for (final sale in sales) {
      totalRevenue += sale.totalAmount;
      totalCash += sale.amountCash;
      totalMomo += sale.amountMomo;
      totalCredit += sale.amountCredit;
    }

    return DashboardSalesStats(
      totalRevenue: totalRevenue,
      saleCount: sales.length,
      totalCash: totalCash,
      totalMomo: totalMomo,
      totalCredit: totalCredit,
    );
  }

  DashboardFinancialKpis aggregateFinancial({
    required DashboardSalesStats salesStats,
    required List<SaleProfitRow> profitLines,
    required DashboardDebtStats debts,
  }) {
    final hasCostData = profitLines.any(
      (line) => line.unitCost != null && line.unitCost! > 0,
    );

    int? estimatedProfit;
    String? profitWarning;

    if (!hasCostData) {
      profitWarning =
          'Bénéfice indisponible : renseignez le prix d\'achat sur les produits vendus aujourd\'hui.';
    } else {
      estimatedProfit = profitLines.fold<int>(0, (sum, line) {
        if (line.unitCost == null) return sum;
        final margin = line.unitPrice - line.unitCost!;
        return sum + (margin * line.quantity).round();
      });
    }

    return DashboardFinancialKpis(
      totalCash: salesStats.totalCash,
      totalMomo: salesStats.totalMomo,
      totalCredit: salesStats.totalCredit,
      estimatedProfit: estimatedProfit,
      profitAvailable: hasCostData,
      profitWarning: profitWarning,
      totalDebt: debts.totalDebt,
    );
  }

  DashboardKpis toPublicKpis({
    required DashboardSalesStats salesStats,
    required int lowStockCount,
    required int debtorCount,
  }) {
    return DashboardKpis(
      totalRevenue: salesStats.totalRevenue,
      saleCount: salesStats.saleCount,
      lowStockCount: lowStockCount,
      debtorCount: debtorCount,
    );
  }

  String resolvePaymentMode(TodaySaleRow sale) {
    if (sale.amountCredit > 0 && sale.amountCash == 0 && sale.amountMomo == 0) {
      return 'credit';
    }
    if (sale.amountCredit > 0) return 'mixed';
    if (sale.amountMomo > 0 && sale.amountCash == 0) return 'momo';
    if (sale.amountMomo > 0) return 'mixed';
    return 'cash';
  }
}
