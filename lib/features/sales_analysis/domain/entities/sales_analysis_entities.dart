import 'package:equatable/equatable.dart';

import '../../../../core/utils/benin_period_range.dart';

class SalesAnalysisQuery extends Equatable {
  const SalesAnalysisQuery({
    this.period = ReportPeriodPreset.month,
    this.customFrom,
    this.customTo,
  });

  final ReportPeriodPreset period;
  final int? customFrom;
  final int? customTo;

  SalesAnalysisQuery copyWith({
    ReportPeriodPreset? period,
    int? customFrom,
    int? customTo,
  }) {
    return SalesAnalysisQuery(
      period: period ?? this.period,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
    );
  }

  @override
  List<Object?> get props => [period, customFrom, customTo];
}

class ProductSalesSummary extends Equatable {
  const ProductSalesSummary({
    this.productId,
    required this.productName,
    this.catalogPrice,
    required this.quantitySold,
    required this.revenue,
    required this.averageUnitPrice,
    this.lastSaleAt,
  });

  final int? productId;
  final String productName;
  final int? catalogPrice;
  final double quantitySold;
  final int revenue;
  final int averageUnitPrice;
  final int? lastSaleAt;

  @override
  List<Object?> get props => [
        productId,
        productName,
        catalogPrice,
        quantitySold,
        revenue,
        averageUnitPrice,
        lastSaleAt,
      ];
}

class ProductSaleLine extends Equatable {
  const ProductSaleLine({
    required this.saleId,
    required this.soldAt,
    this.customerName,
    required this.quantity,
    required this.unitPrice,
    this.sellerName,
    this.catalogPrice,
    required this.discountAmount,
  });

  final int saleId;
  final int soldAt;
  final String? customerName;
  final double quantity;
  final int unitPrice;
  final String? sellerName;
  final int? catalogPrice;
  final int discountAmount;

  @override
  List<Object?> get props => [
        saleId,
        soldAt,
        customerName,
        quantity,
        unitPrice,
        sellerName,
        catalogPrice,
        discountAmount,
      ];
}

class ProductPriceStats extends Equatable {
  const ProductPriceStats({
    this.catalogPrice,
    required this.minSoldPrice,
    required this.maxSoldPrice,
    required this.averageUnitPrice,
    required this.quantitySold,
    required this.revenue,
    required this.saleLineCount,
  });

  final int? catalogPrice;
  final int minSoldPrice;
  final int maxSoldPrice;
  final int averageUnitPrice;
  final double quantitySold;
  final int revenue;
  final int saleLineCount;

  @override
  List<Object?> get props => [
        catalogPrice,
        minSoldPrice,
        maxSoldPrice,
        averageUnitPrice,
        quantitySold,
        revenue,
        saleLineCount,
      ];
}

class EmployeePricePerformance extends Equatable {
  const EmployeePricePerformance({
    required this.userId,
    this.userName,
    required this.saleLineCount,
    required this.averageUnitPrice,
    required this.discountLineCount,
  });

  final int userId;
  final String? userName;
  final int saleLineCount;
  final int averageUnitPrice;
  final int discountLineCount;

  @override
  List<Object?> get props => [
        userId,
        userName,
        saleLineCount,
        averageUnitPrice,
        discountLineCount,
      ];
}

class ProductSoldPriceRange extends Equatable {
  const ProductSoldPriceRange({
    required this.minPrice,
    required this.maxPrice,
    required this.averagePrice,
    required this.sampleCount,
  });

  const ProductSoldPriceRange.empty()
      : minPrice = 0,
        maxPrice = 0,
        averagePrice = 0,
        sampleCount = 0;

  final int minPrice;
  final int maxPrice;
  final int averagePrice;
  final int sampleCount;

  bool get hasEnoughData => sampleCount >= 3;

  @override
  List<Object?> get props => [minPrice, maxPrice, averagePrice, sampleCount];
}

class ProductSalesDetail extends Equatable {
  const ProductSalesDetail({
    required this.summary,
    required this.stats,
    required this.lines,
    required this.employeeStats,
  });

  final ProductSalesSummary summary;
  final ProductPriceStats stats;
  final List<ProductSaleLine> lines;
  final List<EmployeePricePerformance> employeeStats;

  @override
  List<Object?> get props => [summary, stats, lines, employeeStats];
}

class CustomerSalesInsight extends Equatable {
  const CustomerSalesInsight({
    required this.customerId,
    required this.customerName,
    required this.saleCount,
    required this.lineCount,
    required this.totalRevenue,
    required this.averageUnitPrice,
  });

  final int customerId;
  final String customerName;
  final int saleCount;
  final int lineCount;
  final int totalRevenue;
  final int averageUnitPrice;

  @override
  List<Object?> get props => [
        customerId,
        customerName,
        saleCount,
        lineCount,
        totalRevenue,
        averageUnitPrice,
      ];
}

class CustomerProductPriceHabit extends Equatable {
  const CustomerProductPriceHabit({
    this.productId,
    required this.productName,
    required this.recentPrices,
    required this.usualPrice,
  });

  final int? productId;
  final String productName;
  final List<int> recentPrices;
  final int usualPrice;

  @override
  List<Object?> get props => [productId, productName, recentPrices, usualPrice];
}

class CategorySalesSummary extends Equatable {
  const CategorySalesSummary({
    this.categoryId,
    required this.categoryName,
    required this.productCount,
    required this.quantitySold,
    required this.revenue,
  });

  final int? categoryId;
  final String categoryName;
  final int productCount;
  final double quantitySold;
  final int revenue;

  @override
  List<Object?> get props => [
        categoryId,
        categoryName,
        productCount,
        quantitySold,
        revenue,
      ];
}

class MarginProductLine extends Equatable {
  const MarginProductLine({
    this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
    required this.estimatedCost,
    required this.estimatedProfit,
  });

  final int? productId;
  final String productName;
  final double quantitySold;
  final int revenue;
  final int estimatedCost;
  final int estimatedProfit;

  double get marginPercent =>
      revenue > 0 ? (estimatedProfit / revenue) * 100 : 0;

  @override
  List<Object?> get props => [
        productId,
        productName,
        quantitySold,
        revenue,
        estimatedCost,
        estimatedProfit,
      ];
}

class MarginSummary extends Equatable {
  const MarginSummary({
    required this.totalRevenue,
    required this.totalCost,
    required this.estimatedProfit,
    required this.linesWithCost,
    required this.totalLines,
    required this.topProducts,
  });

  const MarginSummary.empty()
      : totalRevenue = 0,
        totalCost = 0,
        estimatedProfit = 0,
        linesWithCost = 0,
        totalLines = 0,
        topProducts = const [];

  final int totalRevenue;
  final int totalCost;
  final int estimatedProfit;
  final int linesWithCost;
  final int totalLines;
  final List<MarginProductLine> topProducts;

  double get marginPercent =>
      totalRevenue > 0 ? (estimatedProfit / totalRevenue) * 100 : 0;

  bool get hasCostData => linesWithCost > 0;

  @override
  List<Object?> get props => [
        totalRevenue,
        totalCost,
        estimatedProfit,
        linesWithCost,
        totalLines,
        topProducts,
      ];
}

class PriceDeviationLine extends Equatable {
  const PriceDeviationLine({
    required this.saleId,
    required this.soldAt,
    this.productId,
    required this.productName,
    this.catalogPrice,
    required this.unitPrice,
    required this.discountAmount,
    this.sellerName,
  });

  final int saleId;
  final int soldAt;
  final int? productId;
  final String productName;
  final int? catalogPrice;
  final int unitPrice;
  final int discountAmount;
  final String? sellerName;

  int? get priceDelta =>
      catalogPrice != null ? unitPrice - catalogPrice! : null;

  @override
  List<Object?> get props => [
        saleId,
        soldAt,
        productId,
        productName,
        catalogPrice,
        unitPrice,
        discountAmount,
        sellerName,
      ];
}

class SalesTrendPoint extends Equatable {
  const SalesTrendPoint({
    required this.bucketStartMs,
    required this.label,
    required this.revenue,
    required this.saleCount,
    required this.quantitySold,
  });

  final int bucketStartMs;
  final String label;
  final int revenue;
  final int saleCount;
  final double quantitySold;

  @override
  List<Object?> get props => [
        bucketStartMs,
        label,
        revenue,
        saleCount,
        quantitySold,
      ];
}

class SalesTrendSummary extends Equatable {
  const SalesTrendSummary({
    required this.points,
    required this.totalRevenue,
    required this.totalSaleCount,
  });

  const SalesTrendSummary.empty()
      : points = const [],
        totalRevenue = 0,
        totalSaleCount = 0;

  final List<SalesTrendPoint> points;
  final int totalRevenue;
  final int totalSaleCount;

  @override
  List<Object?> get props => [points, totalRevenue, totalSaleCount];
}
