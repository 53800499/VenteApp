class TodaySaleRow {
  const TodaySaleRow({
    required this.id,
    required this.totalAmount,
    required this.amountCash,
    required this.amountMomo,
    required this.amountCredit,
    required this.createdAt,
    this.customerId,
    this.customerName,
  });

  final int id;
  final int totalAmount;
  final int amountCash;
  final int amountMomo;
  final int amountCredit;
  final int createdAt;
  final int? customerId;
  final String? customerName;
}

class SaleProfitRow {
  const SaleProfitRow({
    required this.quantity,
    required this.unitPrice,
    this.unitCost,
  });

  final double quantity;
  final int unitPrice;
  final int? unitCost;
}

class DashboardSalesStats {
  const DashboardSalesStats({
    required this.totalRevenue,
    required this.saleCount,
    required this.totalCash,
    required this.totalMomo,
    required this.totalCredit,
  });

  final int totalRevenue;
  final int saleCount;
  final int totalCash;
  final int totalMomo;
  final int totalCredit;
}

class DashboardDebtStats {
  const DashboardDebtStats({
    required this.debtorCount,
    required this.totalDebt,
  });

  final int debtorCount;
  final int totalDebt;
}

class DashboardKpis {
  const DashboardKpis({
    required this.totalRevenue,
    required this.saleCount,
    required this.lowStockCount,
    required this.debtorCount,
  });

  final int totalRevenue;
  final int saleCount;
  final int lowStockCount;
  final int debtorCount;
}

class DashboardFinancialKpis {
  const DashboardFinancialKpis({
    required this.totalCash,
    required this.totalMomo,
    required this.totalCredit,
    required this.estimatedProfit,
    required this.profitAvailable,
    this.profitWarning,
    required this.totalDebt,
    this.totalExpenses = 0,
    this.netProfit,
  });

  final int totalCash;
  final int totalMomo;
  final int totalCredit;
  final int? estimatedProfit;
  final bool profitAvailable;
  final String? profitWarning;
  final int totalDebt;
  final int totalExpenses;
  final int? netProfit;
}

class DashboardRecentSale {
  const DashboardRecentSale({
    required this.id,
    required this.totalAmount,
    required this.createdAt,
    this.customerName,
    required this.paymentMode,
  });

  final int id;
  final int totalAmount;
  final int createdAt;
  final String? customerName;
  final String paymentMode;
}

class DashboardData {
  const DashboardData({
    required this.shopId,
    required this.date,
    required this.kpis,
    required this.recentSales,
    required this.generatedAt,
    this.financial,
  });

  final int shopId;
  final String date;
  final DashboardKpis kpis;
  final List<DashboardRecentSale> recentSales;
  final int generatedAt;
  final DashboardFinancialKpis? financial;
}
