import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/utils/benin_day_range.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/sale_entities.dart';
import '../../../domain/services/receipt_number_service.dart';
import '../../../domain/services/sale_validation_service.dart';
import '../../mappers/sale_mapper.dart';

class SalesLocalDatasource {
  SalesLocalDatasource(
    this._db, {
    ReceiptNumberService? receipts,
  }) : _receipts = receipts ?? const ReceiptNumberService();

  final db.AppDatabase _db;
  final ReceiptNumberService _receipts;

  Future<List<SaleListRow>> listSales({
    required int shopId,
    SaleListFilters filters = const SaleListFilters(),
  }) async {
    final query = _db.select(_db.sales).join([
      leftOuterJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.sales.customerId),
      ),
    ])
      ..where(_db.sales.shopId.equals(shopId));

    if (filters.status != null) {
      final statusCode = filters.status == SaleStatus.cancelled
          ? 'cancelled'
          : 'completed';
      query.where(_db.sales.status.equals(statusCode));
    }
    if (filters.from != null) {
      query.where(
        _db.sales.createdAt.isBiggerOrEqualValue(filters.from!),
      );
    }
    if (filters.to != null) {
      query.where(
        _db.sales.createdAt.isSmallerOrEqualValue(filters.to!),
      );
    }
    if (filters.search.trim().isNotEmpty) {
      final term = '%${filters.search.trim()}%';
      query.where(_db.sales.receiptNumber.like(term));
    }

    query
      ..orderBy([OrderingTerm.desc(_db.sales.createdAt)])
      ..limit(filters.limit);

    final rows = await query.get();
    return rows
        .map(
          (row) => SaleMapper.listRowFromRow(
            row.readTable(_db.sales),
            customerName: row.readTableOrNull(_db.customers)?.name,
          ),
        )
        .toList();
  }

  Future<Sale?> findSale(int shopId, int saleId) async {
    final query = _db.select(_db.sales).join([
      leftOuterJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.sales.customerId),
      ),
    ])
      ..where(
        _db.sales.id.equals(saleId) & _db.sales.shopId.equals(shopId),
      );

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final saleRow = row.readTable(_db.sales);
    final items = await (_db.select(_db.saleItems)
          ..where((i) => i.saleId.equals(saleId))
          ..orderBy([(i) => OrderingTerm.asc(i.id)]))
        .get();

    return SaleMapper.saleFromRow(
      sale: saleRow,
      customerName: row.readTableOrNull(_db.customers)?.name,
      items: items.map(SaleMapper.itemFromRow).toList(),
    );
  }

  Future<List<SaleCustomerOption>> listCustomers({
    required int shopId,
    String search = '',
  }) async {
    final rows = await (_db.select(_db.customers)
          ..where((c) {
            var expr =
                c.shopId.equals(shopId) & c.isArchived.equals(false);
            if (search.trim().isNotEmpty) {
              final term = '%${search.trim()}%';
              expr = expr & (c.name.like(term) | c.phone.like(term));
            }
            return expr;
          })
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
    return rows.map(SaleMapper.customerFromRow).toList();
  }

  Future<int> countSalesOnBeninDay(int shopId, int timestamp) async {
    final bounds = getBeninDayBounds(timestamp);
    final dayEnd = bounds.dayStartMs + 86400000 - 1;
    final rows = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.createdAt.isBiggerOrEqualValue(bounds.dayStartMs) &
                s.createdAt.isSmallerOrEqualValue(dayEnd),
          ))
        .get();
    return rows.length;
  }

  Future<db.Product?> findProduct(int shopId, int productId) async {
    return (_db.select(_db.products)
          ..where(
            (p) =>
                p.id.equals(productId) &
                p.shopId.equals(shopId) &
                p.isArchived.equals(false),
          ))
        .getSingleOrNull();
  }

  Future<db.Customer?> findCustomer(int shopId, int customerId) async {
    return (_db.select(_db.customers)
          ..where(
            (c) =>
                c.id.equals(customerId) &
                c.shopId.equals(shopId) &
                c.isArchived.equals(false),
          ))
        .getSingleOrNull();
  }

  Future<db.Debt?> findDebtBySale(int shopId, int saleId) async {
    return (_db.select(_db.debts)
          ..where(
            (d) => d.shopId.equals(shopId) & d.saleId.equals(saleId),
          ))
        .getSingleOrNull();
  }

  Future<Sale> createStandardSale({
    required int shopId,
    required int userId,
    required String receiptNumber,
    required int? customerId,
    required ComputedSaleTotals totals,
    required PaymentMethod paymentMethod,
    required List<({
      db.Product product,
      SaleLineDraft line,
      int lineTotal,
    })> snapshots,
    String? note,
    int timestamp = 0,
  }) async {
    final ts = timestamp > 0 ? timestamp : nowMs();

    return _db.transaction(() async {
      final saleId = await _db.into(_db.sales).insert(
            db.SalesCompanion.insert(
              shopId: shopId,
              userId: userId,
              customerId: Value(customerId),
              receiptNumber: Value(receiptNumber),
              saleType: const Value('standard'),
              subtotal: Value(totals.subtotal),
              discountAmount: Value(totals.discountAmount),
              totalAmount: totals.totalAmount,
              amountPaid: Value(totals.amountPaid),
              amountCash: Value(totals.amountCash),
              amountMomo: Value(totals.amountMomo),
              amountCredit: Value(totals.amountCredit),
              paymentMethod: Value(paymentMethod.code),
              status: const Value('completed'),
              note: Value(note),
              createdAt: ts,
              updatedAt: Value(ts),
            ),
          );

      for (final snap in snapshots) {
        final product = snap.product;
        final line = snap.line;
        await _db.into(_db.saleItems).insert(
              db.SaleItemsCompanion.insert(
                saleId: saleId,
                shopId: shopId,
                productId: Value(product.id),
                productName: product.name,
                quantity: line.quantity.toDouble(),
                unitPrice: line.unitPrice,
                unitCost: Value(product.priceBuy),
                discountAmount: Value(line.lineDiscountAmount),
                lineTotal: snap.lineTotal,
                createdAt: ts,
              ),
            );

        final qty = line.quantity;
        final quantityBefore = product.quantityInStock;
        final quantityAfter = quantityBefore - qty;
        await (_db.update(_db.products)..where((p) => p.id.equals(product.id)))
            .write(
          db.ProductsCompanion(
            quantityInStock: Value(quantityAfter),
            updatedAt: Value(ts),
            version: Value(product.version + 1),
          ),
        );

        await _db.into(_db.stockMovements).insert(
              db.StockMovementsCompanion.insert(
                shopId: shopId,
                productId: product.id,
                userId: userId,
                type: 'sale',
                quantityChange: -qty,
                quantityBefore: quantityBefore,
                quantityAfter: quantityAfter,
                saleId: Value(saleId),
                unitCost: Value(product.priceBuy),
                createdAt: ts,
              ),
            );
      }

      if (totals.amountCredit > 0 && customerId != null) {
        await _db.into(_db.debts).insert(
              db.DebtsCompanion.insert(
                shopId: shopId,
                customerId: customerId,
                saleId: Value(saleId),
                originalAmount: totals.amountCredit,
                amountRemaining: totals.amountCredit,
                createdAt: ts,
              ),
            );
      }

      final sale = await findSale(shopId, saleId);
      return sale!;
    });
  }

  Future<Sale> createQuickSale({
    required int shopId,
    required int userId,
    required String receiptNumber,
    required ComputedSaleTotals totals,
    required PaymentMethod paymentMethod,
    String? note,
    int timestamp = 0,
  }) async {
    final ts = timestamp > 0 ? timestamp : nowMs();

    final saleId = await _db.into(_db.sales).insert(
          db.SalesCompanion.insert(
            shopId: shopId,
            userId: userId,
            receiptNumber: Value(receiptNumber),
            saleType: const Value('quick'),
            subtotal: Value(totals.subtotal),
            totalAmount: totals.totalAmount,
            amountPaid: Value(totals.amountPaid),
            amountCash: Value(totals.amountCash),
            amountMomo: Value(totals.amountMomo),
            paymentMethod: Value(paymentMethod.code),
            status: const Value('completed'),
            note: Value(note),
            createdAt: ts,
            updatedAt: Value(ts),
          ),
        );

    final sale = await findSale(shopId, saleId);
    return sale!;
  }

  Future<void> cancelSale({
    required int shopId,
    required int userId,
    required int saleId,
    required String reason,
    required int timestamp,
  }) async {
    await _db.transaction(() async {
      final saleRow = await (_db.select(_db.sales)
            ..where(
              (s) => s.id.equals(saleId) & s.shopId.equals(shopId),
            ))
          .getSingleOrNull();
      if (saleRow == null) return;

      if (saleRow.saleType == 'standard') {
        final items = await (_db.select(_db.saleItems)
              ..where((i) => i.saleId.equals(saleId)))
            .get();

        for (final item in items) {
          final productId = item.productId;
          if (productId == null) continue;

          final product = await findProduct(shopId, productId);
          if (product == null) continue;

          final qty = item.quantity.round();
          final quantityBefore = product.quantityInStock;
          final quantityAfter = quantityBefore + qty;
          await (_db.update(_db.products)..where((p) => p.id.equals(product.id)))
              .write(
            db.ProductsCompanion(
              quantityInStock: Value(quantityAfter),
              updatedAt: Value(timestamp),
              version: Value(product.version + 1),
            ),
          );

          await _db.into(_db.stockMovements).insert(
                db.StockMovementsCompanion.insert(
                  shopId: shopId,
                  productId: product.id,
                  userId: userId,
                  type: 'sale_cancel',
                  quantityChange: qty,
                  quantityBefore: quantityBefore,
                  quantityAfter: quantityAfter,
                  saleId: Value(saleId),
                  reason: Value(reason),
                  createdAt: timestamp,
                ),
              );
        }
      }

      final debt = await findDebtBySale(shopId, saleId);
      if (debt != null) {
        await (_db.update(_db.debts)..where((d) => d.id.equals(debt.id))).write(
          const db.DebtsCompanion(
            status: Value('closed'),
            amountRemaining: Value(0),
          ),
        );
      }

      await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
        db.SalesCompanion(
          status: const Value('cancelled'),
          cancelReason: Value(reason),
          cancelledByUserId: Value(userId),
          cancelledAt: Value(timestamp),
          updatedAt: Value(timestamp),
          version: Value(saleRow.version + 1),
        ),
      );
    });
  }

  Future<String> nextReceiptNumber(int shopId, int timestamp) async {
    final count = await countSalesOnBeninDay(shopId, timestamp);
    return _receipts.generate(count, timestamp);
  }
}
