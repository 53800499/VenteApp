import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/time.dart';
import 'tables/auth_tables.dart';
import 'tables/commerce_tables.dart';

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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
        },
      );

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
