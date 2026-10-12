import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/stock_valuation_entities.dart';
import '../../../domain/services/stock_valuation_service.dart';
import '../../mappers/product_mapper.dart';
import 'inventory_lot_local_datasource.dart';

class StockValuationLocalDatasource {
  StockValuationLocalDatasource({
    required AppDatabase db,
    required InventoryLotLocalDatasource lotDatasource,
    StockValuationService service = const StockValuationService(),
  })  : _db = db,
        _lotDs = lotDatasource,
        _service = service;

  final AppDatabase _db;
  final InventoryLotLocalDatasource _lotDs;
  final StockValuationService _service;

  /// Calcule la valorisation consolidée de tout le stock d'une boutique.
  Future<StockValuationSummary> loadStockValuationSummary(int shopId) async {
    final now = nowMs();

    // 1. Charger tous les produits actifs de la boutique
    final defaultAlert = await _getDefaultAlertThreshold(shopId);
    final productRows = await (_db.select(_db.products)
          ..where((p) => p.shopId.equals(shopId) & p.isArchived.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();

    if (productRows.isEmpty) {
      return _service.calculateSummary(const []);
    }

    // 2. Charger les noms de catégories
    final categoryRows = await (_db.select(_db.categories)
          ..where((c) => c.shopId.equals(shopId)))
        .get();
    final categoryMap = {for (final c in categoryRows) c.id: c.name};

    // 3. Charger tous les lots actifs pour la boutique
    final allLots = await (_db.select(_db.inventoryLots)
          ..where(
            (l) =>
                l.shopId.equals(shopId) &
                l.quantityRemaining.isBiggerThanValue(0),
          )
          ..orderBy([
            (l) => OrderingTerm.asc(l.receivedAt),
            (l) => OrderingTerm.asc(l.id),
          ]))
        .get();

    final lotsByProduct = <int, List<dynamic>>{};
    for (final row in allLots) {
      final list = lotsByProduct.putIfAbsent(row.productId, () => []);
      list.add(_lotDs.toEntity(row));
    }

    // 4. Charger la date de dernière vente pour chaque produit
    final lastSaleMap = await _loadLastSaleTimestamps(shopId);

    // 5. Calculer la valorisation pour chaque produit
    final valuations = <ProductStockValuation>[];
    for (final row in productRows) {
      final product = ProductMapper.fromRow(
        row: row,
        effectiveThreshold: row.alertThreshold ?? defaultAlert,
        categoryName: row.categoryId != null ? categoryMap[row.categoryId] : null,
      );

      final lots = lotsByProduct[product.id] ?? const [];
      final lastSale = lastSaleMap[product.id];

      final val = _service.calculateProductValuation(
        product: product,
        activeLots: lots.cast(),
        lastSaleAt: lastSale,
        currentTimestampMs: now,
      );
      valuations.add(val);
    }

    return _service.calculateSummary(valuations);
  }

  /// Calcule l'historique et la dynamique glissante des ventes d'un produit.
  Future<ProductSalesVelocity> loadProductSalesVelocity({
    required int shopId,
    required int productId,
  }) async {
    final now = DateTime.now();
    final startOfToday =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    // Début de semaine (Lundi)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek =
        DateTime(monday.year, monday.month, monday.day).millisecondsSinceEpoch;
    // Début du mois
    final startOfMonth =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    final query = _db.select(_db.saleItems).join([
      innerJoin(
        _db.sales,
        _db.sales.id.equalsExp(_db.saleItems.saleId),
      ),
    ])
      ..where(
        _db.sales.shopId.equals(shopId) &
            _db.sales.status.isNotValue('cancelled') &
            _db.saleItems.productId.equals(productId),
      );

    final rows = await query.get();

    var salesToday = 0;
    var revToday = 0;
    var salesWeek = 0;
    var revWeek = 0;
    var salesMonth = 0;
    var revMonth = 0;
    var salesTotal = 0;
    var revTotal = 0;

    for (final r in rows) {
      final item = r.readTable(_db.saleItems);
      final sale = r.readTable(_db.sales);
      final soldAt = sale.createdAt;
      final qty = item.quantity.round();
      final lineRevenue = (item.unitPrice * item.quantity).round();

      salesTotal += qty;
      revTotal += lineRevenue;

      if (soldAt >= startOfToday) {
        salesToday += qty;
        revToday += lineRevenue;
      }
      if (soldAt >= startOfWeek) {
        salesWeek += qty;
        revWeek += lineRevenue;
      }
      if (soldAt >= startOfMonth) {
        salesMonth += qty;
        revMonth += lineRevenue;
      }
    }

    return ProductSalesVelocity(
      salesToday: salesToday,
      revenueToday: revToday,
      salesThisWeek: salesWeek,
      revenueThisWeek: revWeek,
      salesThisMonth: salesMonth,
      revenueThisMonth: revMonth,
      salesTotal: salesTotal,
      revenueTotal: revTotal,
    );
  }

  Future<Map<int, int>> _loadLastSaleTimestamps(int shopId) async {
    final query = _db.select(_db.saleItems).join([
      innerJoin(
        _db.sales,
        _db.sales.id.equalsExp(_db.saleItems.saleId),
      ),
    ])
      ..where(
        _db.sales.shopId.equals(shopId) &
            _db.sales.status.isNotValue('cancelled'),
      );

    final rows = await query.get();
    final map = <int, int>{};

    for (final r in rows) {
      final item = r.readTable(_db.saleItems);
      final sale = r.readTable(_db.sales);
      final pid = item.productId;
      if (pid == null) continue;
      final existing = map[pid];
      if (existing == null || sale.createdAt > existing) {
        map[pid] = sale.createdAt;
      }
    }

    return map;
  }

  Future<int> _getDefaultAlertThreshold(int shopId) async {
    final rows = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(shopId))
          ..limit(1))
        .get();
    return rows.firstOrNull?.defaultAlertThreshold ?? 5;
  }
}
