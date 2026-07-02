import '../../domain/entities/report_entities.dart';
import '../models/report_api_models.dart';

class ReportMapper {
  const ReportMapper._();

  static Report fromApi(ReportApiDto dto) {
    return Report(
      shopId: dto.shopId,
      shopIds: dto.shopIds,
      consolidated: dto.consolidated,
      period: ReportPeriod(
        preset: parseReportPeriodPreset(dto.period.preset),
        label: dto.period.label,
        fromMs: dto.period.fromMs,
        toMs: dto.period.toMs,
      ),
      empty: dto.empty,
      emptyMessage: dto.emptyMessage,
      sales: ReportSalesKpis(
        grossRevenue: dto.sales.grossRevenue,
        collectedRevenue: dto.sales.collectedRevenue,
        creditGranted: dto.sales.creditGranted,
        saleCount: dto.sales.saleCount,
        averageBasket: dto.sales.averageBasket,
        totalCash: dto.sales.totalCash,
        totalMomo: dto.sales.totalMomo,
        totalCredit: dto.sales.totalCredit,
      ),
      financial: dto.financial == null
          ? null
          : ReportFinancialKpis(
              estimatedProfit: dto.financial!.estimatedProfit,
              profitAvailable: dto.financial!.profitAvailable,
              profitWarning: dto.financial!.profitWarning,
              recoveryRate: dto.financial!.recoveryRate,
              recoveryRateAvailable: dto.financial!.recoveryRateAvailable,
              debtsCreatedAmount: dto.financial!.debtsCreatedAmount,
              debtsRepaidAmount: dto.financial!.debtsRepaidAmount,
            ),
      topProducts: dto.topProducts
          .map(
            (p) => ReportTopProduct(
              rank: p.rank,
              productId: p.productId,
              productName: p.productName,
              quantitySold: p.quantitySold,
              revenue: p.revenue,
            ),
          )
          .toList(),
      sellerPerformance: dto.sellerPerformance
          ?.map(
            (s) => ReportSellerPerformance(
              userId: s.userId,
              userName: s.userName,
              saleCount: s.saleCount,
              totalRevenue: s.totalRevenue,
            ),
          )
          .toList(),
      generatedAt: dto.generatedAt,
    );
  }
}
