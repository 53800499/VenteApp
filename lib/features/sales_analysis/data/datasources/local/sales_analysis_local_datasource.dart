import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/utils/benin_day_range.dart';
import '../../../domain/entities/sales_analysis_entities.dart';

class SalesAnalysisLocalDatasource {
  SalesAnalysisLocalDatasource(this._db);

  final AppDatabase _db;

  Future<List<ProductSalesSummary>> listProductSummaries({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await _fetchSaleItemRows(shopId: shopId, fromMs: fromMs, toMs: toMs);
    final byKey = <String, _ProductAccumulator>{};

    for (final row in rows) {
      final key = _productKey(row.productId, row.productName);
      final acc = byKey.putIfAbsent(
        key,
        () => _ProductAccumulator(
          productId: row.productId,
          productName: row.productName,
        ),
      );
      acc.add(row);
    }

    final headless = await _fetchHeadlessSales(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    for (final sale in headless) {
      final label = sale.saleType == 'quick'
          ? SalesAnalysisHeadlessLabels.quickSale
          : SalesAnalysisHeadlessLabels.standardSale;
      final key = 'headless:${sale.saleType}';
      final acc = byKey.putIfAbsent(
        key,
        () => _ProductAccumulator(productName: label),
      );
      acc.addHeadlessSale(sale);
    }

    final catalogPrices = await _loadCatalogPrices(shopId);
    final summaries = byKey.values.map((acc) {
      final catalog =
          acc.productId != null ? catalogPrices[acc.productId!] : null;
      return ProductSalesSummary(
        productId: acc.productId,
        productName: acc.productName,
        catalogPrice: catalog,
        quantitySold: acc.quantitySold,
        revenue: acc.revenue,
        averageUnitPrice: acc.quantitySold > 0
            ? (acc.revenue / acc.quantitySold).round()
            : 0,
        lastSaleAt: acc.lastSaleAt,
      );
    }).toList();

    summaries.sort((a, b) => b.revenue.compareTo(a.revenue));
    return summaries;
  }

  Future<ProductSalesDetail> loadProductDetail({
    required int shopId,
    required int fromMs,
    required int toMs,
    int? productId,
    required String productName,
  }) async {
    if (SalesAnalysisHeadlessLabels.isHeadlessProductName(productName)) {
      return _loadHeadlessProductDetail(
        shopId: shopId,
        fromMs: fromMs,
        toMs: toMs,
        productName: productName,
      );
    }

    final rows = await _fetchSaleItemRows(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
      productId: productId,
      productName: productName,
    );

    if (rows.isEmpty) {
      final catalog = productId != null
          ? (await _loadCatalogPrices(shopId))[productId]
          : null;
      final emptySummary = ProductSalesSummary(
        productId: productId,
        productName: productName,
        catalogPrice: catalog,
        quantitySold: 0,
        revenue: 0,
        averageUnitPrice: 0,
      );
      return ProductSalesDetail(
        summary: emptySummary,
        stats: ProductPriceStats(
          catalogPrice: catalog,
          minSoldPrice: 0,
          maxSoldPrice: 0,
          averageUnitPrice: 0,
          quantitySold: 0,
          revenue: 0,
          saleLineCount: 0,
        ),
        lines: const [],
        employeeStats: const [],
      );
    }

    var quantitySold = 0.0;
    var revenue = 0;
    var minPrice = rows.first.unitPrice;
    var maxPrice = rows.first.unitPrice;
    int? lastSaleAt;
    final lines = <ProductSaleLine>[];
    final employeeAcc = <int, _EmployeeAccumulator>{};

    for (final row in rows) {
      quantitySold += row.quantity;
      revenue += row.lineTotal;
      if (row.unitPrice < minPrice) minPrice = row.unitPrice;
      if (row.unitPrice > maxPrice) maxPrice = row.unitPrice;
      if (lastSaleAt == null || row.soldAt > lastSaleAt) {
        lastSaleAt = row.soldAt;
      }

      lines.add(
        ProductSaleLine(
          saleId: row.saleId,
          soldAt: row.soldAt,
          customerName: row.customerName,
          quantity: row.quantity,
          unitPrice: row.unitPrice,
          sellerName: row.sellerName,
          catalogPrice: row.catalogPrice,
          discountAmount: row.discountAmount,
        ),
      );

      final emp = employeeAcc.putIfAbsent(
        row.userId,
        () => _EmployeeAccumulator(
          userId: row.userId,
          userName: row.sellerName,
        ),
      );
      emp.add(
        quantity: row.quantity,
        unitPrice: row.unitPrice,
        catalogPrice: row.catalogPrice,
        discountAmount: row.discountAmount,
      );
    }

    final catalog = productId != null
        ? (await _loadCatalogPrices(shopId))[productId]
        : rows.first.catalogPrice;

    final summary = ProductSalesSummary(
      productId: productId,
      productName: productName,
      catalogPrice: catalog,
      quantitySold: quantitySold,
      revenue: revenue,
      averageUnitPrice:
          quantitySold > 0 ? (revenue / quantitySold).round() : 0,
      lastSaleAt: lastSaleAt,
    );

    return ProductSalesDetail(
      summary: summary,
      stats: ProductPriceStats(
        catalogPrice: catalog,
        minSoldPrice: minPrice,
        maxSoldPrice: maxPrice,
        averageUnitPrice:
            quantitySold > 0 ? (revenue / quantitySold).round() : 0,
        quantitySold: quantitySold,
        revenue: revenue,
        saleLineCount: rows.length,
      ),
      lines: lines,
      employeeStats: employeeAcc.values.map((e) => e.toPerformance()).toList()
        ..sort((a, b) => b.saleLineCount.compareTo(a.saleLineCount)),
    );
  }

  Future<List<EmployeePricePerformance>> listEmployeePerformance({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await _fetchSaleItemRows(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    final byUser = <int, _EmployeeAccumulator>{};

    for (final row in rows) {
      final acc = byUser.putIfAbsent(
        row.userId,
        () => _EmployeeAccumulator(
          userId: row.userId,
          userName: row.sellerName,
        ),
      );
      acc.add(
        quantity: row.quantity,
        unitPrice: row.unitPrice,
        catalogPrice: row.catalogPrice,
        discountAmount: row.discountAmount,
      );
    }

    final headless = await _fetchHeadlessSales(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    for (final sale in headless) {
      final acc = byUser.putIfAbsent(
        sale.userId,
        () => _EmployeeAccumulator(
          userId: sale.userId,
          userName: sale.sellerName,
        ),
      );
      acc.addHeadlessSale(amount: sale.totalAmount);
    }

    return byUser.values.map((e) => e.toPerformance()).toList()
      ..sort((a, b) => b.saleLineCount.compareTo(a.saleLineCount));
  }

  Future<ProductSoldPriceRange> soldPriceRangeForProduct({
    required int shopId,
    required int productId,
    int lookbackDays = 90,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const dayMs = 86_400_000;
    final fromMs = now - lookbackDays * dayMs;

    final rows = await _fetchSaleItemRows(
      shopId: shopId,
      fromMs: fromMs,
      toMs: now,
      productId: productId,
    );

    if (rows.isEmpty) return const ProductSoldPriceRange.empty();

    var minPrice = rows.first.unitPrice;
    var maxPrice = rows.first.unitPrice;
    var totalRevenue = 0;
    var totalQty = 0.0;

    for (final row in rows) {
      if (row.unitPrice < minPrice) minPrice = row.unitPrice;
      if (row.unitPrice > maxPrice) maxPrice = row.unitPrice;
      totalRevenue += row.lineTotal;
      totalQty += row.quantity;
    }

    return ProductSoldPriceRange(
      minPrice: minPrice,
      maxPrice: maxPrice,
      averagePrice: totalQty > 0 ? (totalRevenue / totalQty).round() : 0,
      sampleCount: rows.length,
    );
  }

  Future<List<CustomerSalesInsight>> listCustomerInsights({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await _fetchSaleItemRows(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );

    final byCustomer = <int, _CustomerInsightAccumulator>{};
    for (final row in rows) {
      if (row.customerId == null) continue;
      final acc = byCustomer.putIfAbsent(
        row.customerId!,
        () => _CustomerInsightAccumulator(
          customerId: row.customerId!,
          customerName: row.customerName ?? 'Client',
        ),
      );
      acc.addSale(
        row.saleId,
        quantity: row.quantity,
        unitPrice: row.unitPrice,
        lineTotal: row.lineTotal,
      );
    }

    final headless = await _fetchHeadlessSales(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    for (final sale in headless) {
      if (sale.customerId == null) continue;
      final acc = byCustomer.putIfAbsent(
        sale.customerId!,
        () => _CustomerInsightAccumulator(
          customerId: sale.customerId!,
          customerName: sale.customerName ?? 'Client',
        ),
      );
      acc.addHeadlessSale(sale.saleId, amount: sale.totalAmount);
    }

    return byCustomer.values
        .map((e) => e.toInsight())
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
  }

  Future<List<CustomerProductPriceHabit>> listCustomerPriceHabits({
    required int shopId,
    required int customerId,
    int lookbackDays = 180,
    int recentLimit = 5,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const dayMs = 86_400_000;
    final fromMs = now - lookbackDays * dayMs;

    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
    ])
      ..where(
        _db.sales.shopId.equals(shopId) &
            _db.sales.status.equals('completed') &
            _db.sales.customerId.equals(customerId) &
            _db.sales.createdAt.isBiggerOrEqualValue(fromMs) &
            _db.sales.createdAt.isSmallerOrEqualValue(now),
      )
      ..orderBy([
        OrderingTerm.desc(_db.sales.createdAt),
      ]);

    final rows = await query.get();
    final byProduct = <String, List<int>>{};
    final names = <String, String>{};
    final productIds = <String, int?>{};

    for (final row in rows) {
      final item = row.readTable(_db.saleItems);
      final key = '${item.productId ?? 'null'}:${item.productName}';
      names[key] = item.productName;
      productIds[key] = item.productId;
      byProduct.putIfAbsent(key, () => []).add(item.unitPrice);
    }

    final remembered = await (_db.select(_db.customerProductPrices)
          ..where(
            (p) =>
                p.shopId.equals(shopId) &
                p.customerId.equals(customerId),
          ))
        .get();
    final rememberedByProduct = {
      for (final row in remembered) row.productId: row.lastUnitPrice,
    };

    final habits = <CustomerProductPriceHabit>[];
    for (final entry in byProduct.entries) {
      final pid = productIds[entry.key];
      final prices = entry.value;
      final recent = prices.take(recentLimit).toList();
      final usual = pid != null && rememberedByProduct.containsKey(pid)
          ? rememberedByProduct[pid]!
          : _usualPrice(prices);
      habits.add(
        CustomerProductPriceHabit(
          productId: pid,
          productName: names[entry.key]!,
          recentPrices: recent,
          usualPrice: usual,
        ),
      );
    }

    habits.sort((a, b) => a.productName.compareTo(b.productName));
    return habits;
  }

  Future<List<CategorySalesSummary>> listCategorySummaries({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await _fetchSaleItemRows(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    final byCategory = <String, _CategoryAccumulator>{};

    for (final row in rows) {
      final key = row.categoryId?.toString() ?? 'none';
      final acc = byCategory.putIfAbsent(
        key,
        () => _CategoryAccumulator(
          categoryId: row.categoryId,
          categoryName: row.categoryName ?? 'Sans catégorie',
        ),
      );
      acc.add(row);
    }

    final headless = await _fetchHeadlessSales(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    if (headless.isNotEmpty) {
      final acc = byCategory.putIfAbsent(
        'headless',
        () => _CategoryAccumulator(
          categoryName: SalesAnalysisHeadlessLabels.categoryBucket,
        ),
      );
      for (final sale in headless) {
        acc.addHeadlessSale(sale);
      }
    }

    return byCategory.values
        .map((e) => e.toSummary())
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  Future<MarginSummary> loadMarginSummary({
    required int shopId,
    required int fromMs,
    required int toMs,
    int topLimit = 15,
  }) async {
    final rows = await _fetchSaleItemRows(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    final headless = await _fetchHeadlessSales(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    if (rows.isEmpty && headless.isEmpty) return const MarginSummary.empty();

    var totalRevenue = 0;
    var totalCost = 0;
    var linesWithCost = 0;
    final byProduct = <String, _MarginProductAccumulator>{};

    for (final row in rows) {
      totalRevenue += row.lineTotal;
      final unitCost = row.unitCost ?? row.priceBuy;
      final lineCost =
          unitCost != null ? (unitCost * row.quantity).round() : null;

      if (lineCost != null) {
        totalCost += lineCost;
        linesWithCost++;
      }

      final key = _productKey(row.productId, row.productName);
      final acc = byProduct.putIfAbsent(
        key,
        () => _MarginProductAccumulator(
          productId: row.productId,
          productName: row.productName,
        ),
      );
      acc.add(
        revenue: row.lineTotal,
        cost: lineCost,
        quantity: row.quantity,
      );
    }

    for (final sale in headless) {
      totalRevenue += sale.totalAmount;
    }

    final topProducts = byProduct.values
        .map((e) => e.toLine())
        .where((line) => line.estimatedCost > 0)
        .toList()
      ..sort((a, b) => b.estimatedProfit.compareTo(a.estimatedProfit));

    return MarginSummary(
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      estimatedProfit: totalRevenue - totalCost,
      linesWithCost: linesWithCost,
      totalLines: rows.length + headless.length,
      topProducts: topProducts.take(topLimit).toList(),
    );
  }

  Future<List<PriceDeviationLine>> listPriceDeviations({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await _fetchSaleItemRows(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );

    final deviations = <PriceDeviationLine>[];
    for (final row in rows) {
      final belowCatalog = row.catalogPrice != null &&
          row.unitPrice < row.catalogPrice!;
      final aboveCatalog = row.catalogPrice != null &&
          row.unitPrice > row.catalogPrice!;
      if (row.discountAmount > 0 || belowCatalog || aboveCatalog) {
        deviations.add(
          PriceDeviationLine(
            saleId: row.saleId,
            soldAt: row.soldAt,
            productId: row.productId,
            productName: row.productName,
            catalogPrice: row.catalogPrice,
            unitPrice: row.unitPrice,
            discountAmount: row.discountAmount,
            sellerName: row.sellerName,
          ),
        );
      }
    }

    deviations.sort((a, b) => b.soldAt.compareTo(a.soldAt));
    return deviations;
  }

  Future<SalesTrendSummary> loadSalesTrends({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    const beninOffsetMs = 60 * 60 * 1000;
    const dayMs = 86_400_000;

    int beninDayStart(int soldAtMs) {
      final localMs = soldAtMs + beninOffsetMs;
      final localMidnight = (localMs ~/ dayMs) * dayMs;
      return localMidnight - beninOffsetMs;
    }

    final sales = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.status.equals('completed') &
                s.createdAt.isBiggerOrEqualValue(fromMs) &
                s.createdAt.isSmallerOrEqualValue(toMs),
          ))
        .get();

    final itemRows = await _fetchSaleItemRows(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );

    final byDay = <int, _TrendAccumulator>{};

    for (final sale in sales) {
      final bucket = beninDayStart(sale.createdAt);
      final acc = byDay.putIfAbsent(
        bucket,
        () => _TrendAccumulator(bucketStartMs: bucket),
      );
      acc.saleCount++;
      acc.revenue += sale.totalAmount;
    }

    for (final row in itemRows) {
      final bucket = beninDayStart(row.soldAt);
      final acc = byDay.putIfAbsent(
        bucket,
        () => _TrendAccumulator(bucketStartMs: bucket),
      );
      acc.quantitySold += row.quantity;
    }

    final points = byDay.values.map((e) => e.toPoint()).toList()
      ..sort((a, b) => a.bucketStartMs.compareTo(b.bucketStartMs));

    var totalRevenue = 0;
    var totalSaleCount = 0;
    for (final point in points) {
      totalRevenue += point.revenue;
      totalSaleCount += point.saleCount;
    }

    return SalesTrendSummary(
      points: points,
      totalRevenue: totalRevenue,
      totalSaleCount: totalSaleCount,
    );
  }

  int _usualPrice(List<int> prices) {
    if (prices.isEmpty) return 0;
    final counts = <int, int>{};
    for (final price in prices) {
      counts[price] = (counts[price] ?? 0) + 1;
    }
    var bestPrice = prices.first;
    var bestCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        bestPrice = entry.key;
      }
    }
    return bestPrice;
  }

  Future<Map<int, int>> _loadCatalogPrices(int shopId) async {
    final products = await (_db.select(_db.products)
          ..where((p) => p.shopId.equals(shopId)))
        .get();
    return {for (final p in products) p.id: p.priceSell};
  }

  Future<List<_SaleItemRow>> _fetchSaleItemRows({
    required int shopId,
    required int fromMs,
    required int toMs,
    int? productId,
    String? productName,
  }) async {
    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
      leftOuterJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.sales.customerId),
      ),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.sales.userId)),
      leftOuterJoin(
        _db.products,
        _db.products.id.equalsExp(_db.saleItems.productId),
      ),
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.products.categoryId),
      ),
    ])
      ..where(
        _db.sales.shopId.equals(shopId) &
            _db.sales.status.equals('completed') &
            _db.sales.createdAt.isBiggerOrEqualValue(fromMs) &
            _db.sales.createdAt.isSmallerOrEqualValue(toMs) &
            (productId != null
                ? _db.saleItems.productId.equals(productId)
                : productName != null
                    ? _db.saleItems.productName.equals(productName)
                    : const Constant(true)),
      )
      ..orderBy([
        OrderingTerm.desc(_db.sales.createdAt),
      ]);

    final rows = await query.get();
    return rows
        .map(
          (row) => _SaleItemRow(
            saleId: row.readTable(_db.sales).id,
            soldAt: row.readTable(_db.sales).createdAt,
            userId: row.readTable(_db.sales).userId,
            productId: row.readTable(_db.saleItems).productId,
            productName: row.readTable(_db.saleItems).productName,
            quantity: row.readTable(_db.saleItems).quantity,
            unitPrice: row.readTable(_db.saleItems).unitPrice,
            lineTotal: row.readTable(_db.saleItems).lineTotal,
            discountAmount: row.readTable(_db.saleItems).discountAmount,
            customerName: row.readTableOrNull(_db.customers)?.name,
            sellerName: row.readTableOrNull(_db.users)?.name,
            catalogPrice: row.readTableOrNull(_db.products)?.priceSell,
            customerId: row.readTable(_db.sales).customerId,
            unitCost: row.readTable(_db.saleItems).unitCost,
            priceBuy: row.readTableOrNull(_db.products)?.priceBuy,
            categoryId: row.readTableOrNull(_db.products)?.categoryId,
            categoryName: row.readTableOrNull(_db.categories)?.name,
          ),
        )
        .toList();
  }

  /// Ventes complétées sans ligne `sale_items` (vente rapide, sync sans détail…).
  Future<List<_HeadlessSaleRow>> _fetchHeadlessSales({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final query = _db.select(_db.sales).join([
      leftOuterJoin(
        _db.saleItems,
        _db.saleItems.saleId.equalsExp(_db.sales.id),
      ),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.sales.userId)),
      leftOuterJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.sales.customerId),
      ),
    ])
      ..where(
        _db.sales.shopId.equals(shopId) &
            _db.sales.status.equals('completed') &
            _db.sales.createdAt.isBiggerOrEqualValue(fromMs) &
            _db.sales.createdAt.isSmallerOrEqualValue(toMs) &
            _db.saleItems.id.isNull(),
      )
      ..orderBy([
        OrderingTerm.desc(_db.sales.createdAt),
      ]);

    final rows = await query.get();
    return rows
        .map(
          (row) => _HeadlessSaleRow(
            saleId: row.readTable(_db.sales).id,
            soldAt: row.readTable(_db.sales).createdAt,
            userId: row.readTable(_db.sales).userId,
            saleType: row.readTable(_db.sales).saleType,
            totalAmount: row.readTable(_db.sales).totalAmount,
            sellerName: row.readTableOrNull(_db.users)?.name,
            customerId: row.readTable(_db.sales).customerId,
            customerName: row.readTableOrNull(_db.customers)?.name,
          ),
        )
        .toList();
  }

  Future<ProductSalesDetail> _loadHeadlessProductDetail({
    required int shopId,
    required int fromMs,
    required int toMs,
    required String productName,
  }) async {
    final quick = productName == SalesAnalysisHeadlessLabels.quickSale;
    final sales = (await _fetchHeadlessSales(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    ))
        .where((s) => quick ? s.saleType == 'quick' : s.saleType != 'quick')
        .toList();

    if (sales.isEmpty) {
      return ProductSalesDetail(
        summary: ProductSalesSummary(
          productName: productName,
          quantitySold: 0,
          revenue: 0,
          averageUnitPrice: 0,
        ),
        stats: const ProductPriceStats(
          minSoldPrice: 0,
          maxSoldPrice: 0,
          averageUnitPrice: 0,
          quantitySold: 0,
          revenue: 0,
          saleLineCount: 0,
        ),
        lines: const [],
        employeeStats: const [],
      );
    }

    var revenue = 0;
    int? minPrice;
    int? maxPrice;
    int? lastSaleAt;
    final lines = <ProductSaleLine>[];
    final employeeAcc = <int, _EmployeeAccumulator>{};

    for (final sale in sales) {
      revenue += sale.totalAmount;
      minPrice = minPrice == null
          ? sale.totalAmount
          : (sale.totalAmount < minPrice ? sale.totalAmount : minPrice);
      maxPrice = maxPrice == null
          ? sale.totalAmount
          : (sale.totalAmount > maxPrice ? sale.totalAmount : maxPrice);
      if (lastSaleAt == null || sale.soldAt > lastSaleAt) {
        lastSaleAt = sale.soldAt;
      }

      lines.add(
        ProductSaleLine(
          saleId: sale.saleId,
          soldAt: sale.soldAt,
          customerName: sale.customerName,
          quantity: 1,
          unitPrice: sale.totalAmount,
          sellerName: sale.sellerName,
          discountAmount: 0,
        ),
      );

      final emp = employeeAcc.putIfAbsent(
        sale.userId,
        () => _EmployeeAccumulator(
          userId: sale.userId,
          userName: sale.sellerName,
        ),
      );
      emp.addHeadlessSale(amount: sale.totalAmount);
    }

    final qty = sales.length.toDouble();
    final summary = ProductSalesSummary(
      productName: productName,
      quantitySold: qty,
      revenue: revenue,
      averageUnitPrice: qty > 0 ? (revenue / qty).round() : 0,
      lastSaleAt: lastSaleAt,
    );

    return ProductSalesDetail(
      summary: summary,
      stats: ProductPriceStats(
        minSoldPrice: minPrice ?? 0,
        maxSoldPrice: maxPrice ?? 0,
        averageUnitPrice: qty > 0 ? (revenue / qty).round() : 0,
        quantitySold: qty,
        revenue: revenue,
        saleLineCount: sales.length,
      ),
      lines: lines,
      employeeStats: employeeAcc.values.map((e) => e.toPerformance()).toList()
        ..sort((a, b) => b.saleLineCount.compareTo(a.saleLineCount)),
    );
  }

  String _productKey(int? productId, String productName) =>
      '${productId ?? 'null'}:$productName';
}

class _SaleItemRow {
  const _SaleItemRow({
    required this.saleId,
    required this.soldAt,
    required this.userId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.discountAmount,
    this.customerName,
    this.sellerName,
    this.catalogPrice,
    this.customerId,
    this.unitCost,
    this.priceBuy,
    this.categoryId,
    this.categoryName,
  });

  final int saleId;
  final int soldAt;
  final int userId;
  final int? productId;
  final String productName;
  final double quantity;
  final int unitPrice;
  final int lineTotal;
  final int discountAmount;
  final String? customerName;
  final String? sellerName;
  final int? catalogPrice;
  final int? customerId;
  final int? unitCost;
  final int? priceBuy;
  final int? categoryId;
  final String? categoryName;
}

class _HeadlessSaleRow {
  const _HeadlessSaleRow({
    required this.saleId,
    required this.soldAt,
    required this.userId,
    required this.saleType,
    required this.totalAmount,
    this.sellerName,
    this.customerId,
    this.customerName,
  });

  final int saleId;
  final int soldAt;
  final int userId;
  final String saleType;
  final int totalAmount;
  final String? sellerName;
  final int? customerId;
  final String? customerName;
}

class _ProductAccumulator {
  _ProductAccumulator({
    this.productId,
    required this.productName,
  });

  final int? productId;
  final String productName;
  double quantitySold = 0;
  int revenue = 0;
  int? lastSaleAt;

  void add(_SaleItemRow row) {
    quantitySold += row.quantity;
    revenue += row.lineTotal;
    if (lastSaleAt == null || row.soldAt > lastSaleAt!) {
      lastSaleAt = row.soldAt;
    }
  }

  void addHeadlessSale(_HeadlessSaleRow sale) {
    quantitySold += 1;
    revenue += sale.totalAmount;
    if (lastSaleAt == null || sale.soldAt > lastSaleAt!) {
      lastSaleAt = sale.soldAt;
    }
  }
}

class _EmployeeAccumulator {
  _EmployeeAccumulator({required this.userId, this.userName});

  final int userId;
  String? userName;
  int saleLineCount = 0;
  int totalLineRevenue = 0;
  double totalQuantity = 0;
  int discountLineCount = 0;

  void add({
    required double quantity,
    required int unitPrice,
    int? catalogPrice,
    required int discountAmount,
  }) {
    saleLineCount++;
    totalLineRevenue += (unitPrice * quantity).round();
    totalQuantity += quantity;
    final belowCatalog = catalogPrice != null && unitPrice < catalogPrice;
    if (discountAmount > 0 || belowCatalog) {
      discountLineCount++;
    }
  }

  void addHeadlessSale({required int amount}) {
    saleLineCount++;
    totalLineRevenue += amount;
    totalQuantity += 1;
  }

  EmployeePricePerformance toPerformance() {
    return EmployeePricePerformance(
      userId: userId,
      userName: userName,
      saleLineCount: saleLineCount,
      averageUnitPrice: totalQuantity > 0
          ? (totalLineRevenue / totalQuantity).round()
          : 0,
      discountLineCount: discountLineCount,
    );
  }
}

class _CustomerInsightAccumulator {
  _CustomerInsightAccumulator({
    required this.customerId,
    required this.customerName,
  });

  final int customerId;
  String customerName;
  final Set<int> saleIds = {};
  int lineCount = 0;
  int totalRevenue = 0;
  double totalQuantity = 0;

  void addSale(
    int saleId, {
    required double quantity,
    required int unitPrice,
    required int lineTotal,
  }) {
    saleIds.add(saleId);
    lineCount++;
    totalRevenue += lineTotal;
    totalQuantity += quantity;
  }

  void addHeadlessSale(int saleId, {required int amount}) {
    saleIds.add(saleId);
    lineCount++;
    totalRevenue += amount;
    totalQuantity += 1;
  }

  CustomerSalesInsight toInsight() {
    return CustomerSalesInsight(
      customerId: customerId,
      customerName: customerName,
      saleCount: saleIds.length,
      lineCount: lineCount,
      totalRevenue: totalRevenue,
      averageUnitPrice: totalQuantity > 0
          ? (totalRevenue / totalQuantity).round()
          : 0,
    );
  }
}

class _CategoryAccumulator {
  _CategoryAccumulator({
    this.categoryId,
    required this.categoryName,
  });

  final int? categoryId;
  final String categoryName;
  final Set<String> productKeys = {};
  double quantitySold = 0;
  int revenue = 0;

  void add(_SaleItemRow row) {
    productKeys.add('${row.productId ?? 'null'}:${row.productName}');
    quantitySold += row.quantity;
    revenue += row.lineTotal;
  }

  void addHeadlessSale(_HeadlessSaleRow sale) {
    productKeys.add('headless:${sale.saleId}');
    quantitySold += 1;
    revenue += sale.totalAmount;
  }

  CategorySalesSummary toSummary() {
    return CategorySalesSummary(
      categoryId: categoryId,
      categoryName: categoryName,
      productCount: productKeys.length,
      quantitySold: quantitySold,
      revenue: revenue,
    );
  }
}

class _MarginProductAccumulator {
  _MarginProductAccumulator({
    this.productId,
    required this.productName,
  });

  final int? productId;
  final String productName;
  double quantitySold = 0;
  int revenue = 0;
  int estimatedCost = 0;

  void add({required int revenue, int? cost, required double quantity}) {
    this.revenue += revenue;
    quantitySold += quantity;
    if (cost != null) {
      estimatedCost += cost;
    }
  }

  MarginProductLine toLine() {
    return MarginProductLine(
      productId: productId,
      productName: productName,
      quantitySold: quantitySold,
      revenue: revenue,
      estimatedCost: estimatedCost,
      estimatedProfit: revenue - estimatedCost,
    );
  }
}

class _TrendAccumulator {
  _TrendAccumulator({required this.bucketStartMs});

  final int bucketStartMs;
  int revenue = 0;
  int saleCount = 0;
  double quantitySold = 0;

  SalesTrendPoint toPoint() {
    return SalesTrendPoint(
      bucketStartMs: bucketStartMs,
      label: formatBeninDate(bucketStartMs),
      revenue: revenue,
      saleCount: saleCount,
      quantitySold: quantitySold,
    );
  }
}
