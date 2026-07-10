import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/utils/time.dart';

class CustomerProductPriceLocalDatasource {
  CustomerProductPriceLocalDatasource(this._database);

  final db.AppDatabase _database;

  Future<Map<int, int>> loadForCustomer({
    required int shopId,
    required int customerId,
    required Iterable<int> productIds,
  }) async {
    final ids = productIds.toSet().toList();
    if (ids.isEmpty) return {};

    final rows = await (_database.select(_database.customerProductPrices)
          ..where(
            (row) =>
                row.shopId.equals(shopId) &
                row.customerId.equals(customerId) &
                row.productId.isIn(ids),
          ))
        .get();

    return {for (final row in rows) row.productId: row.lastUnitPrice};
  }

  Future<void> saveAfterSale({
    required int shopId,
    required int customerId,
    required List<({int productId, int unitPrice})> lines,
  }) async {
    if (lines.isEmpty) return;
    final timestamp = nowMs();

    await _database.transaction(() async {
      for (final line in lines) {
        if (line.unitPrice <= 0) continue;

        final existingRows = await (_database.select(_database.customerProductPrices)
              ..where(
                (row) =>
                    row.shopId.equals(shopId) &
                    row.customerId.equals(customerId) &
                    row.productId.equals(line.productId),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
        final existing = existingRows.isEmpty ? null : existingRows.first;

        if (existing != null) {
          await (_database.update(_database.customerProductPrices)
                ..where((row) => row.id.equals(existing.id)))
              .write(
            db.CustomerProductPricesCompanion(
              lastUnitPrice: Value(line.unitPrice),
              updatedAt: Value(timestamp),
            ),
          );
          if (existingRows.length > 1) {
            final duplicateIds =
                existingRows.skip(1).map((row) => row.id).toList();
            await (_database.delete(_database.customerProductPrices)
                  ..where((row) => row.id.isIn(duplicateIds)))
                .go();
          }
        } else {
          await _database.into(_database.customerProductPrices).insert(
                db.CustomerProductPricesCompanion.insert(
                  shopId: shopId,
                  customerId: customerId,
                  productId: line.productId,
                  lastUnitPrice: line.unitPrice,
                  updatedAt: timestamp,
                ),
              );
        }
      }
    });
  }
}
