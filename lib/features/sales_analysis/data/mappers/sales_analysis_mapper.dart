import '../../domain/entities/sales_analysis_entities.dart';
import '../models/sales_analysis_api_models.dart';

class SalesAnalysisRemoteBundle {
  const SalesAnalysisRemoteBundle({
    required this.categories,
    this.margins,
    required this.priceDeviations,
    required this.trends,
  });

  final List<CategorySalesSummary> categories;
  final MarginSummary? margins;
  final List<PriceDeviationLine> priceDeviations;
  final SalesTrendSummary trends;
}

class SalesAnalysisMapper {
  const SalesAnalysisMapper._();

  static SalesAnalysisRemoteBundle fromApi(SalesAnalysisApiDto dto) {
    return SalesAnalysisRemoteBundle(
      categories: dto.categories.map(_category).toList(),
      margins: dto.margins != null ? _margins(dto.margins!) : null,
      priceDeviations: dto.priceDeviations.map(_priceDeviation).toList(),
      trends: _trends(dto.trends),
    );
  }

  static CategorySalesSummary _category(CategorySalesSummaryApiDto dto) {
    return CategorySalesSummary(
      categoryId: dto.categoryId,
      categoryName: dto.categoryName,
      productCount: dto.productCount,
      quantitySold: dto.quantitySold.toDouble(),
      revenue: dto.revenue,
    );
  }

  static MarginSummary _margins(MarginSummaryApiDto dto) {
    return MarginSummary(
      totalRevenue: dto.totalRevenue,
      totalCost: dto.totalCost,
      estimatedProfit: dto.estimatedProfit,
      linesWithCost: dto.linesWithCost,
      totalLines: dto.totalLines,
      topProducts: dto.topProducts.map(_marginLine).toList(),
    );
  }

  static MarginProductLine _marginLine(MarginProductLineApiDto dto) {
    return MarginProductLine(
      productId: dto.productId,
      productName: dto.productName,
      quantitySold: dto.quantitySold.toDouble(),
      revenue: dto.revenue,
      estimatedCost: dto.estimatedCost,
      estimatedProfit: dto.estimatedProfit,
    );
  }

  static PriceDeviationLine _priceDeviation(PriceDeviationLineApiDto dto) {
    return PriceDeviationLine(
      saleId: dto.saleId,
      soldAt: dto.soldAt,
      productId: dto.productId,
      productName: dto.productName,
      catalogPrice: dto.catalogPrice,
      unitPrice: dto.unitPrice,
      discountAmount: dto.discountAmount,
      sellerName: dto.sellerName,
    );
  }

  static SalesTrendSummary _trends(SalesTrendSummaryApiDto dto) {
    return SalesTrendSummary(
      points: dto.points.map(_trendPoint).toList(),
      totalRevenue: dto.totalRevenue,
      totalSaleCount: dto.totalSaleCount,
    );
  }

  static SalesTrendPoint _trendPoint(SalesTrendPointApiDto dto) {
    return SalesTrendPoint(
      bucketStartMs: dto.bucketStartMs,
      label: dto.label,
      revenue: dto.revenue,
      saleCount: dto.saleCount,
      quantitySold: dto.quantitySold.toDouble(),
    );
  }
}
