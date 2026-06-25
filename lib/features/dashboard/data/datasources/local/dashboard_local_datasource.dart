import 'package:drift/drift.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../domain/entities/dashboard_entities.dart';
import '../../mappers/dashboard_sale_mapper.dart';

class DashboardLocalDatasource {
  DashboardLocalDatasource(this._db);

  final AppDatabase _db;

  Future<int> resolveAlertThreshold(int shopId) async {
    final settings = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(shopId)))
        .getSingleOrNull();
    return settings?.defaultAlertThreshold ?? AppConstants.defaultAlertThreshold;
  }

  Future<List<TodaySaleRow>> fetchTodaySales(
    int shopId,
    ({int dayStartMs, int dayEndMs}) range,
  ) async {
    final rows = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.status.equals('completed') &
                s.createdAt.isBiggerOrEqualValue(range.dayStartMs) &
                s.createdAt.isSmallerOrEqualValue(range.dayEndMs),
          ))
        .get();

    return rows.map(DashboardSaleMapper.fromSale).toList();
  }

  Future<List<TodaySaleRow>> fetchRecentTodaySales(
    int shopId,
    ({int dayStartMs, int dayEndMs}) range,
  ) async {
    final query = _db.select(_db.sales).join([
      leftOuterJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.sales.customerId),
      ),
    ])
      ..where(
        _db.sales.shopId.equals(shopId) &
            _db.sales.status.equals('completed') &
            _db.sales.createdAt.isBiggerOrEqualValue(range.dayStartMs) &
            _db.sales.createdAt.isSmallerOrEqualValue(range.dayEndMs),
      )
      ..orderBy([OrderingTerm.desc(_db.sales.createdAt)])
      ..limit(AppConstants.recentSalesLimit);

    final rows = await query.get();
    return rows.map((row) {
      final sale = row.readTable(_db.sales);
      final customer = row.readTableOrNull(_db.customers);
      return DashboardSaleMapper.fromSale(sale, customerName: customer?.name);
    }).toList();
  }

  Future<List<SaleProfitRow>> fetchTodayProfitLines(
    int shopId,
    ({int dayStartMs, int dayEndMs}) range,
  ) async {
    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
    ])
      ..where(
        _db.saleItems.shopId.equals(shopId) &
            _db.sales.status.equals('completed') &
            _db.sales.createdAt.isBiggerOrEqualValue(range.dayStartMs) &
            _db.sales.createdAt.isSmallerOrEqualValue(range.dayEndMs),
      );

    final rows = await query.get();
    return rows
        .map(
          (row) => SaleProfitRow(
            quantity: row.readTable(_db.saleItems).quantity,
            unitPrice: row.readTable(_db.saleItems).unitPrice,
            unitCost: row.readTable(_db.saleItems).unitCost,
          ),
        )
        .toList();
  }

  Future<int> countLowStock(int shopId, int defaultThreshold) async {
    final products = await (_db.select(_db.products)
          ..where(
            (p) => p.shopId.equals(shopId) & p.isArchived.equals(false),
          ))
        .get();

    return products.where((product) {
      final threshold = product.alertThreshold ?? defaultThreshold;
      return product.quantityInStock <= threshold;
    }).length;
  }

  Future<DashboardDebtStats> fetchDebtSummary(int shopId) async {
    final rows = await (_db.select(_db.debts)
          ..where(
            (d) =>
                d.shopId.equals(shopId) &
                d.status.equals('open') &
                d.amountRemaining.isBiggerThanValue(0),
          ))
        .get();

    final debtors = rows.map((row) => row.customerId).toSet();
    final totalDebt =
        rows.fold<int>(0, (sum, row) => sum + row.amountRemaining);

    return DashboardDebtStats(
      debtorCount: debtors.length,
      totalDebt: totalDebt,
    );
  }
}
