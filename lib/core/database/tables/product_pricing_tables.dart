import 'package:drift/drift.dart';

import 'auth_tables.dart';
import 'commerce_tables.dart';

/// Historique des prix de vente et coûts d'achat par produit.
class ProductPriceHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitCost => integer().nullable()();
  IntColumn get priceSell => integer()();
  TextColumn get reason => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
}
