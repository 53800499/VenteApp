import 'package:equatable/equatable.dart';

import '../../../../core/utils/benin_period_range.dart';

enum ReportTopSort { quantity, revenue }

class ReportQuery extends Equatable {
  const ReportQuery({
    this.period = ReportPeriodPreset.month,
    this.customFrom,
    this.customTo,
    this.consolidated = false,
    this.topBy = ReportTopSort.quantity,
    this.topLimit = 10,
  });

  final ReportPeriodPreset period;
  final int? customFrom;
  final int? customTo;
  final bool consolidated;
  final ReportTopSort topBy;
  final int topLimit;

  ReportQuery copyWith({
    ReportPeriodPreset? period,
    int? customFrom,
    int? customTo,
    bool? consolidated,
    ReportTopSort? topBy,
    int? topLimit,
  }) {
    return ReportQuery(
      period: period ?? this.period,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
      consolidated: consolidated ?? this.consolidated,
      topBy: topBy ?? this.topBy,
      topLimit: topLimit ?? this.topLimit,
    );
  }

  @override
  List<Object?> get props =>
      [period, customFrom, customTo, consolidated, topBy, topLimit];
}

class ReportPeriod extends Equatable {
  const ReportPeriod({
    required this.preset,
    required this.label,
    required this.fromMs,
    required this.toMs,
  });

  final ReportPeriodPreset preset;
  final String label;
  final int fromMs;
  final int toMs;

  @override
  List<Object?> get props => [preset, label, fromMs, toMs];
}

class ReportSalesKpis extends Equatable {
  const ReportSalesKpis({
    required this.grossRevenue,
    required this.collectedRevenue,
    required this.creditGranted,
    required this.saleCount,
    required this.averageBasket,
    required this.totalCash,
    required this.totalMomo,
    required this.totalCredit,
  });

  const ReportSalesKpis.zero()
      : grossRevenue = 0,
        collectedRevenue = 0,
        creditGranted = 0,
        saleCount = 0,
        averageBasket = 0,
        totalCash = 0,
        totalMomo = 0,
        totalCredit = 0;

  final int grossRevenue;
  final int collectedRevenue;
  final int creditGranted;
  final int saleCount;
  final int averageBasket;
  final int totalCash;
  final int totalMomo;
  final int totalCredit;

  @override
  List<Object?> get props => [
        grossRevenue,
        collectedRevenue,
        creditGranted,
        saleCount,
        averageBasket,
        totalCash,
        totalMomo,
        totalCredit,
      ];
}

class ReportFinancialKpis extends Equatable {
  const ReportFinancialKpis({
    this.estimatedProfit,
    required this.profitAvailable,
    this.profitWarning,
    this.recoveryRate,
    required this.recoveryRateAvailable,
    required this.debtsCreatedAmount,
    required this.debtsRepaidAmount,
    this.totalExpenses = 0,
    this.netProfit,
  });

  final int? estimatedProfit;
  final bool profitAvailable;
  final String? profitWarning;
  final int? recoveryRate;
  final bool recoveryRateAvailable;
  final int debtsCreatedAmount;
  final int debtsRepaidAmount;
  final int totalExpenses;
  final int? netProfit;

  @override
  List<Object?> get props => [
        estimatedProfit,
        profitAvailable,
        profitWarning,
        recoveryRate,
        recoveryRateAvailable,
        debtsCreatedAmount,
        debtsRepaidAmount,
        totalExpenses,
        netProfit,
      ];
}

class ReportTopProduct extends Equatable {
  const ReportTopProduct({
    required this.rank,
    this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
  });

  final int rank;
  final int? productId;
  final String productName;
  final double quantitySold;
  final int revenue;

  @override
  List<Object?> get props =>
      [rank, productId, productName, quantitySold, revenue];
}

class ReportSellerPerformance extends Equatable {
  const ReportSellerPerformance({
    required this.userId,
    this.userName,
    required this.saleCount,
    required this.totalRevenue,
  });

  final int userId;
  final String? userName;
  final int saleCount;
  final int totalRevenue;

  @override
  List<Object?> get props => [userId, userName, saleCount, totalRevenue];
}

class Report extends Equatable {
  const Report({
    this.shopId,
    required this.shopIds,
    required this.consolidated,
    required this.period,
    required this.empty,
    this.emptyMessage,
    required this.sales,
    this.financial,
    required this.topProducts,
    this.sellerPerformance,
    required this.generatedAt,
  });

  final int? shopId;
  final List<int> shopIds;
  final bool consolidated;
  final ReportPeriod period;
  final bool empty;
  final String? emptyMessage;
  final ReportSalesKpis sales;
  final ReportFinancialKpis? financial;
  final List<ReportTopProduct> topProducts;
  final List<ReportSellerPerformance>? sellerPerformance;
  final int generatedAt;

  Report copyWith({
    List<ReportTopProduct>? topProducts,
  }) {
    return Report(
      shopId: shopId,
      shopIds: shopIds,
      consolidated: consolidated,
      period: period,
      empty: empty,
      emptyMessage: emptyMessage,
      sales: sales,
      financial: financial,
      topProducts: topProducts ?? this.topProducts,
      sellerPerformance: sellerPerformance,
      generatedAt: generatedAt,
    );
  }

  @override
  List<Object?> get props => [
        shopId,
        shopIds,
        consolidated,
        period,
        empty,
        emptyMessage,
        sales,
        financial,
        topProducts,
        sellerPerformance,
        generatedAt,
      ];
}
