import 'package:flutter_test/flutter_test.dart';

import 'package:venteapp/features/sales_analysis/data/mappers/sales_analysis_mapper.dart';
import 'package:venteapp/features/sales_analysis/data/models/sales_analysis_api_models.dart';

void main() {
  group('SalesAnalysisMapper', () {
    test('mappe la réponse API vers le bundle domaine', () {
      const dto = SalesAnalysisApiDto(
        shopId: 1,
        period: SalesAnalysisPeriodApiDto(
          preset: 'month',
          label: 'Mois en cours',
          fromMs: 1000,
          toMs: 2000,
        ),
        empty: false,
        categories: [
          CategorySalesSummaryApiDto(
            categoryId: 3,
            categoryName: 'Boissons',
            productCount: 2,
            quantitySold: 10,
            revenue: 50000,
          ),
        ],
        margins: MarginSummaryApiDto(
          totalRevenue: 50000,
          totalCost: 30000,
          estimatedProfit: 20000,
          linesWithCost: 5,
          totalLines: 6,
          topProducts: [
            MarginProductLineApiDto(
              productId: 1,
              productName: 'Eau',
              quantitySold: 10,
              revenue: 50000,
              estimatedCost: 30000,
              estimatedProfit: 20000,
            ),
          ],
        ),
        priceDeviations: [
          PriceDeviationLineApiDto(
            saleId: 42,
            soldAt: 1500,
            productId: 1,
            productName: 'Eau',
            catalogPrice: 500,
            unitPrice: 450,
            discountAmount: 0,
            sellerName: 'Alice',
          ),
        ],
        trends: SalesTrendSummaryApiDto(
          points: [
            SalesTrendPointApiDto(
              bucketStartMs: 1000,
              label: '2026-06-01',
              revenue: 50000,
              saleCount: 3,
              quantitySold: 10,
            ),
          ],
          totalRevenue: 50000,
          totalSaleCount: 3,
        ),
        generatedAt: 9999,
      );

      final bundle = SalesAnalysisMapper.fromApi(dto);

      expect(bundle.categories, hasLength(1));
      expect(bundle.categories.first.categoryName, 'Boissons');
      expect(bundle.margins?.estimatedProfit, 20000);
      expect(bundle.priceDeviations.first.unitPrice, 450);
      expect(bundle.trends.totalSaleCount, 3);
    });

    test('fromJson parse une réponse serveur typique', () {
      final dto = SalesAnalysisApiDto.fromJson({
        'shopId': 1,
        'period': {
          'preset': 'week',
          'label': '7 derniers jours',
          'fromMs': 100,
          'toMs': 200,
        },
        'empty': true,
        'emptyMessage': 'Aucune vente sur cette période.',
        'categories': [],
        'priceDeviations': [],
        'trends': {
          'points': [],
          'totalRevenue': 0,
          'totalSaleCount': 0,
        },
        'generatedAt': 1,
      });

      expect(dto.empty, isTrue);
      expect(dto.margins, isNull);
    });
  });
}
