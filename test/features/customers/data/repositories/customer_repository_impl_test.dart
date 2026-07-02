import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/database/app_database.dart';
import 'package:venteapp/core/utils/time.dart';
import 'package:venteapp/features/customers/data/datasources/local/customers_local_datasource.dart';
import 'package:venteapp/features/customers/domain/entities/customer_entities.dart';

import '../../../../support/auth_test_helpers.dart';

void main() {
  late AppDatabase database;
  late CustomersLocalDatasource datasource;
  late int shopId;

  setUp(() async {
    database = createTestDatabase();
    datasource = CustomersLocalDatasource(database);

    final timestamp = nowMs();
    shopId = await database.into(database.shops).insert(
          ShopsCompanion.insert(
            name: const Value('Boutique Test'),
            createdAt: timestamp,
          ),
        );
  });

  test('insère et retrouve un client', () async {
    final customer = await datasource.insertCustomer(
      shopId: shopId,
      name: 'Afi Koffi',
      phone: '+22990123456',
    );

    final found = await datasource.findCustomer(shopId, customer.id);
    expect(found?.name, 'Afi Koffi');
    expect(found?.phone, '+22990123456');
  });

  test('calcule le solde dû depuis les dettes ouvertes', () async {
    final customer = await datasource.insertCustomer(
      shopId: shopId,
      name: 'Débiteur',
    );

    final timestamp = nowMs();
    await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customer.id,
            originalAmount: 5000,
            amountRemaining: 5000,
            createdAt: timestamp,
          ),
        );

    final customers = await datasource.listCustomers(
      shopId: shopId,
      filters: const CustomerListFilters(hasDebtOnly: true),
    );

    expect(customers, hasLength(1));
    expect(customers.first.balanceDue, 5000);
    expect(customers.first.openDebtsCount, 1);
  });

  test('agrège les débiteurs', () async {
    final customer = await datasource.insertCustomer(
      shopId: shopId,
      name: 'Client Dette',
    );

    final timestamp = nowMs();
    await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customer.id,
            originalAmount: 3000,
            amountRemaining: 3000,
            createdAt: timestamp,
          ),
        );

    final overview = await datasource.listDebtors(shopId: shopId);
    expect(overview.debtorCount, 1);
    expect(overview.totalDebt, 3000);
  });
}
