import 'package:drift/drift.dart';

import '../storage/database_key_storage.dart';
import '../utils/time.dart';
import '../../features/inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import 'encrypted_database_opener.dart';
import 'tables/auth_tables.dart';
import 'tables/commerce_tables.dart';
import 'tables/cash_session_tables.dart';
import 'tables/expense_tables.dart';
import 'tables/notification_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/calculator_tables.dart';
import 'tables/purchase_tables.dart';
import 'tables/inventory_lot_tables.dart';
import 'tables/product_pricing_tables.dart';
import 'tables/stock_transfer_tables.dart';
import 'tables/fx_exchange_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Shops,
  Users,
  Settings,
  AuthSessions,
  AuditLogs,
  IdentitySnapshots,
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
  TenantModules,
  CalculatorProductData,
  CalculatorHistory,
  SyncEntityCache,
  Suppliers,
  PurchaseOrders,
  PurchaseOrderItems,
  PurchaseReceipts,
  PurchaseReceiptItems,
  SupplierInvoices,
  SupplierPayments,
  PurchaseOrderHistoryEntries,
  InventoryLots,
  SaleItemLotAllocations,
  ProductPriceHistory,
  StockTransfers,
  StockTransferItems,
  StockTransferShipments,
  StockTransferLotReservations,
  StockTransferLotLines,
  StockTransferEvents,
  StockTransferDiscrepancies,
  StockTransferReceipts,
  StockTransferReceiptItems,
  FxCurrencies,
  FxShopCurrencies,
  FxRateSnapshots,
  FxSessions,
  FxSessionBalances,
  FxOperations,
  FxMovements,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase({required DatabaseKeyStorage keyStorage})
      : super(openEncryptedConnection(keyStorage));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 35;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await _backfillNotificationSettingsColumns();
          try {
            await seedFxCurrencies(this);
          } catch (_) {
            // Tables FX absentes tant que la migration 35 n'a pas tourné.
          }
        },
        onCreate: (Migrator m) async {
          await m.createAll();
          await seedFxCurrencies(this);
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
          if (from < 17) {
            await _addColumnIfMissing(m, shops, shops.parentShopId);
            await _backfillShopHierarchy(this);
          }
          if (from < 18) {
            await _addColumnIfMissing(m, users, users.pinProvisional);
          }
          if (from < 19) {
            await m.createTable(tenantModules);
            await m.createTable(calculatorProductData);
            await m.createTable(calculatorHistory);
          }
          if (from < 20) {
            await m.createTable(syncEntityCache);
          }
          if (from < 21) {
            await m.createTable(suppliers);
            await m.createTable(purchaseOrders);
            await m.createTable(purchaseOrderItems);
            await m.createTable(purchaseReceipts);
            await m.createTable(purchaseReceiptItems);
            await m.createTable(supplierInvoices);
            await m.createTable(supplierPayments);
            await m.createTable(purchaseOrderHistoryEntries);
          }
          if (from < 22) {
            await m.createTable(inventoryLots);
            await m.createTable(saleItemLotAllocations);
            await _backfillInventoryLots(this);
          }
          if (from < 23) {
            await _migrateDirectProcurementReceipts(this);
          }
          if (from < 24) {
            await _addColumnIfMissing(m, products, products.pricingMode);
            await _addColumnIfMissing(m, products, products.marginValue);
            await m.createTable(productPriceHistory);
            await _backfillProductPriceHistory(this);
          }
          if (from < 25) {
            await m.createTable(stockTransfers);
            await m.createTable(stockTransferItems);
            await m.createTable(stockTransferLotLines);
          }
          if (from < 26) {
            await _addColumnIfMissing(
              m,
              inventoryLots,
              inventoryLots.quantityReserved,
            );
            await _addColumnIfMissing(
              m,
              stockTransfers,
              stockTransfers.validatedBy,
            );
            await _addColumnIfMissing(
              m,
              stockTransfers,
              stockTransfers.validatedAt,
            );
            await m.createTable(stockTransferShipments);
            await m.createTable(stockTransferLotReservations);
            await _addColumnIfMissing(
              m,
              stockTransferLotLines,
              stockTransferLotLines.shipmentId,
            );
          }
          if (from < 27) {
            await _addColumnIfMissing(
              m,
              stockTransfers,
              stockTransfers.transferType,
            );
            await _addColumnIfMissing(
              m,
              stockTransfers,
              stockTransfers.parentTransferId,
            );
          }
          if (from < 28) {
            await _addColumnIfMissing(
              m,
              stockTransfers,
              stockTransfers.sourceShopName,
            );
            await _addColumnIfMissing(
              m,
              stockTransfers,
              stockTransfers.destinationShopName,
            );
            await customStatement('''
              UPDATE stock_transfers
              SET source_shop_name = (
                SELECT name FROM shops WHERE shops.id = stock_transfers.source_shop_id
              )
              WHERE source_shop_name IS NULL
            ''');
            await customStatement('''
              UPDATE stock_transfers
              SET destination_shop_name = (
                SELECT name FROM shops WHERE shops.id = stock_transfers.destination_shop_id
              )
              WHERE destination_shop_name IS NULL
            ''');
          }
          if (from < 29) {
            await customStatement('''
              CREATE TABLE stock_transfer_lot_lines_v29 (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                transfer_item_id INTEGER NOT NULL REFERENCES stock_transfer_items(id),
                shipment_id INTEGER REFERENCES stock_transfer_shipments(id),
                source_lot_id INTEGER REFERENCES inventory_lots(id),
                destination_lot_id INTEGER REFERENCES inventory_lots(id),
                quantity INTEGER NOT NULL,
                quantity_received INTEGER NOT NULL DEFAULT 0,
                unit_cost INTEGER NOT NULL
              )
            ''');
            await customStatement('''
              INSERT INTO stock_transfer_lot_lines_v29 (
                id,
                transfer_item_id,
                shipment_id,
                source_lot_id,
                destination_lot_id,
                quantity,
                quantity_received,
                unit_cost
              )
              SELECT
                id,
                transfer_item_id,
                shipment_id,
                source_lot_id,
                destination_lot_id,
                quantity,
                quantity_received,
                unit_cost
              FROM stock_transfer_lot_lines
            ''');
            await customStatement('DROP TABLE stock_transfer_lot_lines');
            await customStatement(
              'ALTER TABLE stock_transfer_lot_lines_v29 '
              'RENAME TO stock_transfer_lot_lines',
            );
          }
          if (from < 30) {
            await m.createTable(identitySnapshots);
          }
          if (from < 31) {
            await _addColumnIfMissing(
              m,
              stockTransferShipments,
              stockTransferShipments.reference,
            );
            await _addColumnIfMissing(
              m,
              stockTransferShipments,
              stockTransferShipments.driverName,
            );
            await _addColumnIfMissing(
              m,
              stockTransferShipments,
              stockTransferShipments.vehiclePlate,
            );
            await customStatement('''
              UPDATE stock_transfer_shipments
              SET reference = 'SHP-' || transfer_id || '-' || id
              WHERE reference IS NULL OR reference = ''
            ''');
          }
          if (from < 32) {
            await _addColumnIfMissing(
              m,
              stockTransfers,
              stockTransfers.closedBy,
            );
            await _addColumnIfMissing(
              m,
              stockTransfers,
              stockTransfers.closedAt,
            );
            await m.createTable(stockTransferEvents);
            await m.createTable(stockTransferDiscrepancies);
          }
          if (from < 33) {
            await m.createTable(stockTransferReceipts);
            await m.createTable(stockTransferReceiptItems);
          }
          if (from < 34) {
            await _addColumnIfMissing(
              m,
              stockTransferReceiptItems,
              stockTransferReceiptItems.quantityRefused,
            );
            await _addColumnIfMissing(
              m,
              stockTransferReceiptItems,
              stockTransferReceiptItems.refusalReason,
            );
            await _addColumnIfMissing(
              m,
              stockTransferReceiptItems,
              stockTransferReceiptItems.refusalResolution,
            );
          }
          if (from < 35) {
            await m.createTable(fxCurrencies);
            await m.createTable(fxShopCurrencies);
            await m.createTable(fxRateSnapshots);
            await m.createTable(fxSessions);
            await m.createTable(fxSessionBalances);
            await m.createTable(fxOperations);
            await m.createTable(fxMovements);
            await seedFxCurrencies(this);
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

}

Future<void> _backfillProductPriceHistory(AppDatabase db) async {
  final products = await db.select(db.products).get();
  final timestamp = nowMs();
  for (final product in products) {
    if (product.priceSell <= 0) continue;
    await db.into(db.productPriceHistory).insert(
          ProductPriceHistoryCompanion.insert(
            shopId: product.shopId,
            productId: product.id,
            unitCost: Value(product.priceBuy),
            priceSell: product.priceSell,
            reason: 'migration',
            createdAt: product.updatedAt > 0 ? product.updatedAt : timestamp,
          ),
        );
  }
}

Future<void> _backfillInventoryLots(AppDatabase db) async {
  final shops = await db.select(db.shops).get();
  final lotDs = InventoryLotLocalDatasource(db);
  for (final shop in shops) {
    await lotDs.backfillInitialLotsForShop(shop.id);
  }
}

Future<void> _migrateDirectProcurementReceipts(AppDatabase db) async {
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS purchase_receipts_new (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      shop_id INTEGER NOT NULL REFERENCES shops(id),
      purchase_order_id INTEGER REFERENCES purchase_orders(id),
      supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
      receipt_type TEXT NOT NULL DEFAULT 'from_order',
      receipt_number TEXT NOT NULL,
      received_at INTEGER NOT NULL,
      received_by INTEGER NOT NULL REFERENCES users(id),
      notes TEXT,
      version INTEGER NOT NULL DEFAULT 1,
      server_id TEXT,
      synced_at INTEGER,
      sync_status TEXT
    )
  ''');

  await db.customStatement('''
    INSERT INTO purchase_receipts_new (
      id, shop_id, purchase_order_id, supplier_id, receipt_type,
      receipt_number, received_at, received_by, notes, version,
      server_id, synced_at, sync_status
    )
    SELECT
      r.id,
      r.shop_id,
      r.purchase_order_id,
      COALESCE(
        (SELECT po.supplier_id FROM purchase_orders po WHERE po.id = r.purchase_order_id),
        (SELECT s.id FROM suppliers s WHERE s.shop_id = r.shop_id LIMIT 1)
      ),
      'from_order',
      r.receipt_number,
      r.received_at,
      r.received_by,
      r.notes,
      r.version,
      r.server_id,
      r.synced_at,
      r.sync_status
    FROM purchase_receipts r
  ''');

  await db.customStatement('DROP TABLE purchase_receipts');
  await db.customStatement(
    'ALTER TABLE purchase_receipts_new RENAME TO purchase_receipts',
  );

  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS purchase_receipt_items_new (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      shop_id INTEGER NOT NULL REFERENCES shops(id),
      purchase_receipt_id INTEGER NOT NULL REFERENCES purchase_receipts(id),
      purchase_order_item_id INTEGER REFERENCES purchase_order_items(id),
      product_id INTEGER NOT NULL REFERENCES products(id),
      quantity_received INTEGER NOT NULL,
      unit_cost INTEGER NOT NULL,
      batch_number TEXT,
      expiry_date INTEGER,
      version INTEGER NOT NULL DEFAULT 1,
      server_id TEXT,
      synced_at INTEGER,
      sync_status TEXT
    )
  ''');

  await db.customStatement('''
    INSERT INTO purchase_receipt_items_new (
      id, shop_id, purchase_receipt_id, purchase_order_item_id, product_id,
      quantity_received, unit_cost, batch_number, expiry_date, version,
      server_id, synced_at, sync_status
    )
    SELECT
      id, shop_id, purchase_receipt_id, purchase_order_item_id, product_id,
      quantity_received, unit_cost, batch_number, expiry_date, version,
      server_id, synced_at, sync_status
    FROM purchase_receipt_items
  ''');

  await db.customStatement('DROP TABLE purchase_receipt_items');
  await db.customStatement(
    'ALTER TABLE purchase_receipt_items_new RENAME TO purchase_receipt_items',
  );
}

/// Catalogue FX (idempotent) — appelé à la création, migration et à chaque ouverture.
Future<void> seedFxCurrencies(AppDatabase db) async {
  final seeds = [
    ('XOF', 'Franc CFA', 'FCFA', 0, 1),
    ('NGN', 'Naira nigérian', '₦', 2, 2),
    ('GHS', 'Cedi ghanéen', '₵', 2, 3),
    ('USD', 'Dollar US', r'$', 2, 4),
    ('EUR', 'Euro', '€', 2, 5),
  ];

  for (final (code, label, symbol, minor, order) in seeds) {
    await db.into(db.fxCurrencies).insertOnConflictUpdate(
          FxCurrenciesCompanion.insert(
            code: code,
            label: label,
            symbol: symbol,
            minorUnit: Value(minor),
            sortOrder: Value(order),
          ),
        );
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

Future<void> _backfillShopHierarchy(AppDatabase db) async {
  final shops = await db.select(db.shops).get();
  if (shops.isEmpty) return;

  final defaultByOwner = <int, Shop>{};
  for (final shop in shops) {
    if (shop.isDefault && shop.ownerUserId != null) {
      defaultByOwner[shop.ownerUserId!] = shop;
    }
  }

  for (final shop in shops) {
    if (shop.parentShopId != null || shop.isDefault || shop.ownerUserId == null) {
      continue;
    }
    final root = defaultByOwner[shop.ownerUserId!];
    if (root == null || root.id == shop.id) continue;

    await (db.update(db.shops)..where((s) => s.id.equals(shop.id))).write(
      ShopsCompanion(parentShopId: Value(root.id)),
    );
  }
}
