import '../../../../../core/utils/benin_period_range.dart';

class ReportApiDto {
  const ReportApiDto({
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
  final ReportPeriodApiDto period;
  final bool empty;
  final String? emptyMessage;
  final ReportSalesApiDto sales;
  final ReportFinancialApiDto? financial;
  final List<ReportTopProductApiDto> topProducts;
  final List<ReportSellerApiDto>? sellerPerformance;
  final int generatedAt;

  factory ReportApiDto.fromJson(Map<String, dynamic> json) {
    return ReportApiDto(
      shopId: json['shopId'] as int?,
      shopIds: (json['shopIds'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      consolidated: json['consolidated'] as bool? ?? false,
      period: ReportPeriodApiDto.fromJson(
        json['period'] as Map<String, dynamic>,
      ),
      empty: json['empty'] as bool? ?? false,
      emptyMessage: json['emptyMessage'] as String?,
      sales: ReportSalesApiDto.fromJson(
        json['sales'] as Map<String, dynamic>,
      ),
      financial: json['financial'] is Map<String, dynamic>
          ? ReportFinancialApiDto.fromJson(
              json['financial'] as Map<String, dynamic>,
            )
          : null,
      topProducts: (json['topProducts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportTopProductApiDto.fromJson)
          .toList(),
      sellerPerformance: (json['sellerPerformance'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(ReportSellerApiDto.fromJson)
          .toList(),
      generatedAt: (json['generatedAt'] as num).toInt(),
    );
  }
}

class ReportPeriodApiDto {
  const ReportPeriodApiDto({
    required this.preset,
    required this.label,
    required this.fromMs,
    required this.toMs,
  });

  final String preset;
  final String label;
  final int fromMs;
  final int toMs;

  factory ReportPeriodApiDto.fromJson(Map<String, dynamic> json) {
    return ReportPeriodApiDto(
      preset: json['preset'] as String? ?? 'month',
      label: json['label'] as String? ?? '',
      fromMs: (json['fromMs'] as num).toInt(),
      toMs: (json['toMs'] as num).toInt(),
    );
  }
}

class ReportSalesApiDto {
  const ReportSalesApiDto({
    required this.grossRevenue,
    required this.collectedRevenue,
    required this.creditGranted,
    required this.saleCount,
    required this.averageBasket,
    required this.totalCash,
    required this.totalMomo,
    required this.totalCredit,
  });

  final int grossRevenue;
  final int collectedRevenue;
  final int creditGranted;
  final int saleCount;
  final int averageBasket;
  final int totalCash;
  final int totalMomo;
  final int totalCredit;

  factory ReportSalesApiDto.fromJson(Map<String, dynamic> json) {
    return ReportSalesApiDto(
      grossRevenue: (json['grossRevenue'] as num?)?.toInt() ?? 0,
      collectedRevenue: (json['collectedRevenue'] as num?)?.toInt() ?? 0,
      creditGranted: (json['creditGranted'] as num?)?.toInt() ?? 0,
      saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      averageBasket: (json['averageBasket'] as num?)?.toInt() ?? 0,
      totalCash: (json['totalCash'] as num?)?.toInt() ?? 0,
      totalMomo: (json['totalMomo'] as num?)?.toInt() ?? 0,
      totalCredit: (json['totalCredit'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportFinancialApiDto {
  const ReportFinancialApiDto({
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

  factory ReportFinancialApiDto.fromJson(Map<String, dynamic> json) {
    return ReportFinancialApiDto(
      estimatedProfit: (json['estimatedProfit'] as num?)?.toInt(),
      profitAvailable: json['profitAvailable'] as bool? ?? false,
      profitWarning: json['profitWarning'] as String?,
      recoveryRate: (json['recoveryRate'] as num?)?.toInt(),
      recoveryRateAvailable: json['recoveryRateAvailable'] as bool? ?? false,
      debtsCreatedAmount: (json['debtsCreatedAmount'] as num?)?.toInt() ?? 0,
      debtsRepaidAmount: (json['debtsRepaidAmount'] as num?)?.toInt() ?? 0,
      totalExpenses: (json['totalExpenses'] as num?)?.toInt() ?? 0,
      netProfit: (json['netProfit'] as num?)?.toInt(),
    );
  }
}

class ReportTopProductApiDto {
  const ReportTopProductApiDto({
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

  factory ReportTopProductApiDto.fromJson(Map<String, dynamic> json) {
    return ReportTopProductApiDto(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      productId: (json['productId'] as num?)?.toInt(),
      productName: json['productName'] as String? ?? '',
      quantitySold: (json['quantitySold'] as num?)?.toDouble() ?? 0,
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportSellerApiDto {
  const ReportSellerApiDto({
    required this.userId,
    this.userName,
    required this.saleCount,
    required this.totalRevenue,
  });

  final int userId;
  final String? userName;
  final int saleCount;
  final int totalRevenue;

  factory ReportSellerApiDto.fromJson(Map<String, dynamic> json) {
    return ReportSellerApiDto(
      userId: (json['userId'] as num).toInt(),
      userName: json['userName'] as String?,
      saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toInt() ?? 0,
    );
  }
}

ReportPeriodPreset parseReportPeriodPreset(String value) =>
    ReportPeriodPreset.values.firstWhere(
      (p) => p.name == value,
      orElse: () => ReportPeriodPreset.month,
    );
