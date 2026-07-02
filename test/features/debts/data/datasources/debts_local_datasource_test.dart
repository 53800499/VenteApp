import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/database/app_database.dart';
import 'package:venteapp/core/utils/time.dart';
import 'package:venteapp/features/debts/data/datasources/local/debts_local_datasource.dart';
import 'package:venteapp/features/debts/domain/entities/debt_entities.dart';

import '../../../../support/auth_test_helpers.dart';

void main() {
  late AppDatabase database;
  late DebtsLocalDatasource datasource;
  late int shopId;
  late int customerId;

  setUp(() async {
    database = createTestDatabase();
    datasource = DebtsLocalDatasource(database);

    final timestamp = nowMs();
    shopId = await database.into(database.shops).insert(
          ShopsCompanion.insert(
            name: const Value('Boutique Test'),
            createdAt: timestamp,
          ),
        );

    customerId = await database.into(database.customers).insert(
          CustomersCompanion.insert(
            shopId: shopId,
            name: 'Client Test',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  });

  test('liste les dettes ouvertes d\'un client', () async {
    final timestamp = nowMs();
    await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customerId,
            originalAmount: 8000,
            amountRemaining: 8000,
            createdAt: timestamp,
          ),
        );

    final debts = await datasource.listCustomerDebts(
      shopId: shopId,
      customerId: customerId,
    );

    expect(debts, hasLength(1));
    expect(debts.first.amountRemaining, 8000);
    expect(debts.first.isRepayable, isTrue);
  });

  test('enregistre un paiement partiel', () async {
    final timestamp = nowMs();
    final debtId = await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customerId,
            originalAmount: 10000,
            amountRemaining: 10000,
            createdAt: timestamp,
          ),
        );

    final result = await datasource.recordPayment(
      shopId: shopId,
      debtId: debtId,
      amount: 4000,
      newStatus: DebtStatus.partial,
    );

    expect(result.amount, 4000);
    expect(result.amountRemaining, 6000);
    expect(result.status, DebtStatus.partial);

    final updated = await datasource.findDebt(shopId, debtId);
    expect(updated?.amountPaid, 4000);
    expect(updated?.amountRemaining, 6000);
  });

  test('solde une dette après paiement total', () async {
    final timestamp = nowMs();
    final debtId = await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customerId,
            originalAmount: 5000,
            amountRemaining: 5000,
            createdAt: timestamp,
          ),
        );

    await datasource.recordPayment(
      shopId: shopId,
      debtId: debtId,
      amount: 5000,
      newStatus: DebtStatus.paid,
    );

    final debts = await datasource.listCustomerDebts(
      shopId: shopId,
      customerId: customerId,
      openOnly: true,
    );
    expect(debts, isEmpty);
  });

  test('pardonne une dette et journalise l\'audit', () async {
    final timestamp = nowMs();
    final userId = await database.into(database.users).insert(
          UsersCompanion.insert(
            shopId: shopId,
            name: 'Patron',
            pinHash: 'hash',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    final debtId = await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customerId,
            originalAmount: 12000,
            amountRemaining: 12000,
            createdAt: timestamp,
          ),
        );

    const reason = 'Client fidèle depuis 5 ans';
    final forgiven = await datasource.forgiveDebt(
      shopId: shopId,
      debtId: debtId,
      userId: userId,
      reason: reason,
    );

    expect(forgiven.status, DebtStatus.forgiven);
    expect(forgiven.amountRemaining, 0);

    final debts = await datasource.listCustomerDebts(
      shopId: shopId,
      customerId: customerId,
      openOnly: true,
    );
    expect(debts, isEmpty);

    final auditRows = await database.select(database.auditLogs).get();
    expect(auditRows, hasLength(1));
    expect(auditRows.first.action, 'debt_forgiven');
    expect(auditRows.first.module, 'debts');
    expect(auditRows.first.entityId, debtId);
    expect(auditRows.first.reason, reason);
  });

  test('liste les dettes pardonnées avec motif et montant annulé', () async {
    final timestamp = nowMs();
    final userId = await database.into(database.users).insert(
          UsersCompanion.insert(
            shopId: shopId,
            name: 'Patron',
            pinHash: 'hash',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    final debtId = await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customerId,
            originalAmount: 15000,
            amountPaid: const Value(3000),
            amountRemaining: 12000,
            status: const Value('partial'),
            createdAt: timestamp,
          ),
        );

    const reason = 'Client en difficulté temporaire';
    await datasource.forgiveDebt(
      shopId: shopId,
      debtId: debtId,
      userId: userId,
      reason: reason,
    );

    final entries = await datasource.listForgivenDebts(shopId: shopId);
    expect(entries, hasLength(1));
    expect(entries.first.customerName, 'Client Test');
    expect(entries.first.forgiveness.reason, reason);
    expect(entries.first.forgiveness.forgivenAmount, 12000);
    expect(entries.first.forgiveness.forgivenByName, 'Patron');
    expect(entries.first.debt.status, DebtStatus.forgiven);

    final filtered = await datasource.listForgivenDebts(
      shopId: shopId,
      customerId: customerId,
    );
    expect(filtered, hasLength(1));

    final info = await datasource.getDebtForgivenessInfo(
      shopId: shopId,
      debtId: debtId,
    );
    expect(info?.forgivenAmount, 12000);
    expect(info?.reason, reason);
  });

  test('liste l\'historique des remboursements via l\'audit', () async {
    final timestamp = nowMs();
    final userId = await database.into(database.users).insert(
          UsersCompanion.insert(
            shopId: shopId,
            name: 'Vendeur',
            pinHash: 'hash',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    final debtId = await database.into(database.debts).insert(
          DebtsCompanion.insert(
            shopId: shopId,
            customerId: customerId,
            originalAmount: 10000,
            amountRemaining: 10000,
            createdAt: timestamp,
          ),
        );

    await datasource.recordPaymentWithAudit(
      shopId: shopId,
      debtId: debtId,
      userId: userId,
      amount: 3000,
      method: DebtRepaymentMethod.cash,
      newStatus: DebtStatus.partial,
    );

    final history = await datasource.listPaymentHistory(
      shopId: shopId,
      debtId: debtId,
    );

    expect(history, hasLength(1));
    expect(history.first.amount, 3000);
    expect(history.first.method, DebtRepaymentMethod.cash);
    expect(history.first.userName, 'Vendeur');
  });
}
