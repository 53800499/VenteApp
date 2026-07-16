import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/utils/benin_day_range.dart';
import '../../../../../core/utils/time.dart';
import '../../../../inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import '../../../domain/entities/sale_entities.dart';
import '../../../domain/services/receipt_number_service.dart';
import '../../../domain/services/sale_validation_service.dart';
import '../../mappers/sale_mapper.dart';
import '../../models/sale_api_models.dart';

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
      )
      ..limit(1);

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
    final rows = await (_db.select(_db.debts)
          ..where(
            (d) => d.shopId.equals(shopId) & d.saleId.equals(saleId),
          )
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
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
      final lotDs = InventoryLotLocalDatasource(_db);
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
        await _applyFifoSaleLine(
          lotDs: lotDs,
          shopId: shopId,
          userId: userId,
          saleId: saleId,
          product: snap.product,
          line: snap.line,
          lineTotal: snap.lineTotal,
          ts: ts,
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

  Future<Sale> convertQuickSaleToStandard({
    required int shopId,
    required int userId,
    required int saleId,
    required ComputedSaleTotals totals,
    required List<({
      db.Product product,
      SaleLineDraft line,
      int lineTotal,
    })> snapshots,
    int timestamp = 0,
  }) async {
    final ts = timestamp > 0 ? timestamp : nowMs();

    return _db.transaction(() async {
      final lotDs = InventoryLotLocalDatasource(_db);
      final saleRow = await (_db.select(_db.sales)
            ..where(
              (s) => s.id.equals(saleId) & s.shopId.equals(shopId),
            )
            ..limit(1))
          .getSingleOrNull();
      if (saleRow == null) {
        throw StateError('Vente introuvable pour conversion.');
      }

      for (final snap in snapshots) {
        await _applyFifoSaleLine(
          lotDs: lotDs,
          shopId: shopId,
          userId: userId,
          saleId: saleId,
          product: snap.product,
          line: snap.line,
          lineTotal: snap.lineTotal,
          ts: ts,
        );
      }

      await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
        db.SalesCompanion(
          saleType: const Value('standard'),
          subtotal: Value(totals.subtotal),
          discountAmount: Value(totals.discountAmount),
          updatedAt: Value(ts),
          syncStatus: const Value('pending'),
          version: Value(saleRow.version + 1),
        ),
      );

      final sale = await findSale(shopId, saleId);
      return sale!;
    });
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

        final stockBeforeRestore = <int, int>{};
        for (final item in items) {
          final productId = item.productId;
          if (productId == null) continue;
          final product = await findProduct(shopId, productId);
          if (product != null) {
            stockBeforeRestore[productId] = product.quantityInStock;
          }
        }

        final lotDs = InventoryLotLocalDatasource(_db);
        await lotDs.restoreLotsForSale(shopId: shopId, saleId: saleId);

        for (final item in items) {
          final productId = item.productId;
          if (productId == null) continue;

          final product = await findProduct(shopId, productId);
          if (product == null) continue;

          final qty = item.quantity.round();
          final quantityBefore =
              stockBeforeRestore[productId] ?? product.quantityInStock;
          final quantityAfter = product.quantityInStock;

          await (_db.update(_db.products)..where((p) => p.id.equals(product.id)))
              .write(
            db.ProductsCompanion(
              version: Value(product.version + 1),
              updatedAt: Value(timestamp),
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
                  unitCost: Value(item.unitCost),
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

  Future<bool> allProductsHaveServerId(int shopId, List<int> productIds) async {
    for (final productId in productIds) {
      final product = await findProduct(shopId, productId);
      if (product?.serverId == null || product!.serverId!.isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> markSaleSynced({
    required int saleId,
    required String serverId,
  }) async {
    final timestamp = nowMs();
    await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
      db.SalesCompanion(
        serverId: Value(serverId),
        syncedAt: Value(timestamp),
        syncStatus: const Value('synced'),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<void> markSaleSyncPending(int saleId) async {
    await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
      const db.SalesCompanion(syncStatus: Value('pending')),
    );
  }

  Future<String?> findSaleServerId(int shopId, int saleId) async {
    final row = await (_db.select(_db.sales)
          ..where(
            (s) => s.id.equals(saleId) & s.shopId.equals(shopId),
          )
          ..limit(1))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<int?> resolveDefaultUserId(int shopId) async {
    final user = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(shopId) & u.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return user?.id;
  }

  Future<int?> resolveLocalCustomerId(int shopId, int? remoteCustomerId) async {
    if (remoteCustomerId == null) return null;
    final row = await (_db.select(_db.customers)
          ..where(
            (c) =>
                c.shopId.equals(shopId) &
                c.serverId.equals('$remoteCustomerId'),
          ))
        .getSingleOrNull();
    return row?.id;
  }

  Future<bool> saleNeedsPaymentDetail(int shopId, String serverId) async {
    final sale = await _firstSaleByServerId(shopId, serverId);
    if (sale == null) return true;
    if (sale.customerId == null) return true;
    return sale.amountCash == 0 &&
        sale.amountMomo == 0 &&
        sale.amountCredit == 0 &&
        sale.totalAmount > 0;
  }

  Future<void> upsertSalePaymentDetailFromRemote({
    required int shopId,
    required SaleDetailApiDto detail,
  }) async {
    final timestamp = nowMs();
    final serverId = '${detail.id}';
    final existingRows = await _findSalesByServerId(shopId, serverId);
    final existing = existingRows.isEmpty ? null : existingRows.first;
    if (existing == null) return;

    final localCustomerId =
        await resolveLocalCustomerId(shopId, detail.customerId);

    await (_db.update(_db.sales)..where((s) => s.id.equals(existing.id))).write(
      db.SalesCompanion(
        customerId: localCustomerId != null
            ? Value(localCustomerId)
            : const Value.absent(),
        amountPaid: Value(detail.amountPaid),
        amountCash: Value(detail.amountCash),
        amountMomo: Value(detail.amountMomo),
        amountCredit: Value(detail.amountCredit),
        paymentMethod: Value(detail.paymentMethod),
        syncedAt: Value(timestamp),
        updatedAt: Value(timestamp),
        syncStatus: const Value('synced'),
      ),
    );
    if (existingRows.length > 1) {
      await _dedupeSales(existingRows, keepId: existing.id);
    }
  }

  Future<db.SalesCompanion> _remoteListSaleFields({
    required int shopId,
    required SaleListItemApiDto remote,
    required int timestamp,
  }) async {
    final localCustomerId =
        await resolveLocalCustomerId(shopId, remote.customerId);
    return db.SalesCompanion(
      receiptNumber: Value(remote.receiptNumber),
      saleType: Value(remote.saleType),
      totalAmount: Value(remote.totalAmount),
      status: Value(remote.status),
      customerId: localCustomerId != null
          ? Value(localCustomerId)
          : const Value.absent(),
      amountCash: Value(remote.amountCash),
      amountMomo: Value(remote.amountMomo),
      amountCredit: Value(remote.amountCredit),
      paymentMethod: remote.paymentMethod != null
          ? Value(remote.paymentMethod)
          : const Value.absent(),
      syncedAt: Value(timestamp),
      updatedAt: Value(timestamp),
      syncStatus: const Value('synced'),
    );
  }

  Future<void> upsertSaleListItemFromRemote({
    required int shopId,
    required int userId,
    required SaleListItemApiDto remote,
  }) async {
    final timestamp = nowMs();
    final serverId = '${remote.id}';
    final existingRows = await _findSalesByServerId(shopId, serverId);
    final existing = existingRows.isEmpty ? null : existingRows.first;
    final fields = await _remoteListSaleFields(
      shopId: shopId,
      remote: remote,
      timestamp: timestamp,
    );

    if (existing != null) {
      await (_db.update(_db.sales)..where((s) => s.id.equals(existing.id)))
          .write(fields);
      if (existingRows.length > 1) {
        await _dedupeSales(existingRows, keepId: existing.id);
      }
      return;
    }

    if (remote.receiptNumber.isNotEmpty) {
      final pendingRows = await (_db.select(_db.sales)
            ..where(
              (s) =>
                  s.shopId.equals(shopId) &
                  s.serverId.isNull() &
                  s.receiptNumber.equals(remote.receiptNumber),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.id)]))
          .get();
      if (pendingRows.isNotEmpty) {
        final pending = pendingRows.first;
        await (_db.update(_db.sales)..where((s) => s.id.equals(pending.id)))
            .write(
          fields.copyWith(
            serverId: Value(serverId),
          ),
        );
        if (pendingRows.length > 1) {
          await _dedupeSales(pendingRows, keepId: pending.id);
        }
        return;
      }
    }

    await _db.into(_db.sales).insert(
          db.SalesCompanion.insert(
            shopId: shopId,
            userId: userId,
            receiptNumber: Value(remote.receiptNumber),
            saleType: Value(remote.saleType),
            totalAmount: remote.totalAmount,
            status: Value(remote.status),
            customerId: remote.customerId != null
                ? Value(await resolveLocalCustomerId(shopId, remote.customerId))
                : const Value.absent(),
            amountCash: Value(remote.amountCash),
            amountMomo: Value(remote.amountMomo),
            amountCredit: Value(remote.amountCredit),
            paymentMethod: remote.paymentMethod != null
                ? Value(remote.paymentMethod)
                : const Value.absent(),
            createdAt: remote.createdAt,
            updatedAt: Value(remote.createdAt),
            serverId: Value(serverId),
            syncedAt: Value(timestamp),
            syncStatus: const Value('synced'),
          ),
        );
  }

  Future<void> upsertCustomerSaleFromRemote({
    required int shopId,
    required int userId,
    required int localCustomerId,
    required int remoteId,
    required int totalAmount,
    required String status,
    required int createdAt,
    String? receiptNumber,
  }) async {
    final timestamp = nowMs();
    final serverId = '$remoteId';
    final existingRows = await _findSalesByServerId(shopId, serverId);
    final existing = existingRows.isEmpty ? null : existingRows.first;

    if (existing != null) {
      await (_db.update(_db.sales)..where((s) => s.id.equals(existing.id))).write(
        db.SalesCompanion(
          customerId: Value(localCustomerId),
          receiptNumber: Value(receiptNumber),
          totalAmount: Value(totalAmount),
          status: Value(status),
          syncedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncStatus: const Value('synced'),
        ),
      );
      if (existingRows.length > 1) {
        await _dedupeSales(existingRows, keepId: existing.id);
      }
      return;
    }

    await _db.into(_db.sales).insert(
          db.SalesCompanion.insert(
            shopId: shopId,
            userId: userId,
            customerId: Value(localCustomerId),
            receiptNumber: Value(receiptNumber),
            totalAmount: totalAmount,
            status: Value(status),
            createdAt: createdAt,
            updatedAt: Value(createdAt),
            serverId: Value(serverId),
            syncedAt: Value(timestamp),
            syncStatus: const Value('synced'),
          ),
        );
  }

  Future<bool> hasSaleItems(int shopId, String serverId) async {
    final sale = await _firstSaleByServerId(shopId, serverId);
    if (sale == null) return false;
    final itemsList = await (_db.select(_db.saleItems)
          ..where((i) => i.saleId.equals(sale.id)))
        .get();
    return itemsList.isNotEmpty;
  }

  Future<void> upsertSaleItemsFromRemote({
    required int shopId,
    required String serverId,
    required List<SaleDetailItemApiDto> items,
  }) async {
    final existingRows = await _findSalesByServerId(shopId, serverId);
    final sale = existingRows.isEmpty ? null : existingRows.first;
    if (sale == null) return;
    if (existingRows.length > 1) {
      await _dedupeSales(existingRows, keepId: sale.id);
    }

    await _db.transaction(() async {
      await (_db.delete(_db.saleItems)..where((i) => i.saleId.equals(sale.id))).go();

      for (final item in items) {
        int? localProductId;
        if (item.productId != null) {
          final prod = await (_db.select(_db.products)
                ..where((p) => p.shopId.equals(shopId) & p.serverId.equals('${item.productId}')))
              .getSingleOrNull();
          localProductId = prod?.id;
        }

        await _db.into(_db.saleItems).insert(
              db.SaleItemsCompanion.insert(
                saleId: sale.id,
                shopId: shopId,
                productId: Value(localProductId),
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                lineTotal: item.lineTotal,
                createdAt: sale.createdAt,
              ),
            );
      }
    });
  }

  Future<List<db.Sale>> _findSalesByServerId(int shopId, String serverId) async {
    return (_db.select(_db.sales)
          ..where(
            (s) => s.shopId.equals(shopId) & s.serverId.equals(serverId),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.id)]))
        .get();
  }

  Future<db.Sale?> _firstSaleByServerId(int shopId, String serverId) async {
    final rows = await _findSalesByServerId(shopId, serverId);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _dedupeSales(List<db.Sale> rows, {required int keepId}) async {
    final duplicateIds =
        rows.where((s) => s.id != keepId).map((s) => s.id).toList();
    if (duplicateIds.isEmpty) return;

    await _db.transaction(() async {
      for (final dupId in duplicateIds) {
        await (_db.delete(_db.saleItems)..where((i) => i.saleId.equals(dupId)))
            .go();
        await (_db.delete(_db.debts)..where((d) => d.saleId.equals(dupId))).go();
      }
      await (_db.delete(_db.sales)..where((s) => s.id.isIn(duplicateIds))).go();
    });
  }

  Future<void> _applyFifoSaleLine({
    required InventoryLotLocalDatasource lotDs,
    required int shopId,
    required int userId,
    required int saleId,
    required db.Product product,
    required SaleLineDraft line,
    required int lineTotal,
    required int ts,
  }) async {
    final qty = line.quantity;
    final quantityBefore = product.quantityInStock;

    final slices = await lotDs.allocateFifo(
      shopId: shopId,
      productId: product.id,
      quantity: qty,
    );
    final unitCost = InventoryLotLocalDatasource.weightedUnitCost(slices);

    final saleItemId = await _db.into(_db.saleItems).insert(
          db.SaleItemsCompanion.insert(
            saleId: saleId,
            shopId: shopId,
            productId: Value(product.id),
            productName: product.name,
            quantity: line.quantity.toDouble(),
            unitPrice: line.unitPrice,
            unitCost: Value(unitCost),
            discountAmount: Value(line.lineDiscountAmount),
            lineTotal: lineTotal,
            createdAt: ts,
          ),
        );

    await lotDs.recordSaleItemAllocations(
      shopId: shopId,
      saleItemId: saleItemId,
      slices: slices,
    );

    final productAfter = await findProduct(shopId, product.id);
    final quantityAfter =
        productAfter?.quantityInStock ?? (quantityBefore - qty);

    if (productAfter != null) {
      await (_db.update(_db.products)..where((p) => p.id.equals(product.id)))
          .write(
        db.ProductsCompanion(
          version: Value(productAfter.version + 1),
          updatedAt: Value(ts),
        ),
      );
    }

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
            unitCost: Value(unitCost),
            createdAt: ts,
          ),
        );
  }
}
