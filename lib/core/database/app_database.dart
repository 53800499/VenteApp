import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/time.dart';
import 'tables/auth_tables.dart';
import 'tables/commerce_tables.dart';
import 'tables/cash_session_tables.dart';
import 'tables/expense_tables.dart';
import 'tables/notification_tables.dart';
import 'tables/sync_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Shops,
  Users,
  Settings,
  AuthSessions,
  AuditLogs,
  Categories,
  Products,
  Customers,
  Sales,
  SaleItems,
  Debts,
  StockMovements,
  SyncQueue,
  NotificationDailyStates,
  CustomerProductPrices,
  ExpenseCategories,
  Expenses,
  ExpenseAttachments,
  ExpenseHistoryEntries,
  CategoryBudgets,
  CashSessions,
  CashMovements,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await _backfillNotificationSettingsColumns();
        },
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(products);
            await m.createTable(customers);
            await m.createTable(sales);
            await m.createTable(saleItems);
            await m.createTable(debts);
          }
          if (from < 3) {
            await m.createTable(categories);
            await m.createTable(stockMovements);
            await m.addColumn(products, products.categoryId);
            await m.addColumn(products, products.sku);
            await _seedDefaultCategories(this);
          }
          if (from < 4) {
            await m.addColumn(sales, sales.receiptNumber);
            await m.addColumn(sales, sales.saleType);
            await m.addColumn(sales, sales.subtotal);
            await m.addColumn(sales, sales.discountAmount);
            await m.addColumn(sales, sales.amountPaid);
            await m.addColumn(sales, sales.paymentMethod);
            await m.addColumn(sales, sales.note);
            await m.addColumn(sales, sales.updatedAt);
            await m.addColumn(sales, sales.cancelledByUserId);
            await m.addColumn(sales, sales.cancelReason);
            await m.addColumn(sales, sales.serverId);
            await m.addColumn(sales, sales.syncedAt);
            await m.addColumn(sales, sales.syncStatus);
            await m.addColumn(saleItems, saleItems.discountAmount);
          }
          if (from < 5) {
            await m.addColumn(products, products.serverId);
            await m.addColumn(products, products.syncedAt);
            await m.addColumn(customers, customers.serverId);
            await m.addColumn(customers, customers.syncedAt);
          }
          if (from < 6) {
            await m.addColumn(customers, customers.note);
          }
          if (from < 7) {
            await m.addColumn(debts, debts.serverId);
            await m.addColumn(debts, debts.syncedAt);
            await m.addColumn(debts, debts.updatedAt);
          }
          if (from < 8) {
            await m.createTable(syncQueue);
          }
          if (from < 9) {
            await m.addColumn(
              settings,
              settings.enableBackupReminder,
            );
            await m.addColumn(
              settings,
              settings.enableGoodDayAlert,
            );
            await m.createTable(notificationDailyStates);
            await _backfillNotificationSettingsColumns();
          }
          if (from < 10) {
            await m.addColumn(customers, customers.isShared);
          }
          if (from < 11) {
            await m.addColumn(customers, customers.address);
          }
          if (from < 12) {
            await customStatement(
              'UPDATE settings SET cloud_sync_enabled = 1 '
              'WHERE cloud_sync_enabled = 0',
            );
          }
          if (from < 13) {
            await m.addColumn(products, products.priceSemiWholesale);
            await m.addColumn(products, products.priceWholesale);
            await m.addColumn(settings, settings.pricingTiersEnabled);
            await m.createTable(customerProductPrices);
          }
          if (from < 14) {
            await _addColumnIfMissing(m, categories, categories.description);
          }
          if (from < 15) {
            await m.createTable(expenseCategories);
            await m.createTable(expenses);
            await m.createTable(expenseAttachments);
            await m.createTable(expenseHistoryEntries);
            await m.createTable(categoryBudgets);
          }
          if (from < 16) {
            await m.createTable(cashSessions);
            await m.createTable(cashMovements);
          }
        },
      );

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    final exists = rows.any((row) => row.read<String>('name') == column.name);
    if (!exists) {
      await m.addColumn(table, column);
    }
  }

  Future<void> _backfillNotificationSettingsColumns() async {
    await customStatement(
      'UPDATE settings SET enable_backup_reminder = 1 '
      'WHERE enable_backup_reminder IS NULL',
    );
    await customStatement(
      'UPDATE settings SET enable_good_day_alert = 1 '
      'WHERE enable_good_day_alert IS NULL',
    );
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'venteapp.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

Future<void> _seedDefaultCategories(AppDatabase db) async {
  final shops = await db.select(db.shops).get();
  final timestamp = nowMs();

  for (final shop in shops) {
    final existing = await (db.select(db.categories)
          ..where(
            (c) => c.shopId.equals(shop.id) & c.name.equals('Général'),
          ))
        .getSingleOrNull();

    final categoryId = existing?.id ??
        await db.into(db.categories).insert(
              CategoriesCompanion.insert(
                shopId: shop.id,
                name: 'Général',
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );

    await (db.update(db.products)
          ..where(
            (p) => p.shopId.equals(shop.id) & p.categoryId.isNull(),
          ))
        .write(ProductsCompanion(categoryId: Value(categoryId)));
  }
}
