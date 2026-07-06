import '../entities/report_entities.dart';

/// Agrégation Module 8 — alignée sur le backend `ReportAggregationService`.
class ReportAggregationService {
  const ReportAggregationService();

  ReportSalesKpis aggregateSales(List<ReportSaleRow> sales) {
    if (sales.isEmpty) return const ReportSalesKpis.zero();

    var grossRevenue = 0;
    var collectedRevenue = 0;
    var creditGranted = 0;
    var totalCash = 0;
    var totalMomo = 0;
    var totalCredit = 0;

    for (final sale in sales) {
      grossRevenue += sale.totalAmount;
      collectedRevenue += sale.amountCash + sale.amountMomo;
      creditGranted += sale.amountCredit;
      totalCash += sale.amountCash;
      totalMomo += sale.amountMomo;
      totalCredit += sale.amountCredit;
    }

    return ReportSalesKpis(
      grossRevenue: grossRevenue,
      collectedRevenue: collectedRevenue,
      creditGranted: creditGranted,
      saleCount: sales.length,
      averageBasket: (grossRevenue / sales.length).round(),
      totalCash: totalCash,
      totalMomo: totalMomo,
      totalCredit: totalCredit,
    );
  }

  ReportFinancialKpis aggregateFinancial({
    required List<ReportProfitLine> profitLines,
    required ReportDebtRecoveryRaw debtRecovery,
    int totalExpenses = 0,
  }) {
    final hasCostData = profitLines.any(
      (line) => line.unitCost != null && line.unitCost! > 0,
    );

    int? estimatedProfit;
    String? profitWarning;

    if (!hasCostData) {
      profitWarning =
          'Bénéfice indisponible : renseignez le prix d\'achat sur les produits vendus sur la période.';
    } else {
      estimatedProfit = profitLines.fold<int>(0, (sum, line) {
        if (line.unitCost == null) return sum;
        final margin = line.unitPrice - line.unitCost!;
        return sum + (margin * line.quantity).round();
      });
    }

    final debtsCreatedAmount = debtRecovery.debtsCreatedAmount;
    final debtsRepaidAmount = debtRecovery.debtsRepaidAmount;
    int? recoveryRate;
    var recoveryRateAvailable = false;

    if (debtsCreatedAmount > 0) {
      recoveryRate =
          ((debtsRepaidAmount / debtsCreatedAmount) * 100).round();
      recoveryRateAvailable = true;
    }

    return ReportFinancialKpis(
      estimatedProfit: estimatedProfit,
      profitAvailable: hasCostData,
      profitWarning: profitWarning,
      recoveryRate: recoveryRate,
      recoveryRateAvailable: recoveryRateAvailable,
      debtsCreatedAmount: debtsCreatedAmount,
      debtsRepaidAmount: debtsRepaidAmount,
      totalExpenses: totalExpenses,
      netProfit: estimatedProfit != null
          ? estimatedProfit - totalExpenses
          : null,
    );
  }

  List<ReportTopProductRow> sortTopProducts(
    List<ReportTopProductRow> products,
    ReportTopSort sortBy,
    int limit,
  ) {
    final sorted = [...products]
      ..sort(
        (a, b) => sortBy == ReportTopSort.revenue
            ? b.revenue.compareTo(a.revenue)
            : b.quantitySold.compareTo(a.quantitySold),
      );
    return sorted.take(limit).toList();
  }

  List<ReportSellerRow> aggregateSellerPerformance(List<ReportSellerRow> sellers) {
    return [...sellers]..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
  }
}

class ReportSaleRow {
  const ReportSaleRow({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.totalAmount,
    required this.amountCash,
    required this.amountMomo,
    required this.amountCredit,
    required this.createdAt,
  });

  final int id;
  final int shopId;
  final int userId;
  final int totalAmount;
  final int amountCash;
  final int amountMomo;
  final int amountCredit;
  final int createdAt;
}

class ReportProfitLine {
  const ReportProfitLine({
    required this.quantity,
    required this.unitPrice,
    this.unitCost,
  });

  final double quantity;
  final int unitPrice;
  final int? unitCost;
}

class ReportTopProductRow {
  const ReportTopProductRow({
    this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
  });

  final int? productId;
  final String productName;
  final double quantitySold;
  final int revenue;
}

class ReportSellerRow {
  const ReportSellerRow({
    required this.userId,
    this.userName,
    required this.saleCount,
    required this.totalRevenue,
  });

  final int userId;
  final String? userName;
  final int saleCount;
  final int totalRevenue;
}

class ReportDebtRecoveryRaw {
  const ReportDebtRecoveryRaw({
    required this.debtsCreatedAmount,
    required this.debtsRepaidAmount,
  });

  final int debtsCreatedAmount;
  final int debtsRepaidAmount;
}
