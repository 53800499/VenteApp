import 'package:drift/drift.dart';

import '../../../../inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/errors/failures.dart';
import '../../../../../core/utils/benin_day_range.dart';
import '../../../../../core/utils/time.dart';
import '../../../../inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import '../../../../inventory/domain/entities/inventory_lot_entities.dart'
    as lot_entity;
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
            )
            ..limit(1))
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
    final rows = await (_db.select(_db.customers)
          ..where(
            (c) =>
                c.shopId.equals(shopId) &
                c.serverId.equals('$remoteCustomerId'),
          )
          ..orderBy([(c) => OrderingTerm.asc(c.id)])
          ..limit(1))
        .get();
    return rows.firstOrNull?.id;
  }

  Future<bool> saleNeedsPaymentDetail(int shopId, String serverId) async {
    final sale = await _firstSaleByServerId(shopId, serverId);
    if (sale == null) return true;
    // Walk-in (customerId null) : pas de GET si les montants sont déjà connus.
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

  Future<bool> saleItemsNeedUnitCostBackfill(int shopId, String serverId) async {
    final sale = await _firstSaleByServerId(shopId, serverId);
    if (sale == null) return false;
    final itemsList = await (_db.select(_db.saleItems)
          ..where((i) => i.saleId.equals(sale.id)))
        .get();
    if (itemsList.isEmpty) return false;
    return itemsList.every(
      (item) => item.unitCost == null || item.unitCost! <= 0,
    );
  }

  Future<int?> _resolveRemoteItemUnitCost({
    required int shopId,
    required SaleDetailItemApiDto item,
    int? localProductId,
  }) async {
    if (item.unitCost != null && item.unitCost! > 0) {
      return item.unitCost;
    }

    if (localProductId != null) {
      final product = await (_db.select(_db.products)
            ..where((p) => p.shopId.equals(shopId) & p.id.equals(localProductId)))
          .getSingleOrNull();
      final priceBuy = product?.priceBuy;
      if (priceBuy != null && priceBuy > 0) return priceBuy;
    }

    return null;
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
      final inventoryLocal = InventoryLocalDatasource(_db);
      await (_db.delete(_db.saleItems)..where((i) => i.saleId.equals(sale.id))).go();

      for (final item in items) {
        int? localProductId;
        if (item.productId != null) {
          localProductId = await inventoryLocal.findLocalProductIdByServerId(
            shopId,
            '${item.productId}',
          );
        }

        final unitCost = await _resolveRemoteItemUnitCost(
          shopId: shopId,
          item: item,
          localProductId: localProductId,
        );

        await _db.into(_db.saleItems).insert(
              db.SaleItemsCompanion.insert(
                saleId: sale.id,
                shopId: shopId,
                productId: Value(localProductId),
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                unitCost: unitCost != null ? Value(unitCost) : const Value.absent(),
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

  Future<String> nextReplacementNumber(int shopId) async {
    final rows = await (_db.select(_db.saleReplacements)
          ..where((t) => t.shopId.equals(shopId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .get();
    final next = rows.isEmpty ? 1 : rows.first.id + 1;
    return 'RX-${next.toString().padLeft(5, '0')}';
  }

  Future<Map<int, int>> returnedQuantitiesBySaleItem({
    required int shopId,
    required int saleId,
  }) async {
    final replacements = await (_db.select(_db.saleReplacements)
          ..where(
            (r) => r.shopId.equals(shopId) & r.saleId.equals(saleId),
          ))
        .get();
    if (replacements.isEmpty) return {};

    final replacementIds = replacements.map((r) => r.id).toList();
    final items = await (_db.select(_db.saleReplacementItems)
          ..where(
            (i) =>
                i.shopId.equals(shopId) &
                i.replacementId.isIn(replacementIds),
          ))
        .get();

    final map = <int, int>{};
    for (final item in items) {
      map[item.returnedSaleItemId] =
          (map[item.returnedSaleItemId] ?? 0) + item.quantityReturned;
    }
    return map;
  }

  Future<List<SaleReplacement>> listReplacementsForSale({
    required int shopId,
    required int saleId,
  }) async {
    final rows = await (_db.select(_db.saleReplacements)
          ..where(
            (r) => r.shopId.equals(shopId) & r.saleId.equals(saleId),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.replacedAt)]))
        .get();

    final result = <SaleReplacement>[];
    for (final row in rows) {
      result.add(await _mapReplacement(shopId, row));
    }
    return result;
  }

  Future<SaleReplacement> createSaleReplacement({
    required int shopId,
    required int userId,
    required int saleId,
    required List<SaleReplacementLineInput> items,
    String? notes,
    int timestamp = 0,
  }) async {
    final ts = timestamp > 0 ? timestamp : nowMs();

    return _db.transaction(() async {
      final saleRow = await (_db.select(_db.sales)
            ..where(
              (s) => s.id.equals(saleId) & s.shopId.equals(shopId),
            )
            ..limit(1))
          .getSingleOrNull();
      if (saleRow == null) {
        throw const NotFoundFailure('Vente introuvable.');
      }
      if (saleRow.status == 'cancelled') {
        throw const ValidationFailure(
          'Impossible de remplacer une vente annulée.',
        );
      }
      if (saleRow.saleType != 'standard') {
        throw const ValidationFailure(
          'Le remplacement n\'est possible que sur une vente standard.',
        );
      }
      if (items.isEmpty) {
        throw const ValidationFailure(
          'Ajoutez au moins une ligne de remplacement.',
        );
      }

      final alreadyReturned = await returnedQuantitiesBySaleItem(
        shopId: shopId,
        saleId: saleId,
      );
      final saleItems = await (_db.select(_db.saleItems)
            ..where((i) => i.saleId.equals(saleId)))
          .get();
      final saleItemById = {for (final i in saleItems) i.id: i};

      final lotDs = InventoryLotLocalDatasource(_db);
      final number = await nextReplacementNumber(shopId);

      final replacementId = await _db.into(_db.saleReplacements).insert(
            db.SaleReplacementsCompanion.insert(
              shopId: shopId,
              saleId: saleId,
              number: number,
              replacedAt: ts,
              replacedBy: userId,
              notes: Value(notes),
              syncStatus: const Value('pending'),
            ),
          );

      for (final line in items) {
        if (line.quantityReturned <= 0 || line.quantityIssued <= 0) {
          throw const ValidationFailure(
            'Les quantités retournées et émises doivent être > 0.',
          );
        }

        final saleItem = saleItemById[line.returnedSaleItemId];
        if (saleItem == null || saleItem.productId == null) {
          throw ValidationFailure(
            'Ligne de vente #${line.returnedSaleItemId} introuvable.',
          );
        }

        final soldQty = saleItem.quantity.round();
        final prior = alreadyReturned[saleItem.id] ?? 0;
        final returnable = saleItemQuantityReturnable(
          soldQuantity: soldQty,
          alreadyReturned: prior,
        );
        if (line.quantityReturned > returnable) {
          throw ValidationFailure(
            'Retour trop élevé pour ${saleItem.productName} '
            '(reste retournable : $returnable).',
          );
        }
        alreadyReturned[saleItem.id] = prior + line.quantityReturned;

        final returnedProductId = saleItem.productId!;
        final issuedProduct = await findProduct(shopId, line.issuedProductId);
        if (issuedProduct == null) {
          throw NotFoundFailure(
            'Produit #${line.issuedProductId} introuvable.',
          );
        }
        if (issuedProduct.quantityInStock < line.quantityIssued) {
          throw ValidationFailure(
            'Stock insuffisant pour ${issuedProduct.name} '
            '(dispo ${issuedProduct.quantityInStock}).',
          );
        }

        final unitCostReturned = saleItem.unitCost ??
            (await lotDs.getReferenceUnitCost(
              shopId: shopId,
              productId: returnedProductId,
            ));

        // 1) Retour → stock + lot
        final qtyBeforeReturn = (await findProduct(shopId, returnedProductId))
                ?.quantityInStock ??
            0;
        await lotDs.createLot(
          shopId: shopId,
          productId: returnedProductId,
          sourceType: lot_entity.InventoryLotSourceType.saleReplacementReturn,
          sourceId: replacementId,
          unitCost: unitCostReturned,
          quantity: line.quantityReturned,
          receivedAt: ts,
        );
        final qtyAfterReturn = (await findProduct(shopId, returnedProductId))
                ?.quantityInStock ??
            (qtyBeforeReturn + line.quantityReturned);

        await _db.into(_db.stockMovements).insert(
              db.StockMovementsCompanion.insert(
                shopId: shopId,
                productId: returnedProductId,
                userId: userId,
                type: 'return',
                quantityChange: line.quantityReturned,
                quantityBefore: qtyBeforeReturn,
                quantityAfter: qtyAfterReturn,
                saleId: Value(saleId),
                reason: Value('Remplacement $number'),
                unitCost: Value(unitCostReturned),
                createdAt: ts,
              ),
            );

        // 2) Sortie produit de remplacement (FIFO)
        final qtyBeforeIssue = issuedProduct.quantityInStock;
        final slices = await lotDs.allocateFifo(
          shopId: shopId,
          productId: issuedProduct.id,
          quantity: line.quantityIssued,
        );
        final unitCostIssued =
            InventoryLotLocalDatasource.weightedUnitCost(slices);
        final qtyAfterIssue = (await findProduct(shopId, issuedProduct.id))
                ?.quantityInStock ??
            (qtyBeforeIssue - line.quantityIssued);

        await _db.into(_db.stockMovements).insert(
              db.StockMovementsCompanion.insert(
                shopId: shopId,
                productId: issuedProduct.id,
                userId: userId,
                type: 'sale',
                quantityChange: -line.quantityIssued,
                quantityBefore: qtyBeforeIssue,
                quantityAfter: qtyAfterIssue,
                saleId: Value(saleId),
                reason: Value('Remplacement $number'),
                unitCost: Value(unitCostIssued),
                createdAt: ts,
              ),
            );

        await _db.into(_db.saleReplacementItems).insert(
              db.SaleReplacementItemsCompanion.insert(
                shopId: shopId,
                replacementId: replacementId,
                returnedSaleItemId: saleItem.id,
                returnedProductId: returnedProductId,
                quantityReturned: line.quantityReturned,
                issuedProductId: issuedProduct.id,
                quantityIssued: line.quantityIssued,
                unitPriceIssued: line.unitPriceIssued,
                reason: line.reason.code,
                syncStatus: const Value('pending'),
              ),
            );
      }

      // Historique SO si vente liée à une livraison
      final delivery = await (_db.select(_db.salesOrderDeliveries)
            ..where(
              (d) => d.shopId.equals(shopId) & d.saleId.equals(saleId),
            )
            ..limit(1))
          .getSingleOrNull();
      if (delivery != null) {
        await _db.into(_db.salesOrderHistoryEntries).insert(
              db.SalesOrderHistoryEntriesCompanion.insert(
                shopId: shopId,
                salesOrderId: delivery.salesOrderId,
                action: 'replacement',
                performedBy: userId,
                performedAt: ts,
                details: Value(
                  'Remplacement $number via vente #$saleId',
                ),
              ),
            );
      }

      final row = await (_db.select(_db.saleReplacements)
            ..where((r) => r.id.equals(replacementId)))
          .getSingle();
      return _mapReplacement(shopId, row);
    });
  }

  Future<void> markReplacementSynced({
    required int shopId,
    required int replacementId,
    required String serverId,
  }) async {
    final now = nowMs();
    await (_db.update(_db.saleReplacements)
          ..where(
            (r) => r.id.equals(replacementId) & r.shopId.equals(shopId),
          ))
        .write(
      db.SaleReplacementsCompanion(
        serverId: Value(serverId),
        syncedAt: Value(now),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<SaleReplacement> _mapReplacement(
    int shopId,
    db.SaleReplacement row,
  ) async {
    final itemRows = await (_db.select(_db.saleReplacementItems)
          ..where((i) => i.replacementId.equals(row.id)))
        .get();

    final items = <SaleReplacementItem>[];
    for (final ir in itemRows) {
      final returned = await findProduct(shopId, ir.returnedProductId);
      final issued = await findProduct(shopId, ir.issuedProductId);
      items.add(
        SaleReplacementItem(
          id: ir.id,
          replacementId: ir.replacementId,
          returnedSaleItemId: ir.returnedSaleItemId,
          returnedProductId: ir.returnedProductId,
          returnedProductName: returned?.name,
          quantityReturned: ir.quantityReturned,
          issuedProductId: ir.issuedProductId,
          issuedProductName: issued?.name,
          quantityIssued: ir.quantityIssued,
          unitPriceIssued: ir.unitPriceIssued,
          reason: ir.reason,
        ),
      );
    }

    return SaleReplacement(
      id: row.id,
      shopId: row.shopId,
      saleId: row.saleId,
      number: row.number,
      replacedAt: row.replacedAt,
      replacedBy: row.replacedBy,
      notes: row.notes,
      items: items,
    );
  }
}
