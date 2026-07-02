import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:venteapp/core/database/app_database.dart';
import 'package:venteapp/shared/enums/permission.dart';
import 'package:venteapp/core/utils/benin_day_range.dart';
import 'package:venteapp/core/utils/time.dart';
import 'package:venteapp/features/dashboard/data/datasources/local/dashboard_local_datasource.dart';
import 'package:venteapp/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/auth_test_helpers.dart';

void main() {
  late AppDatabase database;
  late DashboardRepositoryImpl repository;
  late int shopId;
  late int userId;
  late int customerId;

  setUp(() async {
    database = createTestDatabase();
    repository = DashboardRepositoryImpl(
      localDatasource: DashboardLocalDatasource(database),
    );

    final timestamp = nowMs();
    final range = getBeninDayBounds(timestamp);

    shopId = await database.into(database.shops).insert(
          ShopsCompanion.insert(
            name: const Value('Boutique Test'),
            createdAt: timestamp,
          ),
        );
    userId = await database.into(database.users).insert(
          UsersCompanion.insert(
            shopId: shopId,
            name: 'Patron',
            pinHash: 'hash',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    await database.into(database.settings).insert(
          SettingsCompanion.insert(
            shopId: shopId,
            shopName: const Value('Boutique Test'),
            defaultAlertThreshold: const Value(5),
            updatedAt: timestamp,
          ),
        );
    customerId = await database.into(database.customers).insert(
          CustomersCompanion.insert(
            shopId: shopId,
            name: 'Client A',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );

    final saleId = await database.into(database.sales).insert(
          SalesCompanion.insert(
            shopId: shopId,
            userId: userId,
            customerId: Value(customerId),
            totalAmount: 15000,
            amountCash: const Value(10000),
            amountMomo: const Value(5000),
            createdAt: range.dayEndMs - 3600000,
          ),
        );

    await database.into(database.saleItems).insert(
          SaleItemsCompanion.insert(
            shopId: shopId,
            saleId: saleId,
            productName: 'Riz',
            quantity: 2,
            unitPrice: 5000,
            unitCost: const Value(3000),
            lineTotal: 10000,
            createdAt: range.dayEndMs - 3600000,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            shopId: shopId,
            name: 'Huile',
            quantityInStock: const Value(2),
            alertThreshold: const Value(5),
            priceSell: 2500,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );

    await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customerId,
            originalAmount: 8000,
            amountRemaining: 5000,
            createdAt: timestamp,
          ),
        );

    // Vente annulée — exclue [RG-DB-02]
    await database.into(database.sales).insert(
          SalesCompanion.insert(
            shopId: shopId,
            userId: userId,
            totalAmount: 99999,
            status: const Value('cancelled'),
            createdAt: range.dayEndMs - 1000,
          ),
        );
  });

  tearDown(() async {
    try {
      await database.close();
    } on Object {
      // ignore
    }
  });

  test('agrège les KPI du jour pour le patron', () async {
    final data = await repository.getDashboard(
      shopId: shopId,
      permissions: Permission.values.toSet(),
    );

    expect(data.kpis.totalRevenue, 15000);
    expect(data.kpis.saleCount, 1);
    expect(data.kpis.lowStockCount, 1);
    expect(data.kpis.debtorCount, 1);
    expect(data.financial, isNotNull);
    expect(data.financial!.estimatedProfit, 4000);
    expect(data.financial!.totalDebt, 5000);
    expect(data.recentSales, hasLength(1));
    expect(data.recentSales.first.customerName, 'Client A');
  });

  test('masque les données financières sans permission', () async {
    final data = await repository.getDashboard(
      shopId: shopId,
      permissions: const {Permission.dashboardRead},
    );

    expect(data.kpis.totalRevenue, 15000);
    expect(data.financial, isNull);
  });

  test('retourne 0 FCFA sans vente du jour (RG-DB-05)', () async {
    await database.delete(database.sales).go();

    final data = await repository.getDashboard(
      shopId: shopId,
      permissions: Permission.values.toSet(),
    );

    expect(data.kpis.totalRevenue, 0);
    expect(data.kpis.saleCount, 0);
    expect(data.recentSales, isEmpty);
  });
}
