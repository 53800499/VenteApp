import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../domain/services/report_aggregation_service.dart';

class ReportsLocalDatasource {
  ReportsLocalDatasource(this._db);

  final AppDatabase _db;

  Future<ReportPeriodRawData> loadPeriodData({
    required List<int> shopIds,
    required int fromMs,
    required int toMs,
    required bool includeSellerPerformance,
  }) async {
    if (shopIds.isEmpty) {
      return ReportPeriodRawData.empty();
    }

    final sales = await _fetchSales(shopIds, fromMs, toMs);
    final profitLines = await _fetchProfitLines(shopIds, fromMs, toMs);
    final topProducts = await _fetchTopProducts(shopIds, fromMs, toMs);
    final sellerPerformance = includeSellerPerformance
        ? await _fetchSellerPerformance(shopIds, fromMs, toMs)
        : <ReportSellerRow>[];
    final debtRecovery = await _fetchDebtRecovery(shopIds, fromMs, toMs);

    return ReportPeriodRawData(
      sales: sales,
      profitLines: profitLines,
      topProducts: topProducts,
      sellerPerformance: sellerPerformance,
      debtRecovery: debtRecovery,
    );
  }

  Future<List<int>> activeShopIdsForOwner(int ownerUserId) async {
    final rows = await (_db.select(_db.shops)
          ..where(
            (s) =>
                s.ownerUserId.equals(ownerUserId) &
                s.isActive.equals(true),
          ))
        .get();
    if (rows.isEmpty) return [];
    return rows.map((s) => s.id).toList();
  }

  /// Boutiques à agréger en vue consolidée (offline).
  Future<List<int>> resolveConsolidatedShopIds({
    required int activeShopId,
    required int ownerUserId,
  }) async {
    final byOwner = await activeShopIdsForOwner(ownerUserId);
    if (byOwner.length > 1) return byOwner;

    final activeShop = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(activeShopId)))
        .getSingleOrNull();

    final ownerId = activeShop?.ownerUserId ?? ownerUserId;
    final siblings = await (_db.select(_db.shops)
          ..where(
            (s) => s.ownerUserId.equals(ownerId) & s.isActive.equals(true),
          ))
        .get();
    if (siblings.length > 1) {
      return siblings.map((s) => s.id).toList();
    }

    final allActive = await (_db.select(_db.shops)
          ..where((s) => s.isActive.equals(true)))
        .get();
    if (allActive.length > 1) {
      return allActive.map((s) => s.id).toList();
    }

    return [activeShopId];
  }

  Future<List<ReportSaleRow>> _fetchSales(
    List<int> shopIds,
    int fromMs,
    int toMs,
  ) async {
    final rows = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.isIn(shopIds) &
                s.status.equals('completed') &
                s.createdAt.isBiggerOrEqualValue(fromMs) &
                s.createdAt.isSmallerOrEqualValue(toMs),
          ))
        .get();

    return rows
        .map(
          (s) => ReportSaleRow(
            id: s.id,
            shopId: s.shopId,
            userId: s.userId,
            totalAmount: s.totalAmount,
            amountCash: s.amountCash,
            amountMomo: s.amountMomo,
            amountCredit: s.amountCredit,
            createdAt: s.createdAt,
          ),
        )
        .toList();
  }

  Future<List<ReportProfitLine>> _fetchProfitLines(
    List<int> shopIds,
    int fromMs,
    int toMs,
  ) async {
    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
    ])
      ..where(
        _db.saleItems.shopId.isIn(shopIds) &
            _db.sales.status.equals('completed') &
            _db.sales.createdAt.isBiggerOrEqualValue(fromMs) &
            _db.sales.createdAt.isSmallerOrEqualValue(toMs),
      );

    final rows = await query.get();
    return rows
        .map(
          (row) => ReportProfitLine(
            quantity: row.readTable(_db.saleItems).quantity,
            unitPrice: row.readTable(_db.saleItems).unitPrice,
            unitCost: row.readTable(_db.saleItems).unitCost,
          ),
        )
        .toList();
  }

  Future<List<ReportTopProductRow>> _fetchTopProducts(
    List<int> shopIds,
    int fromMs,
    int toMs,
  ) async {
    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
    ])
      ..where(
        _db.saleItems.shopId.isIn(shopIds) &
            _db.sales.status.equals('completed') &
            _db.sales.createdAt.isBiggerOrEqualValue(fromMs) &
            _db.sales.createdAt.isSmallerOrEqualValue(toMs),
      );

    final rows = await query.get();
    final byKey = <String, ReportTopProductRow>{};

    for (final row in rows) {
      final item = row.readTable(_db.saleItems);
      final key = '${item.productId ?? 'null'}:${item.productName}';
      final existing = byKey[key];
      final qty = item.quantity;
      final revenue = item.lineTotal;

      if (existing == null) {
        byKey[key] = ReportTopProductRow(
          productId: item.productId,
          productName: item.productName,
          quantitySold: qty,
          revenue: revenue,
        );
      } else {
        byKey[key] = ReportTopProductRow(
          productId: existing.productId,
          productName: existing.productName,
          quantitySold: existing.quantitySold + qty,
          revenue: existing.revenue + revenue,
        );
      }
    }

    return byKey.values.toList();
  }

  Future<List<ReportSellerRow>> _fetchSellerPerformance(
    List<int> shopIds,
    int fromMs,
    int toMs,
  ) async {
    final rows = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.isIn(shopIds) &
                s.status.equals('completed') &
                s.createdAt.isBiggerOrEqualValue(fromMs) &
                s.createdAt.isSmallerOrEqualValue(toMs),
          ))
        .get();

    final byUser = <int, ReportSellerRow>{};
    for (final sale in rows) {
      final user = await (_db.select(_db.users)
            ..where((u) => u.id.equals(sale.userId)))
          .getSingleOrNull();
      final existing = byUser[sale.userId];
      if (existing == null) {
        byUser[sale.userId] = ReportSellerRow(
          userId: sale.userId,
          userName: user?.name,
          saleCount: 1,
          totalRevenue: sale.totalAmount,
        );
      } else {
        byUser[sale.userId] = ReportSellerRow(
          userId: existing.userId,
          userName: existing.userName ?? user?.name,
          saleCount: existing.saleCount + 1,
          totalRevenue: existing.totalRevenue + sale.totalAmount,
        );
      }
    }
    return byUser.values.toList();
  }

  Future<ReportDebtRecoveryRaw> _fetchDebtRecovery(
    List<int> shopIds,
    int fromMs,
    int toMs,
  ) async {
    final createdRows = await (_db.select(_db.debts)
          ..where(
            (d) =>
                d.shopId.isIn(shopIds) &
                d.createdAt.isBiggerOrEqualValue(fromMs) &
                d.createdAt.isSmallerOrEqualValue(toMs) &
                d.status.isNotValue('cancelled'),
          ))
        .get();

    var debtsCreatedAmount = 0;
    var debtsRepaidAmount = 0;
    for (final debt in createdRows) {
      debtsCreatedAmount += debt.originalAmount;
      debtsRepaidAmount += debt.amountPaid;
    }

    return ReportDebtRecoveryRaw(
      debtsCreatedAmount: debtsCreatedAmount,
      debtsRepaidAmount: debtsRepaidAmount,
    );
  }
}

class ReportPeriodRawData {
  const ReportPeriodRawData({
    required this.sales,
    required this.profitLines,
    required this.topProducts,
    required this.sellerPerformance,
    required this.debtRecovery,
  });

  factory ReportPeriodRawData.empty() {
    return const ReportPeriodRawData(
      sales: [],
      profitLines: [],
      topProducts: [],
      sellerPerformance: [],
      debtRecovery: ReportDebtRecoveryRaw(
        debtsCreatedAmount: 0,
        debtsRepaidAmount: 0,
      ),
    );
  }

  final List<ReportSaleRow> sales;
  final List<ReportProfitLine> profitLines;
  final List<ReportTopProductRow> topProducts;
  final List<ReportSellerRow> sellerPerformance;
  final ReportDebtRecoveryRaw debtRecovery;
}
