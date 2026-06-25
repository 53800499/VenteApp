import 'package:frontend/core/utils/benin_day_range.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_entities.dart';
import 'package:frontend/features/dashboard/domain/services/dashboard_aggregation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DashboardAggregationService service;

  setUp(() {
    service = DashboardAggregationService();
  });

  test('retourne 0 FCFA si aucune vente (RG-DB-05)', () {
    final stats = service.aggregateSales([]);
    expect(stats.totalRevenue, 0);
    expect(stats.saleCount, 0);
  });

  test('agrège CA, cash, momo et crédit', () {
    const sales = [
      TodaySaleRow(
        id: 1,
        totalAmount: 10000,
        amountCash: 7000,
        amountMomo: 3000,
        amountCredit: 0,
        createdAt: 1,
      ),
      TodaySaleRow(
        id: 2,
        totalAmount: 5000,
        amountCash: 0,
        amountMomo: 0,
        amountCredit: 5000,
        createdAt: 2,
        customerId: 1,
        customerName: 'Client',
      ),
    ];

    final stats = service.aggregateSales(sales);
    expect(stats.totalRevenue, 15000);
    expect(stats.saleCount, 2);
    expect(stats.totalCredit, 5000);
  });

  test('masque le bénéfice sans prix d\'achat (RG-DB-06)', () {
    const stats = DashboardSalesStats(
      totalRevenue: 0,
      saleCount: 0,
      totalCash: 0,
      totalMomo: 0,
      totalCredit: 0,
    );
    final financial = service.aggregateFinancial(
      salesStats: stats,
      profitLines: const [
        SaleProfitRow(quantity: 2, unitPrice: 1000, unitCost: null),
      ],
      debts: const DashboardDebtStats(debtorCount: 0, totalDebt: 0),
    );

    expect(financial.estimatedProfit, isNull);
    expect(financial.profitAvailable, isFalse);
    expect(financial.profitWarning, isNotNull);
  });

  test('calcule le bénéfice estimé avec coûts', () {
    const stats = DashboardSalesStats(
      totalRevenue: 0,
      saleCount: 0,
      totalCash: 0,
      totalMomo: 0,
      totalCredit: 0,
    );
    final financial = service.aggregateFinancial(
      salesStats: stats,
      profitLines: const [
        SaleProfitRow(quantity: 2, unitPrice: 1000, unitCost: 600),
        SaleProfitRow(quantity: 1, unitPrice: 500, unitCost: 200),
      ],
      debts: const DashboardDebtStats(debtorCount: 1, totalDebt: 3000),
    );

    expect(financial.estimatedProfit, 1100);
    expect(financial.profitAvailable, isTrue);
    expect(financial.totalDebt, 3000);
  });

  test('getBeninDayBounds couvre la journée jusqu\'à maintenant', () {
    const now = 1_704_067_200_000; // 2024-01-01 00:00 UTC = 01:00 Bénin
    final range = getBeninDayBounds(now);

    expect(range.dayEndMs, now);
    expect(range.dayStartMs, lessThan(now));
    expect(now - range.dayStartMs, lessThanOrEqualTo(86400000));
  });
}
