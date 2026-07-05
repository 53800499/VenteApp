class SalesAnalysisApiDto {
  const SalesAnalysisApiDto({
    required this.shopId,
    required this.period,
    required this.empty,
    this.emptyMessage,
    required this.categories,
    this.margins,
    required this.priceDeviations,
    required this.trends,
    required this.generatedAt,
  });

  final int shopId;
  final SalesAnalysisPeriodApiDto period;
  final bool empty;
  final String? emptyMessage;
  final List<CategorySalesSummaryApiDto> categories;
  final MarginSummaryApiDto? margins;
  final List<PriceDeviationLineApiDto> priceDeviations;
  final SalesTrendSummaryApiDto trends;
  final int generatedAt;

  factory SalesAnalysisApiDto.fromJson(Map<String, dynamic> json) {
    return SalesAnalysisApiDto(
      shopId: (json['shopId'] as num).toInt(),
      period: SalesAnalysisPeriodApiDto.fromJson(
        json['period'] as Map<String, dynamic>,
      ),
      empty: json['empty'] as bool? ?? false,
      emptyMessage: json['emptyMessage'] as String?,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CategorySalesSummaryApiDto.fromJson)
          .toList(),
      margins: json['margins'] is Map<String, dynamic>
          ? MarginSummaryApiDto.fromJson(
              json['margins'] as Map<String, dynamic>,
            )
          : null,
      priceDeviations: (json['priceDeviations'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PriceDeviationLineApiDto.fromJson)
          .toList(),
      trends: SalesTrendSummaryApiDto.fromJson(
        json['trends'] as Map<String, dynamic>,
      ),
      generatedAt: (json['generatedAt'] as num).toInt(),
    );
  }
}

class SalesAnalysisPeriodApiDto {
  const SalesAnalysisPeriodApiDto({
    required this.preset,
    required this.label,
    required this.fromMs,
    required this.toMs,
  });

  final String preset;
  final String label;
  final int fromMs;
  final int toMs;

  factory SalesAnalysisPeriodApiDto.fromJson(Map<String, dynamic> json) {
    return SalesAnalysisPeriodApiDto(
      preset: json['preset'] as String? ?? 'month',
      label: json['label'] as String? ?? '',
      fromMs: (json['fromMs'] as num).toInt(),
      toMs: (json['toMs'] as num).toInt(),
    );
  }
}

class CategorySalesSummaryApiDto {
  const CategorySalesSummaryApiDto({
    this.categoryId,
    required this.categoryName,
    required this.productCount,
    required this.quantitySold,
    required this.revenue,
  });

  final int? categoryId;
  final String categoryName;
  final int productCount;
  final num quantitySold;
  final int revenue;

  factory CategorySalesSummaryApiDto.fromJson(Map<String, dynamic> json) {
    return CategorySalesSummaryApiDto(
      categoryId: (json['categoryId'] as num?)?.toInt(),
      categoryName: json['categoryName'] as String? ?? 'Sans catégorie',
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
      quantitySold: json['quantitySold'] as num? ?? 0,
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
    );
  }
}

class MarginSummaryApiDto {
  const MarginSummaryApiDto({
    required this.totalRevenue,
    required this.totalCost,
    required this.estimatedProfit,
    required this.linesWithCost,
    required this.totalLines,
    required this.topProducts,
  });

  final int totalRevenue;
  final int totalCost;
  final int estimatedProfit;
  final int linesWithCost;
  final int totalLines;
  final List<MarginProductLineApiDto> topProducts;

  factory MarginSummaryApiDto.fromJson(Map<String, dynamic> json) {
    return MarginSummaryApiDto(
      totalRevenue: (json['totalRevenue'] as num?)?.toInt() ?? 0,
      totalCost: (json['totalCost'] as num?)?.toInt() ?? 0,
      estimatedProfit: (json['estimatedProfit'] as num?)?.toInt() ?? 0,
      linesWithCost: (json['linesWithCost'] as num?)?.toInt() ?? 0,
      totalLines: (json['totalLines'] as num?)?.toInt() ?? 0,
      topProducts: (json['topProducts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MarginProductLineApiDto.fromJson)
          .toList(),
    );
  }
}

class MarginProductLineApiDto {
  const MarginProductLineApiDto({
    this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
    required this.estimatedCost,
    required this.estimatedProfit,
  });

  final int? productId;
  final String productName;
  final num quantitySold;
  final int revenue;
  final int estimatedCost;
  final int estimatedProfit;

  factory MarginProductLineApiDto.fromJson(Map<String, dynamic> json) {
    return MarginProductLineApiDto(
      productId: (json['productId'] as num?)?.toInt(),
      productName: json['productName'] as String? ?? '',
      quantitySold: json['quantitySold'] as num? ?? 0,
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      estimatedCost: (json['estimatedCost'] as num?)?.toInt() ?? 0,
      estimatedProfit: (json['estimatedProfit'] as num?)?.toInt() ?? 0,
    );
  }
}

class PriceDeviationLineApiDto {
  const PriceDeviationLineApiDto({
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

  factory PriceDeviationLineApiDto.fromJson(Map<String, dynamic> json) {
    return PriceDeviationLineApiDto(
      saleId: (json['saleId'] as num).toInt(),
      soldAt: (json['soldAt'] as num).toInt(),
      productId: (json['productId'] as num?)?.toInt(),
      productName: json['productName'] as String? ?? '',
      catalogPrice: (json['catalogPrice'] as num?)?.toInt(),
      unitPrice: (json['unitPrice'] as num).toInt(),
      discountAmount: (json['discountAmount'] as num?)?.toInt() ?? 0,
      sellerName: json['sellerName'] as String?,
    );
  }
}

class SalesTrendSummaryApiDto {
  const SalesTrendSummaryApiDto({
    required this.points,
    required this.totalRevenue,
    required this.totalSaleCount,
  });

  final List<SalesTrendPointApiDto> points;
  final int totalRevenue;
  final int totalSaleCount;

  factory SalesTrendSummaryApiDto.fromJson(Map<String, dynamic> json) {
    return SalesTrendSummaryApiDto(
      points: (json['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SalesTrendPointApiDto.fromJson)
          .toList(),
      totalRevenue: (json['totalRevenue'] as num?)?.toInt() ?? 0,
      totalSaleCount: (json['totalSaleCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class SalesTrendPointApiDto {
  const SalesTrendPointApiDto({
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
  final num quantitySold;

  factory SalesTrendPointApiDto.fromJson(Map<String, dynamic> json) {
    return SalesTrendPointApiDto(
      bucketStartMs: (json['bucketStartMs'] as num).toInt(),
      label: json['label'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      quantitySold: json['quantitySold'] as num? ?? 0,
    );
  }
}
