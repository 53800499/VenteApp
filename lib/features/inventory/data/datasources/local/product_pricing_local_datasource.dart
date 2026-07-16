import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/product_pricing_entities.dart';

class ProductPricingLocalDatasource {
  ProductPricingLocalDatasource(this._db);

  final AppDatabase _db;

  Future<List<ProductPriceHistoryEntry>> listPriceHistory({
    required int shopId,
    required int productId,
    int limit = 20,
  }) async {
    final rows = await (_db.select(_db.productPriceHistory)
          ..where(
            (h) =>
                h.shopId.equals(shopId) & h.productId.equals(productId),
          )
          ..orderBy([(h) => OrderingTerm.desc(h.createdAt)])
          ..limit(limit))
        .get();

    return rows.map(_mapRow).toList();
  }

  Future<void> recordPriceHistory({
    required int shopId,
    required int productId,
    int? unitCost,
    required int priceSell,
    required String reason,
    String? notes,
  }) async {
    await _db.into(_db.productPriceHistory).insert(
          ProductPriceHistoryCompanion.insert(
            shopId: shopId,
            productId: productId,
            unitCost: Value(unitCost),
            priceSell: priceSell,
            reason: reason,
            notes: Value(notes),
            createdAt: nowMs(),
          ),
        );
  }

  /// Met à jour le prix de vente catalogue et enregistre l'historique.
  Future<void> updateSalePrice({
    required int shopId,
    required int productId,
    required int newPriceSell,
    int? unitCost,
    required String reason,
    String? notes,
  }) async {
    final timestamp = nowMs();
    final product = await (_db.select(_db.products)
          ..where(
            (p) => p.shopId.equals(shopId) & p.id.equals(productId),
          ))
        .getSingleOrNull();
    if (product == null) return;

    if (product.priceSell == newPriceSell) return;

    await (_db.update(_db.products)..where((p) => p.id.equals(productId)))
        .write(
      ProductsCompanion(
        priceSell: Value(newPriceSell),
        updatedAt: Value(timestamp),
        version: Value(product.version + 1),
      ),
    );

    await recordPriceHistory(
      shopId: shopId,
      productId: productId,
      unitCost: unitCost,
      priceSell: newPriceSell,
      reason: reason,
      notes: notes,
    );
  }

  Future<void> applyProcurementDecisions({
    required int shopId,
    required List<ProcurementPriceDecision> decisions,
    required Map<int, int> unitCostsByProduct,
  }) async {
    for (final decision in decisions) {
      switch (decision.type) {
        case ProcurementPriceDecisionType.keepCurrent:
        case ProcurementPriceDecisionType.decideLater:
          continue;
        case ProcurementPriceDecisionType.updateManual:
        case ProcurementPriceDecisionType.applySuggested:
          final newPrice = decision.newPriceSell;
          if (newPrice == null || newPrice <= 0) continue;
          await updateSalePrice(
            shopId: shopId,
            productId: decision.productId,
            newPriceSell: newPrice,
            unitCost: unitCostsByProduct[decision.productId],
            reason: decision.type == ProcurementPriceDecisionType.applySuggested
                ? 'margin_rule'
                : 'procurement',
            notes: 'Mise à jour lors de l\'approvisionnement',
          );
      }
    }
  }

  ProductPriceHistoryEntry _mapRow(ProductPriceHistoryData row) {
    return ProductPriceHistoryEntry(
      id: row.id,
      shopId: row.shopId,
      productId: row.productId,
      unitCost: row.unitCost,
      priceSell: row.priceSell,
      reason: row.reason,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }
}
