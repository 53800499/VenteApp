import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/errors/failures.dart';
import '../../../../core/shop/shop_hierarchy.dart';
import '../../../../core/utils/time.dart';
import '../../../inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import '../../../inventory/domain/entities/inventory_lot_entities.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/entities/procurement_report_entities.dart';
import '../models/procurement_api_models.dart';

class ProcurementLocalDatasource {
  ProcurementLocalDatasource(this._db);

  final db.AppDatabase _db;
  db.AppDatabase get database => _db;

  // ---------------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------------
  Future<List<Supplier>> listSuppliers(int shopId) async {
    final rows = await (_db.select(_db.suppliers)
          ..where((s) => s.shopId.equals(shopId))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .get();

    return rows.map(_mapSupplierRow).toList();
  }

  Future<Supplier?> findSupplier(int shopId, int id) async {
    final row = await (_db.select(_db.suppliers)
          ..where((s) => s.shopId.equals(shopId) & s.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _mapSupplierRow(row) : null;
  }

  Future<Supplier> createSupplier(
    int shopId,
    String name, {
    String? phone,
    String? email,
    String? address,
  }) async {
    final timestamp = nowMs();
    final companion = db.SuppliersCompanion.insert(
      shopId: shopId,
      name: name,
      phone: Value(phone),
      email: Value(email),
      address: Value(address),
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    final id = await _db.into(_db.suppliers).insert(companion);
    return Supplier(
      id: id,
      shopId: shopId,
      name: name,
      phone: phone,
      email: email,
      address: address,
      isActive: true,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: 1,
    );
  }

  Future<Supplier> updateSupplier(
    int shopId,
    int id, {
    String? name,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
    String? serverId,
    String? syncStatus,
    int? version,
  }) async {
    final timestamp = nowMs();
    final companion = db.SuppliersCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      phone: phone != null ? Value(phone) : const Value.absent(),
      email: email != null ? Value(email) : const Value.absent(),
      address: address != null ? Value(address) : const Value.absent(),
      isActive: isActive != null ? Value(isActive) : const Value.absent(),
      serverId: serverId != null ? Value(serverId) : const Value.absent(),
      syncStatus: syncStatus != null ? Value(syncStatus) : const Value.absent(),
      version: version != null ? Value(version) : const Value.absent(),
      updatedAt: Value(timestamp),
    );

    await (_db.update(_db.suppliers)..where((s) => s.shopId.equals(shopId) & s.id.equals(id)))
        .write(companion);

    final updated = await findSupplier(shopId, id);
    if (updated == null) throw Exception('Fournisseur introuvable après mise à jour.');
    return updated;
  }

  Future<int> upsertSupplierFromRemote({
    required int shopId,
    required SupplierApiDto remote,
  }) async {
    final existing = await (_db.select(_db.suppliers)
          ..where((s) => s.shopId.equals(shopId) & (s.serverId.equals(remote.id.toString()) | s.name.equals(remote.name))))
        .getSingleOrNull();

    final timestamp = nowMs();
    final companion = db.SuppliersCompanion(
      shopId: Value(shopId),
      name: Value(remote.name),
      phone: Value(remote.phone),
      email: Value(remote.email),
      address: Value(remote.address),
      isActive: Value(remote.isActive),
      serverId: Value(remote.id.toString()),
      syncStatus: const Value('synced'),
      version: Value(remote.version),
      updatedAt: Value(timestamp),
    );

    if (existing == null) {
      return _db.into(_db.suppliers).insert(companion.copyWith(
            createdAt: Value(remote.createdAt),
          ));
    } else {
      await (_db.update(_db.suppliers)..where((s) => s.id.equals(existing.id)))
          .write(companion);
      return existing.id;
    }
  }

  // ---------------------------------------------------------------------------
  // Purchase Orders
  // ---------------------------------------------------------------------------
  Future<List<PurchaseOrder>> listPurchaseOrders(
    int shopId, {
    int? supplierId,
    String? status,
  }) async {
    final query = _db.select(_db.purchaseOrders).join([
      leftOuterJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchaseOrders.supplierId)),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.purchaseOrders.createdBy)),
    ])
      ..where(
        _db.purchaseOrders.shopId.equals(shopId) &
            (supplierId != null
                ? _db.purchaseOrders.supplierId.equals(supplierId)
                : const Constant(true)) &
            (status != null
                ? _db.purchaseOrders.status.equals(status)
                : const Constant(true)),
      )
      ..orderBy([OrderingTerm.desc(_db.purchaseOrders.orderedAt)]);

    final rows = await query.get();
    final orders = <PurchaseOrder>[];

    for (final row in rows) {
      final po = row.readTable(_db.purchaseOrders);
      final supplier = row.readTableOrNull(_db.suppliers);
      final user = row.readTableOrNull(_db.users);

      orders.add(PurchaseOrder(
        id: po.id,
        shopId: po.shopId,
        supplierId: po.supplierId,
        supplierName: supplier?.name,
        number: po.number,
        status: _parseOrderStatus(po.status),
        orderedAt: po.orderedAt,
        expectedAt: po.expectedAt,
        subtotal: po.subtotal,
        discount: po.discount,
        tax: po.tax,
        total: po.total,
        notes: po.notes,
        createdBy: po.createdBy,
        createdByName: user?.name,
        createdAt: po.createdAt,
        updatedAt: po.updatedAt,
        version: po.version,
        serverId: po.serverId,
      ));
    }

    return orders;
  }

  Future<PurchaseOrder?> findPurchaseOrder(int shopId, int id) async {
    final query = _db.select(_db.purchaseOrders).join([
      leftOuterJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchaseOrders.supplierId)),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.purchaseOrders.createdBy)),
    ])..where(_db.purchaseOrders.shopId.equals(shopId) & _db.purchaseOrders.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final po = row.readTable(_db.purchaseOrders);
    final supplier = row.readTableOrNull(_db.suppliers);
    final user = row.readTableOrNull(_db.users);

    final itemRows = await _listPurchaseOrderItems(shopId, id);

    return PurchaseOrder(
      id: po.id,
      shopId: po.shopId,
      supplierId: po.supplierId,
      supplierName: supplier?.name,
      number: po.number,
      status: _parseOrderStatus(po.status),
      orderedAt: po.orderedAt,
      expectedAt: po.expectedAt,
      subtotal: po.subtotal,
      discount: po.discount,
      tax: po.tax,
      total: po.total,
      notes: po.notes,
      createdBy: po.createdBy,
      createdByName: user?.name,
      createdAt: po.createdAt,
      updatedAt: po.updatedAt,
      version: po.version,
      serverId: po.serverId,
      items: itemRows,
    );
  }

  Future<List<PurchaseOrderItem>> _listPurchaseOrderItems(int shopId, int poId) async {
    final query = _db.select(_db.purchaseOrderItems).join([
      leftOuterJoin(_db.products, _db.products.id.equalsExp(_db.purchaseOrderItems.productId)),
    ])..where(_db.purchaseOrderItems.shopId.equals(shopId) & _db.purchaseOrderItems.purchaseOrderId.equals(poId));

    final rows = await query.get();
    return rows.map((row) {
      final pi = row.readTable(_db.purchaseOrderItems);
      final product = row.readTableOrNull(_db.products);
      return PurchaseOrderItem(
        id: pi.id,
        shopId: pi.shopId,
        purchaseOrderId: pi.purchaseOrderId,
        productId: pi.productId,
        productName: product?.name,
        quantityOrdered: pi.quantityOrdered,
        quantityReceived: pi.quantityReceived,
        unitCost: pi.unitCost,
        discount: pi.discount,
        tax: pi.tax,
        subtotal: pi.subtotal,
        version: pi.version,
        serverId: pi.serverId,
      );
    }).toList();
  }

  Future<PurchaseOrder> createPurchaseOrder(
    int shopId,
    int userId,
    int supplierId,
    String number,
    int orderedAt,
    int? expectedAt,
    int subtotal,
    int discount,
    int tax,
    int total,
    String? notes,
    List<Map<String, dynamic>> items,
  ) async {
    final timestamp = nowMs();
    final poId = await _db.into(_db.purchaseOrders).insert(
          db.PurchaseOrdersCompanion.insert(
            shopId: shopId,
            supplierId: supplierId,
            number: number,
            orderedAt: orderedAt,
            expectedAt: Value(expectedAt),
            subtotal: subtotal,
            discount: Value(discount),
            tax: Value(tax),
            total: total,
            notes: Value(notes),
            createdBy: userId,
            createdAt: timestamp,
            updatedAt: timestamp,
            syncStatus: const Value('pending'),
          ),
        );

    await _db.batch((batch) {
      for (final it in items) {
        batch.insert(
          _db.purchaseOrderItems,
          db.PurchaseOrderItemsCompanion.insert(
            shopId: shopId,
            purchaseOrderId: poId,
            productId: it['productId'] as int,
            quantityOrdered: it['quantityOrdered'] as int,
            unitCost: it['unitCost'] as int,
            discount: Value(it['discount'] as int? ?? 0),
            tax: Value(it['tax'] as int? ?? 0),
            subtotal: it['subtotal'] as int,
            syncStatus: const Value('pending'),
          ),
        );
      }
    });

    final created = await findPurchaseOrder(shopId, poId);
    if (created == null) throw Exception('Impossible de charger la commande créée.');
    return created;
  }

  Future<PurchaseOrder> updatePurchaseOrder(
    int shopId,
    int id, {
    String? number,
    int? supplierId,
    int? orderedAt,
    int? expectedAt,
    int? subtotal,
    int? discount,
    int? tax,
    int? total,
    String? notes,
    List<Map<String, dynamic>>? items,
    String? syncStatus,
    int? version,
  }) async {
    final timestamp = nowMs();
    await (_db.update(_db.purchaseOrders)
          ..where((p) => p.shopId.equals(shopId) & p.id.equals(id)))
        .write(
      db.PurchaseOrdersCompanion(
        number: number != null ? Value(number) : const Value.absent(),
        supplierId: supplierId != null ? Value(supplierId) : const Value.absent(),
        orderedAt: orderedAt != null ? Value(orderedAt) : const Value.absent(),
        expectedAt: expectedAt != null ? Value(expectedAt) : const Value.absent(),
        subtotal: subtotal != null ? Value(subtotal) : const Value.absent(),
        discount: discount != null ? Value(discount) : const Value.absent(),
        tax: tax != null ? Value(tax) : const Value.absent(),
        total: total != null ? Value(total) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        syncStatus: syncStatus != null ? Value(syncStatus) : const Value.absent(),
        version: version != null ? Value(version) : const Value.absent(),
        updatedAt: Value(timestamp),
      ),
    );

    if (items != null) {
      // Recreate items
      await (_db.delete(_db.purchaseOrderItems)
            ..where((i) => i.shopId.equals(shopId) & i.purchaseOrderId.equals(id)))
          .go();

      await _db.batch((batch) {
        for (final it in items) {
          batch.insert(
            _db.purchaseOrderItems,
            db.PurchaseOrderItemsCompanion.insert(
              shopId: shopId,
              purchaseOrderId: id,
              productId: it['productId'] as int,
              quantityOrdered: it['quantityOrdered'] as int,
              unitCost: it['unitCost'] as int,
              discount: Value(it['discount'] as int? ?? 0),
              tax: Value(it['tax'] as int? ?? 0),
              subtotal: it['subtotal'] as int,
            ),
          );
        }
      });
    }

    final updated = await findPurchaseOrder(shopId, id);
    if (updated == null) throw Exception('Commande introuvable après mise à jour.');
    return updated;
  }

  Future<void> updatePurchaseOrderStatus(int shopId, int id, String status) async {
    final timestamp = nowMs();
    await (_db.update(_db.purchaseOrders)
          ..where((p) => p.shopId.equals(shopId) & p.id.equals(id)))
        .write(
      db.PurchaseOrdersCompanion(
        status: Value(status),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<void> updatePurchaseOrderServerDetails(
    int shopId,
    int id, {
    required String serverId,
    required int version,
  }) async {
    await (_db.update(_db.purchaseOrders)
          ..where((p) => p.shopId.equals(shopId) & p.id.equals(id)))
        .write(
      db.PurchaseOrdersCompanion(
        serverId: Value(serverId),
        version: Value(version),
        syncStatus: const Value('synced'),
        syncedAt: Value(nowMs()),
      ),
    );
  }

  /// Applique la réponse API (création / détail) : serverId commande + lignes.
  Future<void> applyRemotePurchaseOrderSnapshot(
    int shopId,
    int localPoId,
    Map<String, dynamic> remote,
  ) async {
    final serverId = remote['id']?.toString();
    final version = (remote['version'] as num?)?.toInt() ?? 1;
    final status = remote['status'] as String? ?? 'draft';
    final timestamp = nowMs();

    if (serverId != null) {
      await (_db.update(_db.purchaseOrders)
            ..where((p) => p.shopId.equals(shopId) & p.id.equals(localPoId)))
          .write(
        db.PurchaseOrdersCompanion(
          serverId: Value(serverId),
          version: Value(version),
          status: Value(status),
          syncStatus: const Value('synced'),
          syncedAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
    }

    final items = remote['items'] as List?;
    if (items == null) return;

    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final remoteProductId = (raw['productId'] as num?)?.toInt();
      final remoteItemId = raw['id']?.toString();
      final itemVersion = (raw['version'] as num?)?.toInt() ?? 1;
      if (remoteProductId == null || remoteItemId == null) continue;

      final localProductId =
          await _resolveProductLocalId(shopId, remoteProductId.toString());
      if (localProductId == null) continue;

      final existingItem = await (_db.select(_db.purchaseOrderItems)
            ..where(
              (pi) =>
                  pi.shopId.equals(shopId) &
                  pi.purchaseOrderId.equals(localPoId) &
                  pi.productId.equals(localProductId),
            ))
          .getSingleOrNull();
      if (existingItem == null) continue;

      await (_db.update(_db.purchaseOrderItems)
            ..where((pi) => pi.id.equals(existingItem.id)))
          .write(
        db.PurchaseOrderItemsCompanion(
          serverId: Value(remoteItemId),
          version: Value(itemVersion),
          quantityReceived: Value(
            (raw['quantityReceived'] as num?)?.toInt() ??
                existingItem.quantityReceived,
          ),
          syncStatus: const Value('synced'),
          syncedAt: Value(timestamp),
        ),
      );
    }
  }

  Future<int> upsertPurchaseOrderFromRemote({
    required int shopId,
    required int defaultUserId,
    required PurchaseOrderApiDto remote,
  }) async {
    final existing = await (_db.select(_db.purchaseOrders)
          ..where((p) => p.shopId.equals(shopId) & p.serverId.equals(remote.id.toString())))
        .getSingleOrNull();

    // Map supplier serverId to localId
    final localSupplierId = await _resolveSupplierLocalId(shopId, remote.supplierId.toString());
    if (localSupplierId == null) return 0; // Wait for supplier to be synced

    final timestamp = nowMs();
    final companion = db.PurchaseOrdersCompanion(
      shopId: Value(shopId),
      supplierId: Value(localSupplierId),
      number: Value(remote.number),
      status: Value(remote.status),
      orderedAt: Value(remote.orderedAt),
      expectedAt: Value(remote.expectedAt),
      subtotal: Value(remote.subtotal),
      discount: Value(remote.discount),
      tax: Value(remote.tax),
      total: Value(remote.total),
      notes: Value(remote.notes),
      createdBy: Value(defaultUserId),
      serverId: Value(remote.id.toString()),
      syncStatus: const Value('synced'),
      version: Value(remote.version),
      updatedAt: Value(timestamp),
    );

    int localPoId;
    if (existing == null) {
      localPoId = await _db.into(_db.purchaseOrders).insert(companion.copyWith(
            createdAt: Value(remote.createdAt),
          ));
    } else {
      await (_db.update(_db.purchaseOrders)..where((p) => p.id.equals(existing.id)))
          .write(companion);
      localPoId = existing.id;
    }

    if (remote.items != null) {
      // Upsert Items
      for (final item in remote.items!) {
        final localProductId = await _resolveProductLocalId(shopId, item.productId.toString());
        if (localProductId == null) continue; // Skip item if product not found

        final existingItem = await (_db.select(_db.purchaseOrderItems)
              ..where((pi) => pi.purchaseOrderId.equals(localPoId) & pi.productId.equals(localProductId)))
            .getSingleOrNull();

        final itemCompanion = db.PurchaseOrderItemsCompanion(
          shopId: Value(shopId),
          purchaseOrderId: Value(localPoId),
          productId: Value(localProductId),
          quantityOrdered: Value(item.quantityOrdered),
          quantityReceived: Value(item.quantityReceived),
          unitCost: Value(item.unitCost),
          discount: Value(item.discount),
          tax: Value(item.tax),
          subtotal: Value(item.subtotal),
          serverId: Value(item.id.toString()),
          syncStatus: const Value('synced'),
          version: Value(item.version),
        );

        if (existingItem == null) {
          await _db.into(_db.purchaseOrderItems).insert(itemCompanion);
        } else {
          await (_db.update(_db.purchaseOrderItems)..where((pi) => pi.id.equals(existingItem.id)))
              .write(itemCompanion);
        }
      }
    }

    return localPoId;
  }

  // ---------------------------------------------------------------------------
  // Receipts (moteur unique : commande ou appro direct)
  // ---------------------------------------------------------------------------

  int _maxSequenceFromReferences(List<String> values, RegExp pattern) {
    var maxSeq = 0;
    for (final value in values) {
      final match = pattern.firstMatch(value.trim());
      if (match == null) continue;
      final seq = int.tryParse(match.group(1) ?? '') ?? 0;
      if (seq > maxSeq) maxSeq = seq;
    }
    return maxSeq;
  }

  Future<String> _nextNumberInGroup({
    required int shopId,
    required String prefix,
    required Future<List<String>> Function(List<int> groupIds) loadValues,
  }) async {
    final groupIds = await ShopHierarchy.groupShopIdsFromDb(_db, shopId);
    final values = await loadValues(groupIds);
    final pattern = RegExp(
      '^${RegExp.escape(prefix)}-(\\d+)\$',
      caseSensitive: false,
    );
    final seq = _maxSequenceFromReferences(values, pattern) + 1;
    return '$prefix-${seq.toString().padLeft(5, '0')}';
  }

  Future<bool> isReceiptNumberUsedInGroup({
    required int shopId,
    required String receiptNumber,
    int? excludeLocalId,
  }) async {
    final trimmed = receiptNumber.trim();
    if (trimmed.isEmpty) return false;
    final groupIds = await ShopHierarchy.groupShopIdsFromDb(_db, shopId);
    final row = await (_db.select(_db.purchaseReceipts)
          ..where(
            (r) =>
                r.shopId.isIn(groupIds) &
                r.receiptNumber.equals(trimmed) &
                (excludeLocalId != null
                    ? r.id.isNotValue(excludeLocalId)
                    : const Constant(true)),
          )
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<bool> isPurchaseOrderNumberUsedInGroup({
    required int shopId,
    required String number,
    int? excludeLocalId,
  }) async {
    final trimmed = number.trim();
    if (trimmed.isEmpty) return false;
    final groupIds = await ShopHierarchy.groupShopIdsFromDb(_db, shopId);
    final row = await (_db.select(_db.purchaseOrders)
          ..where(
            (p) =>
                p.shopId.isIn(groupIds) &
                p.number.equals(trimmed) &
                (excludeLocalId != null
                    ? p.id.isNotValue(excludeLocalId)
                    : const Constant(true)),
          )
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<bool> isInvoiceNumberUsedInGroup({
    required int shopId,
    required String invoiceNumber,
    int? excludeLocalId,
  }) async {
    final trimmed = invoiceNumber.trim();
    if (trimmed.isEmpty) return false;
    final groupIds = await ShopHierarchy.groupShopIdsFromDb(_db, shopId);
    final row = await (_db.select(_db.supplierInvoices)
          ..where(
            (i) =>
                i.shopId.isIn(groupIds) &
                i.invoiceNumber.equals(trimmed) &
                (excludeLocalId != null
                    ? i.id.isNotValue(excludeLocalId)
                    : const Constant(true)),
          )
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<String> nextDirectReceiptNumber(int shopId) {
    return _nextNumberInGroup(
      shopId: shopId,
      prefix: 'GR',
      loadValues: (groupIds) async {
        final rows = await (_db.select(_db.purchaseReceipts)
              ..where(
                (r) =>
                    r.shopId.isIn(groupIds) &
                    r.receiptType.equals(PurchaseReceiptType.direct),
              ))
            .get();
        return rows.map((r) => r.receiptNumber).toList();
      },
    );
  }

  Future<String> nextOrderReceiptNumber(int shopId) {
    return _nextNumberInGroup(
      shopId: shopId,
      prefix: 'BR',
      loadValues: (groupIds) async {
        final rows = await (_db.select(_db.purchaseReceipts)
              ..where((r) => r.shopId.isIn(groupIds)))
            .get();
        return rows.map((r) => r.receiptNumber).toList();
      },
    );
  }

  Future<String> nextPurchaseOrderNumber(int shopId) {
    return _nextNumberInGroup(
      shopId: shopId,
      prefix: 'PO',
      loadValues: (groupIds) async {
        final rows = await (_db.select(_db.purchaseOrders)
              ..where((p) => p.shopId.isIn(groupIds)))
            .get();
        return rows.map((p) => p.number).toList();
      },
    );
  }

  Future<String> nextSupplierInvoiceNumber(int shopId) {
    return _nextNumberInGroup(
      shopId: shopId,
      prefix: 'FAC',
      loadValues: (groupIds) async {
        final rows = await (_db.select(_db.supplierInvoices)
              ..where((i) => i.shopId.isIn(groupIds)))
            .get();
        return rows
            .map((i) => i.invoiceNumber)
            .where((n) => RegExp(r'^FAC-\d+$', caseSensitive: false).hasMatch(n))
            .toList();
      },
    );
  }

  Future<PurchaseReceipt?> findReceiptByNumber(int shopId, String receiptNumber) async {
    final trimmed = receiptNumber.trim();
    if (trimmed.isEmpty) return null;
    final row = await (_db.select(_db.purchaseReceipts)
          ..where(
            (r) => r.shopId.equals(shopId) & r.receiptNumber.equals(trimmed),
          )
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return findReceipt(shopId, row.id);
  }

  Future<SupplierPayment?> findPayment(int shopId, int id) async {
    final row = await (_db.select(_db.supplierPayments)
          ..where((p) => p.shopId.equals(shopId) & p.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return SupplierPayment(
      id: row.id,
      shopId: row.shopId,
      invoiceId: row.invoiceId,
      amount: row.amount,
      paymentMethod: _parsePaymentMethod(row.paymentMethod),
      paymentDate: row.paymentDate,
      reference: row.reference,
      createdAt: row.createdAt,
      version: row.version,
      serverId: row.serverId,
    );
  }

  Future<List<SupplierPayment>> listPaymentsForInvoice(
    int shopId,
    int invoiceId,
  ) async {
    final rows = await (_db.select(_db.supplierPayments)
          ..where((p) => p.shopId.equals(shopId) & p.invoiceId.equals(invoiceId)))
        .get();
    return rows
        .map(
          (p) => SupplierPayment(
            id: p.id,
            shopId: p.shopId,
            invoiceId: p.invoiceId,
            amount: p.amount,
            paymentMethod: _parsePaymentMethod(p.paymentMethod),
            paymentDate: p.paymentDate,
            reference: p.reference,
            createdAt: p.createdAt,
            version: p.version,
            serverId: p.serverId,
          ),
        )
        .toList();
  }

  Future<PurchaseReceipt> createReceipt(
    int shopId,
    int poId,
    String receiptNumber,
    int receivedAt,
    int receivedBy,
    String? notes,
    List<Map<String, dynamic>> items,
  ) {
    final poRow = (_db.select(_db.purchaseOrders)
          ..where((p) => p.shopId.equals(shopId) & p.id.equals(poId)));
    return poRow.getSingleOrNull().then((po) {
      if (po == null) {
        throw const ValidationFailure('Commande introuvable.');
      }
      final status = _parseOrderStatus(po.status);
      if (status != PurchaseOrderStatus.sent &&
          status != PurchaseOrderStatus.partiallyReceived) {
        throw ValidationFailure(
          'Réception impossible : la commande doit être envoyée '
          '(statut actuel : ${status.label}).',
        );
      }
      return createGoodsReceipt(
        shopId: shopId,
        supplierId: po.supplierId,
        purchaseOrderId: poId,
        receiptType: PurchaseReceiptType.fromOrder,
        receiptNumber: receiptNumber,
        receivedAt: receivedAt,
        receivedBy: receivedBy,
        notes: notes,
        items: items,
      );
    });
  }

  Future<PurchaseReceipt> createDirectReceipt({
    required int shopId,
    required int supplierId,
    required String receiptNumber,
    required int receivedAt,
    required int receivedBy,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) {
    return createGoodsReceipt(
      shopId: shopId,
      supplierId: supplierId,
      purchaseOrderId: null,
      receiptType: PurchaseReceiptType.direct,
      receiptNumber: receiptNumber,
      receivedAt: receivedAt,
      receivedBy: receivedBy,
      notes: notes,
      items: items,
    );
  }

  Future<PurchaseReceipt> createGoodsReceipt({
    required int shopId,
    required int supplierId,
    required int? purchaseOrderId,
    required String receiptType,
    required String receiptNumber,
    required int receivedAt,
    required int receivedBy,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final poRow = purchaseOrderId == null
        ? null
        : await (_db.select(_db.purchaseOrders)
              ..where(
                (p) =>
                    p.shopId.equals(shopId) & p.id.equals(purchaseOrderId!),
              ))
            .getSingleOrNull();
    final poNumber = poRow?.number;
    final timestamp = nowMs();
    final lotDs = InventoryLotLocalDatasource(_db);
    final isDirect = receiptType == PurchaseReceiptType.direct;
    final lotSource = isDirect
        ? InventoryLotSourceType.directProcurement
        : InventoryLotSourceType.procurementReceipt;

    return _db.transaction(() async {
      final recId = await _db.into(_db.purchaseReceipts).insert(
            db.PurchaseReceiptsCompanion.insert(
              shopId: shopId,
              purchaseOrderId: Value(purchaseOrderId),
              supplierId: supplierId,
              receiptType: Value(receiptType),
              receiptNumber: receiptNumber,
              receivedAt: receivedAt,
              receivedBy: receivedBy,
              notes: Value(notes),
              syncStatus: const Value('pending'),
            ),
          );

      for (final it in items) {
        final poItemId = it['purchaseOrderItemId'] as int?;
        final productId = it['productId'] as int;
        final quantity = it['quantityReceived'] as int;
        final unitCost = it['unitCost'] as int;

        final receiptItemId = await _db.into(_db.purchaseReceiptItems).insert(
              db.PurchaseReceiptItemsCompanion.insert(
                shopId: shopId,
                purchaseReceiptId: recId,
                purchaseOrderItemId: Value(poItemId),
                productId: productId,
                quantityReceived: quantity,
                unitCost: unitCost,
                batchNumber: Value(it['batchNumber'] as String?),
                expiryDate: Value(it['expiryDate'] as int?),
                syncStatus: const Value('pending'),
              ),
            );

        if (poItemId != null) {
          final curItem = await (_db.select(_db.purchaseOrderItems)
                ..where((i) => i.id.equals(poItemId)))
              .getSingleOrNull();
          if (curItem != null) {
            await (_db.update(_db.purchaseOrderItems)
                  ..where((i) => i.id.equals(poItemId)))
                .write(
              db.PurchaseOrderItemsCompanion(
                quantityReceived: Value(curItem.quantityReceived + quantity),
              ),
            );
          }
        }

        if (quantity > 0) {
          final productRow = await (_db.select(_db.products)
                ..where(
                  (p) => p.shopId.equals(shopId) & p.id.equals(productId),
                ))
              .getSingleOrNull();

          final qtyBefore = productRow?.quantityInStock ?? 0;

          await lotDs.createLot(
            shopId: shopId,
            productId: productId,
            sourceType: lotSource,
            sourceId: recId,
            purchaseReceiptItemId: receiptItemId,
            supplierId: supplierId,
            unitCost: unitCost,
            quantity: quantity,
            batchNumber: it['batchNumber'] as String?,
            expiryDate: it['expiryDate'] as int?,
            receivedAt: receivedAt,
          );

          await lotDs.updateLastPurchasePrice(
            productId: productId,
            unitCost: unitCost,
          );

          final productAfter = await (_db.select(_db.products)
                ..where(
                  (p) => p.shopId.equals(shopId) & p.id.equals(productId),
                ))
              .getSingleOrNull();
          final qtyAfter =
              productAfter?.quantityInStock ?? (qtyBefore + quantity);

          final movementReason = isDirect
              ? 'Approvisionnement direct (BR: $receiptNumber)'
              : 'Réception Commande #$poNumber (BR: $receiptNumber)';

          await _db.into(_db.stockMovements).insert(
                db.StockMovementsCompanion.insert(
                  shopId: shopId,
                  productId: productId,
                  userId: receivedBy,
                  type: 'restock',
                  quantityChange: quantity,
                  quantityBefore: qtyBefore,
                  quantityAfter: qtyAfter,
                  reason: Value(movementReason),
                  unitCost: Value(unitCost),
                  createdAt: timestamp,
                ),
              );
        }
      }

      if (purchaseOrderId != null) {
        final poItems = await _listPurchaseOrderItems(shopId, purchaseOrderId);
        var allReceived = true;
        for (final pi in poItems) {
          if (pi.quantityReceived < pi.quantityOrdered) {
            allReceived = false;
            break;
          }
        }

        await updatePurchaseOrderStatus(
          shopId,
          purchaseOrderId,
          allReceived ? 'received' : 'partially_received',
        );
      }

      final receipt = await findReceipt(shopId, recId);
      if (receipt == null) {
        throw StateError('Impossible de charger le bon de réception créé.');
      }
      return receipt;
    });
  }

  Future<List<PurchaseReceipt>> listDirectReceipts(
    int shopId, {
    int? supplierId,
    int limit = 50,
  }) async {
    final rows = await (_db.select(_db.purchaseReceipts)
          ..where(
            (r) =>
                r.shopId.equals(shopId) &
                r.receiptType.equals(PurchaseReceiptType.direct) &
                (supplierId != null
                    ? r.supplierId.equals(supplierId)
                    : const Constant(true)),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.receivedAt)])
          ..limit(limit))
        .get();

    final receipts = <PurchaseReceipt>[];
    for (final row in rows) {
      final rec = await findReceipt(shopId, row.id);
      if (rec != null) receipts.add(rec);
    }
    return receipts;
  }

  Future<PurchaseReceipt?> findReceipt(int shopId, int id) async {
    final query = _db.select(_db.purchaseReceipts).join([
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.purchaseReceipts.receivedBy)),
      leftOuterJoin(
        _db.suppliers,
        _db.suppliers.id.equalsExp(_db.purchaseReceipts.supplierId),
      ),
    ])..where(_db.purchaseReceipts.shopId.equals(shopId) & _db.purchaseReceipts.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final rec = row.readTable(_db.purchaseReceipts);
    final user = row.readTableOrNull(_db.users);
    final supplier = row.readTableOrNull(_db.suppliers);

    final itemRows = await (_db.select(_db.purchaseReceiptItems).join([
      leftOuterJoin(_db.products, _db.products.id.equalsExp(_db.purchaseReceiptItems.productId)),
    ])..where(_db.purchaseReceiptItems.shopId.equals(shopId) & _db.purchaseReceiptItems.purchaseReceiptId.equals(id)))
        .get();

    final items = itemRows.map((itRow) {
      final ri = itRow.readTable(_db.purchaseReceiptItems);
      final product = itRow.readTableOrNull(_db.products);
      return PurchaseReceiptItem(
        id: ri.id,
        shopId: ri.shopId,
        purchaseReceiptId: ri.purchaseReceiptId,
        purchaseOrderItemId: ri.purchaseOrderItemId,
        productId: ri.productId,
        productName: product?.name,
        quantityReceived: ri.quantityReceived,
        unitCost: ri.unitCost,
        batchNumber: ri.batchNumber,
        expiryDate: ri.expiryDate,
        version: ri.version,
        serverId: ri.serverId,
      );
    }).toList();

    return PurchaseReceipt(
      id: rec.id,
      shopId: rec.shopId,
      purchaseOrderId: rec.purchaseOrderId,
      supplierId: rec.supplierId,
      supplierName: supplier?.name,
      receiptType: rec.receiptType,
      receiptNumber: rec.receiptNumber,
      receivedAt: rec.receivedAt,
      receivedBy: rec.receivedBy,
      receivedByName: user?.name,
      notes: rec.notes,
      version: rec.version,
      serverId: rec.serverId,
      items: items,
    );
  }

  Future<List<PurchaseReceipt>> listReceipts(int shopId, int poId) async {
    final rows = await (_db.select(_db.purchaseReceipts)
          ..where((r) => r.shopId.equals(shopId) & r.purchaseOrderId.equals(poId))
          ..orderBy([(r) => OrderingTerm.desc(r.receivedAt)]))
        .get();

    final receipts = <PurchaseReceipt>[];
    for (final row in rows) {
      final rec = await findReceipt(shopId, row.id);
      if (rec != null) receipts.add(rec);
    }
    return receipts;
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------
  Future<void> addHistory(int shopId, int poId, String action, int performedBy, {String? details}) async {
    final timestamp = nowMs();
    await _db.into(_db.purchaseOrderHistoryEntries).insert(
          db.PurchaseOrderHistoryEntriesCompanion.insert(
            shopId: shopId,
            purchaseOrderId: poId,
            action: action,
            performedBy: performedBy,
            performedAt: timestamp,
            details: Value(details),
          ),
        );
  }

  Future<List<PurchaseOrderHistory>> listHistory(int shopId, int poId) async {
    final query = _db.select(_db.purchaseOrderHistoryEntries).join([
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.purchaseOrderHistoryEntries.performedBy)),
    ])
      ..where(_db.purchaseOrderHistoryEntries.shopId.equals(shopId) &
          _db.purchaseOrderHistoryEntries.purchaseOrderId.equals(poId))
      ..orderBy([OrderingTerm.desc(_db.purchaseOrderHistoryEntries.performedAt)]);

    final rows = await query.get();
    return rows.map((row) {
      final h = row.readTable(_db.purchaseOrderHistoryEntries);
      final user = row.readTableOrNull(_db.users);
      return PurchaseOrderHistory(
        id: h.id,
        shopId: h.shopId,
        purchaseOrderId: h.purchaseOrderId,
        action: h.action,
        performedBy: h.performedBy,
        performedByName: user?.name,
        performedAt: h.performedAt,
        details: h.details,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Invoices & Payments
  // ---------------------------------------------------------------------------
  Future<SupplierInvoice> createInvoice(
    int shopId,
    int? poId,
    String invoiceNumber,
    int supplierId,
    int invoiceDate,
    int? dueDate,
    int subtotal,
    int tax,
    int total,
  ) async {
    final timestamp = nowMs();
    final companion = db.SupplierInvoicesCompanion.insert(
      shopId: shopId,
      purchaseOrderId: Value(poId),
      invoiceNumber: invoiceNumber,
      supplierId: supplierId,
      invoiceDate: invoiceDate,
      dueDate: Value(dueDate),
      subtotal: subtotal,
      tax: Value(tax),
      total: total,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    final id = await _db.into(_db.supplierInvoices).insert(companion);
    return SupplierInvoice(
      id: id,
      shopId: shopId,
      purchaseOrderId: poId,
      invoiceNumber: invoiceNumber,
      supplierId: supplierId,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      subtotal: subtotal,
      tax: tax,
      total: total,
      status: SupplierInvoiceStatus.unpaid,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: 1,
    );
  }

  Future<SupplierInvoice?> findInvoiceForDirectReceipt(
    int shopId,
    PurchaseReceipt receipt,
  ) async {
    final candidates = <String>{
      'FAC-${receipt.receiptNumber}',
      receipt.receiptNumber,
    };

    for (final invoiceNumber in candidates) {
      final row = await (_db.select(_db.supplierInvoices)
            ..where(
              (i) =>
                  i.shopId.equals(shopId) &
                  i.invoiceNumber.equals(invoiceNumber),
            ))
          .getSingleOrNull();
      if (row != null) {
        return findInvoice(shopId, row.id);
      }
    }

    final fallback = await (_db.select(_db.supplierInvoices)
          ..where(
            (i) =>
                i.shopId.equals(shopId) &
                i.supplierId.equals(receipt.supplierId) &
                i.invoiceDate.equals(receipt.receivedAt) &
                i.purchaseOrderId.isNull(),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])
          ..limit(1))
        .getSingleOrNull();

    if (fallback == null) return null;
    return findInvoice(shopId, fallback.id);
  }

  Future<SupplierInvoice?> findInvoice(int shopId, int id) async {
    final query = _db.select(_db.supplierInvoices).join([
      leftOuterJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.supplierInvoices.supplierId)),
    ])..where(_db.supplierInvoices.shopId.equals(shopId) & _db.supplierInvoices.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final inv = row.readTable(_db.supplierInvoices);
    final supplier = row.readTableOrNull(_db.suppliers);

    final payRows = await (_db.select(_db.supplierPayments)
          ..where((p) => p.shopId.equals(shopId) & p.invoiceId.equals(id)))
        .get();

    final payments = payRows.map((p) => SupplierPayment(
          id: p.id,
          shopId: p.shopId,
          invoiceId: p.invoiceId,
          amount: p.amount,
          paymentMethod: _parsePaymentMethod(p.paymentMethod),
          paymentDate: p.paymentDate,
          reference: p.reference,
          createdAt: p.createdAt,
          version: p.version,
          serverId: p.serverId,
        )).toList();

    return SupplierInvoice(
      id: inv.id,
      shopId: inv.shopId,
      purchaseOrderId: inv.purchaseOrderId,
      invoiceNumber: inv.invoiceNumber,
      supplierId: inv.supplierId,
      supplierName: supplier?.name,
      invoiceDate: inv.invoiceDate,
      dueDate: inv.dueDate,
      subtotal: inv.subtotal,
      tax: inv.tax,
      total: inv.total,
      status: _parseInvoiceStatus(inv.status),
      createdAt: inv.createdAt,
      updatedAt: inv.updatedAt,
      version: inv.version,
      serverId: inv.serverId,
      payments: payments,
    );
  }

  Future<List<SupplierInvoice>> listInvoices(int shopId, {int? supplierId}) async {
    final query = _db.select(_db.supplierInvoices).join([
      leftOuterJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.supplierInvoices.supplierId)),
    ])
      ..where(
        _db.supplierInvoices.shopId.equals(shopId) &
            (supplierId != null
                ? _db.supplierInvoices.supplierId.equals(supplierId)
                : const Constant(true)),
      )
      ..orderBy([OrderingTerm.desc(_db.supplierInvoices.invoiceDate)]);

    final rows = await query.get();
    return rows.map((row) {
      final inv = row.readTable(_db.supplierInvoices);
      final supplier = row.readTableOrNull(_db.suppliers);
      return SupplierInvoice(
        id: inv.id,
        shopId: inv.shopId,
        purchaseOrderId: inv.purchaseOrderId,
        invoiceNumber: inv.invoiceNumber,
        supplierId: inv.supplierId,
        supplierName: supplier?.name,
        invoiceDate: inv.invoiceDate,
        dueDate: inv.dueDate,
        subtotal: inv.subtotal,
        tax: inv.tax,
        total: inv.total,
        status: _parseInvoiceStatus(inv.status),
        createdAt: inv.createdAt,
        updatedAt: inv.updatedAt,
        version: inv.version,
        serverId: inv.serverId,
      );
    }).toList();
  }

  Future<SupplierPayment> createPayment(
    int shopId,
    int invoiceId,
    int amount,
    String paymentMethod,
    int paymentDate,
    String? reference,
  ) async {
    final timestamp = nowMs();
    final companion = db.SupplierPaymentsCompanion.insert(
      shopId: shopId,
      invoiceId: invoiceId,
      amount: amount,
      paymentMethod: Value(paymentMethod),
      paymentDate: paymentDate,
      reference: Value(reference),
      createdAt: timestamp,
    );

    final id = await _db.into(_db.supplierPayments).insert(companion);
    
    // Update invoice status
    final paymentsSum = await sumPaymentsForInvoice(shopId, invoiceId);
    final invoice = await findInvoice(shopId, invoiceId);
    if (invoice != null) {
      final nextStatus = paymentsSum >= invoice.total ? 'paid' : 'partially_paid';
      await updateInvoiceStatus(shopId, invoiceId, nextStatus);
    }

    return SupplierPayment(
      id: id,
      shopId: shopId,
      invoiceId: invoiceId,
      amount: amount,
      paymentMethod: _parsePaymentMethod(paymentMethod),
      paymentDate: paymentDate,
      reference: reference,
      createdAt: timestamp,
      version: 1,
    );
  }

  Future<void> updateInvoiceStatus(int shopId, int id, String status) async {
    final timestamp = nowMs();
    await (_db.update(_db.supplierInvoices)
          ..where((i) => i.shopId.equals(shopId) & i.id.equals(id)))
        .write(
      db.SupplierInvoicesCompanion(
        status: Value(status),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<int> sumPaymentsForInvoice(int shopId, int invoiceId) async {
    final rows = await (_db.select(_db.supplierPayments)
          ..where((p) => p.shopId.equals(shopId) & p.invoiceId.equals(invoiceId)))
        .get();

    return rows.fold<int>(0, (sum, p) => sum + p.amount);
  }

  // ---------------------------------------------------------------------------
  // Rapports
  // ---------------------------------------------------------------------------
  Future<ProcurementReportSummary> buildReportSummary(int shopId) async {
    final now = nowMs();
    final orders = await (_db.select(_db.purchaseOrders)
          ..where((p) => p.shopId.equals(shopId)))
        .get();

    var pendingCount = 0;
    var pendingAmount = 0;
    var overdueCount = 0;
    var receivedCount = 0;
    var receivedAmount = 0;
    var cancelledCount = 0;

    final supplierTotals = <String, ({int count, int amount})>{};

    for (final po in orders) {
      final supplier = await (_db.select(_db.suppliers)
            ..where((s) => s.id.equals(po.supplierId)))
          .getSingleOrNull();
      final supplierName = supplier?.name ?? 'Fournisseur #${po.supplierId}';
      final acc = supplierTotals.putIfAbsent(
        supplierName,
        () => (count: 0, amount: 0),
      );
      supplierTotals[supplierName] = (
        count: acc.count + 1,
        amount: acc.amount + po.total,
      );

      switch (po.status) {
        case 'cancelled':
          cancelledCount++;
        case 'received':
          receivedCount++;
          receivedAmount += po.total;
        case 'validated':
        case 'sent':
        case 'partially_received':
          pendingCount++;
          pendingAmount += po.total;
          if (po.expectedAt != null && po.expectedAt! < now) {
            overdueCount++;
          }
      }
    }

    final invoices = await (_db.select(_db.supplierInvoices)
          ..where(
            (i) =>
                i.shopId.equals(shopId) &
                i.status.isNotIn(['paid']),
          ))
        .get();

    var unpaidCount = invoices.length;
    var unpaidAmount = 0;
    for (final inv in invoices) {
      final paid = await sumPaymentsForInvoice(shopId, inv.id);
      unpaidAmount += (inv.total - paid).clamp(0, inv.total);
    }

    final itemRows = await (_db.select(_db.purchaseOrderItems).join([
      innerJoin(
        _db.purchaseOrders,
        _db.purchaseOrders.id.equalsExp(_db.purchaseOrderItems.purchaseOrderId),
      ),
      leftOuterJoin(
        _db.products,
        _db.products.id.equalsExp(_db.purchaseOrderItems.productId),
      ),
    ])
          ..where(_db.purchaseOrderItems.shopId.equals(shopId)))
        .get();

    final productTotals = <String, ({int qty, int cost})>{};
    for (final row in itemRows) {
      final item = row.readTable(_db.purchaseOrderItems);
      final product = row.readTableOrNull(_db.products);
      final name = product?.name ?? 'Produit #${item.productId}';
      final acc = productTotals.putIfAbsent(name, () => (qty: 0, cost: 0));
      productTotals[name] = (
        qty: acc.qty + item.quantityOrdered,
        cost: acc.cost + item.subtotal,
      );
    }

    final topSuppliers = supplierTotals.entries
        .map(
          (e) => ProcurementSupplierStat(
            supplierName: e.key,
            orderCount: e.value.count,
            totalAmount: e.value.amount,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final topProducts = productTotals.entries
        .map(
          (e) => ProcurementProductStat(
            productName: e.key,
            quantityOrdered: e.value.qty,
            totalCost: e.value.cost,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalCost.compareTo(a.totalCost));

    return ProcurementReportSummary(
      pendingOrderCount: pendingCount,
      overdueOrderCount: overdueCount,
      receivedOrderCount: receivedCount,
      cancelledOrderCount: cancelledCount,
      pendingOrderAmount: pendingAmount,
      receivedOrderAmount: receivedAmount,
      unpaidInvoiceCount: unpaidCount,
      unpaidInvoiceAmount: unpaidAmount,
      topSuppliers: topSuppliers.take(5).toList(),
      topProducts: topProducts.take(10).toList(),
    );
  }

  Future<List<({int poId, String number, String supplierName})>>
      listOverduePurchaseOrders(int shopId) async {
    final now = nowMs();
    final rows = await (_db.select(_db.purchaseOrders).join([
      leftOuterJoin(
        _db.suppliers,
        _db.suppliers.id.equalsExp(_db.purchaseOrders.supplierId),
      ),
    ])
          ..where(
            _db.purchaseOrders.shopId.equals(shopId) &
                _db.purchaseOrders.status.isIn([
                  'validated',
                  'sent',
                  'partially_received',
                ]) &
                _db.purchaseOrders.expectedAt.isSmallerThanValue(now),
          ))
        .get();

    return rows
        .map(
          (row) => (
            poId: row.readTable(_db.purchaseOrders).id,
            number: row.readTable(_db.purchaseOrders).number,
            supplierName: row.readTableOrNull(_db.suppliers)?.name ??
                'Fournisseur',
          ),
        )
        .toList();
  }

  Future<List<({int invoiceId, String number, int amountDue})>>
      listOverdueSupplierInvoices(int shopId) async {
    final now = nowMs();
    final rows = await (_db.select(_db.supplierInvoices)
          ..where(
            (i) =>
                i.shopId.equals(shopId) &
                i.status.isNotIn(['paid']) &
                i.dueDate.isSmallerThanValue(now),
          ))
        .get();

    final result = <({int invoiceId, String number, int amountDue})>[];
    for (final inv in rows) {
      final paid = await sumPaymentsForInvoice(shopId, inv.id);
      final due = inv.total - paid;
      if (due > 0) {
        result.add((invoiceId: inv.id, number: inv.invoiceNumber, amountDue: due));
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Resolution Helpers
  // ---------------------------------------------------------------------------

  /// Métadonnées pour éviter un GET détail si la commande locale est à jour.
  Future<({int version, int updatedAt, String status, bool hasItems})?>
      findPurchaseOrderSyncMeta(
    int shopId,
    String serverId,
  ) async {
    final row = await (_db.select(_db.purchaseOrders)
          ..where(
            (p) => p.shopId.equals(shopId) & p.serverId.equals(serverId),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.id)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;

    final item = await (_db.select(_db.purchaseOrderItems)
          ..where((i) => i.purchaseOrderId.equals(row.id))
          ..limit(1))
        .getSingleOrNull();

    return (
      version: row.version,
      updatedAt: row.updatedAt,
      status: row.status,
      hasItems: item != null,
    );
  }

  Future<int?> resolveDefaultUserId(int shopId) async {
    final user = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(shopId) & u.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return user?.id;
  }

  Future<int?> _resolveSupplierLocalId(int shopId, String serverId) async {
    final row = await (_db.select(_db.suppliers)
          ..where((s) => s.shopId.equals(shopId) & s.serverId.equals(serverId))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int?> _resolveProductLocalId(int shopId, String serverId) async {
    final row = await (_db.select(_db.products)
          ..where((p) => p.shopId.equals(shopId) & p.serverId.equals(serverId))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  // ---------------------------------------------------------------------------
  // Mappers & Helpers
  // ---------------------------------------------------------------------------
  Supplier _mapSupplierRow(db.Supplier row) {
    return Supplier(
      id: row.id,
      shopId: row.shopId,
      name: row.name,
      phone: row.phone,
      email: row.email,
      address: row.address,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
      serverId: row.serverId,
    );
  }

  PurchaseOrderStatus _parseOrderStatus(String value) {
    if (value == 'partially_received') {
      return PurchaseOrderStatus.partiallyReceived;
    }
    return PurchaseOrderStatus.values.firstWhere(
      (e) => e.name == value || e.toString().split('.').last == value,
      orElse: () => PurchaseOrderStatus.draft,
    );
  }

  String orderStatusToDb(PurchaseOrderStatus status) => _orderStatusToDb(status);

  String _orderStatusToDb(PurchaseOrderStatus status) {
    return switch (status) {
      PurchaseOrderStatus.partiallyReceived => 'partially_received',
      _ => status.name,
    };
  }

  SupplierInvoiceStatus _parseInvoiceStatus(String value) {
    if (value == 'partially_paid') {
      return SupplierInvoiceStatus.partiallyPaid;
    }
    return SupplierInvoiceStatus.values.firstWhere(
      (e) => e.name == value || e.toString().split('.').last == value,
      orElse: () => SupplierInvoiceStatus.unpaid,
    );
  }

  /// Convertit la valeur stockée localement vers le format API.
  static String paymentMethodToApi(String stored) {
    return switch (stored) {
      'mtnMomo' => 'mtn_momo',
      'moovMoney' => 'moov_money',
      _ => stored,
    };
  }

  PurchasePaymentMethod _parsePaymentMethod(String value) {
    if (value == 'mtn_momo') return PurchasePaymentMethod.mtnMomo;
    if (value == 'moov_money') return PurchasePaymentMethod.moovMoney;
    return PurchasePaymentMethod.values.firstWhere(
      (e) => e.name == value || e.toString().split('.').last == value,
      orElse: () => PurchasePaymentMethod.cash,
    );
  }

  // ---------------------------------------------------------------------------
  // Remote upsert helpers (called by syncFromRemote)
  // ---------------------------------------------------------------------------

  Future<void> upsertPurchaseReceiptFromRemote({
    required int shopId,
    required int defaultUserId,
    required PurchaseReceiptApiDto remote,
  }) async {
    int? localPoId;
    if (remote.purchaseOrderId != null) {
      localPoId =
          await _resolvePoLocalId(shopId, remote.purchaseOrderId.toString());
      if (localPoId == null &&
          remote.receiptType != PurchaseReceiptType.direct) {
        return;
      }
    }

    final localSupplierId =
        await _resolveSupplierLocalId(shopId, remote.supplierId.toString());
    if (localSupplierId == null) return;

    final existing = await (_db.select(_db.purchaseReceipts)
          ..where((r) => r.shopId.equals(shopId) & r.serverId.equals(remote.id.toString())))
        .getSingleOrNull();

    var targetExisting = existing;
    if (targetExisting == null) {
      targetExisting = await (_db.select(_db.purchaseReceipts)
            ..where(
              (r) =>
                  r.shopId.equals(shopId) &
                  r.receiptNumber.equals(remote.receiptNumber) &
                  r.serverId.isNull(),
            ))
          .getSingleOrNull();
    }

    final companion = db.PurchaseReceiptsCompanion(
      shopId: Value(shopId),
      purchaseOrderId: Value(localPoId),
      supplierId: Value(localSupplierId),
      receiptType: Value(remote.receiptType),
      receiptNumber: Value(remote.receiptNumber),
      receivedAt: Value(remote.receivedAt),
      receivedBy: Value(remote.receivedBy),
      notes: Value(remote.notes),
      serverId: Value(remote.id.toString()),
      syncStatus: const Value('synced'),
      version: Value(remote.version),
    );

    int receiptId;
    if (targetExisting == null) {
      receiptId = await _db.into(_db.purchaseReceipts).insert(companion);
    } else {
      await (_db.update(_db.purchaseReceipts)..where((r) => r.id.equals(targetExisting!.id)))
          .write(companion);
      receiptId = targetExisting.id;
    }

    final lotDs = InventoryLotLocalDatasource(_db);
    final supplierId = localSupplierId;
    final lotSource = remote.receiptType == PurchaseReceiptType.direct
        ? InventoryLotSourceType.directProcurement
        : InventoryLotSourceType.procurementReceipt;

    if (remote.items != null) {
      for (final item in remote.items!) {
        final localProdId = await _resolveProductLocalId(shopId, item.productId.toString());
        if (localProdId == null) continue;

        int? localPoItemId;
        if (item.purchaseOrderItemId != null) {
          localPoItemId = await _resolvePoItemLocalId(
            shopId,
            item.purchaseOrderItemId.toString(),
          );
        }

        final existingItem = await (_db.select(_db.purchaseReceiptItems)
              ..where((ri) =>
                  ri.purchaseReceiptId.equals(receiptId) & ri.productId.equals(localProdId)))
            .getSingleOrNull();

        final itemCompanion = db.PurchaseReceiptItemsCompanion(
          shopId: Value(shopId),
          purchaseReceiptId: Value(receiptId),
          purchaseOrderItemId: Value(localPoItemId),
          productId: Value(localProdId),
          quantityReceived: Value(item.quantityReceived),
          unitCost: Value(item.unitCost),
          batchNumber: Value(item.batchNumber),
          expiryDate: Value(item.expiryDate),
          serverId: Value(item.id.toString()),
          syncStatus: const Value('synced'),
          version: Value(item.version),
        );

        int receiptItemId;
        if (existingItem == null) {
          receiptItemId = await _db.into(_db.purchaseReceiptItems).insert(itemCompanion);
        } else {
          await (_db.update(_db.purchaseReceiptItems)..where((ri) => ri.id.equals(existingItem.id)))
              .write(itemCompanion);
          receiptItemId = existingItem.id;
        }

        if (item.quantityReceived > 0) {
          final hasLot = await lotDs.hasLotForReceiptItem(receiptItemId);
          if (!hasLot) {
            await lotDs.createLot(
              shopId: shopId,
              productId: localProdId,
              sourceType: lotSource,
              sourceId: receiptId,
              purchaseReceiptItemId: receiptItemId,
              supplierId: supplierId,
              unitCost: item.unitCost,
              quantity: item.quantityReceived,
              batchNumber: item.batchNumber,
              expiryDate: item.expiryDate,
              receivedAt: remote.receivedAt,
            );
          }
          await lotDs.updateLastPurchasePrice(
            productId: localProdId,
            unitCost: item.unitCost,
          );
        }
      }
    }
  }

  Future<void> upsertSupplierInvoiceFromRemote({
    required int shopId,
    required SupplierInvoiceApiDto remote,
  }) async {
    final localSupplierId = await _resolveSupplierLocalId(shopId, remote.supplierId.toString());
    if (localSupplierId == null) return;

    int? localPoId;
    if (remote.purchaseOrderId != null) {
      localPoId = await _resolvePoLocalId(shopId, remote.purchaseOrderId!.toString());
    }

    final existing = await (_db.select(_db.supplierInvoices)
          ..where((i) => i.shopId.equals(shopId) & i.serverId.equals(remote.id.toString())))
        .getSingleOrNull();

    var targetExisting = existing;
    if (targetExisting == null) {
      targetExisting = await (_db.select(_db.supplierInvoices)
            ..where(
              (i) =>
                  i.shopId.equals(shopId) &
                  i.invoiceNumber.equals(remote.invoiceNumber) &
                  i.serverId.isNull(),
            ))
          .getSingleOrNull();
    }

    final timestamp = nowMs();
    final companion = db.SupplierInvoicesCompanion(
      shopId: Value(shopId),
      supplierId: Value(localSupplierId),
      purchaseOrderId: Value(localPoId),
      invoiceNumber: Value(remote.invoiceNumber),
      invoiceDate: Value(remote.invoiceDate),
      dueDate: Value(remote.dueDate),
      subtotal: Value(remote.subtotal),
      tax: Value(remote.tax),
      total: Value(remote.total),
      status: Value(remote.status),
      serverId: Value(remote.id.toString()),
      syncStatus: const Value('synced'),
      version: Value(remote.version),
      updatedAt: Value(timestamp),
    );

    if (targetExisting == null) {
      await _db.into(_db.supplierInvoices).insert(companion.copyWith(
            createdAt: Value(remote.createdAt),
          ));
    } else {
      await (_db.update(_db.supplierInvoices)..where((i) => i.id.equals(targetExisting!.id)))
          .write(companion);
    }
  }

  Future<void> upsertSupplierPaymentFromRemote({
    required int shopId,
    required SupplierPaymentApiDto remote,
  }) async {
    final localInvoiceId = await _resolveInvoiceLocalId(shopId, remote.invoiceId.toString());
    if (localInvoiceId == null) return;

    final existing = await (_db.select(_db.supplierPayments)
          ..where((p) => p.shopId.equals(shopId) & p.serverId.equals(remote.id.toString())))
        .getSingleOrNull();

    var targetExisting = existing;
    if (targetExisting == null) {
      targetExisting = await (_db.select(_db.supplierPayments)
            ..where(
              (p) =>
                  p.shopId.equals(shopId) &
                  p.invoiceId.equals(localInvoiceId) &
                  p.amount.equals(remote.amount) &
                  p.paymentDate.equals(remote.paymentDate) &
                  p.serverId.isNull(),
            ))
          .getSingleOrNull();
    }

    final companion = db.SupplierPaymentsCompanion(
      shopId: Value(shopId),
      invoiceId: Value(localInvoiceId),
      amount: Value(remote.amount),
      paymentMethod: Value(remote.paymentMethod),
      paymentDate: Value(remote.paymentDate),
      reference: Value(remote.reference),
      serverId: Value(remote.id.toString()),
      syncStatus: const Value('synced'),
      version: Value(remote.version),
    );

    if (targetExisting == null) {
      await _db.into(_db.supplierPayments).insert(companion.copyWith(
            createdAt: Value(remote.createdAt),
          ));
    } else {
      await (_db.update(_db.supplierPayments)..where((p) => p.id.equals(targetExisting!.id)))
          .write(companion);
    }
  }

  Future<void> linkInvoiceServerSync({
    required int shopId,
    required int localId,
    required String serverId,
    int version = 1,
  }) async {
    await (_db.update(_db.supplierInvoices)
          ..where((i) => i.shopId.equals(shopId) & i.id.equals(localId)))
        .write(db.SupplierInvoicesCompanion(
          serverId: Value(serverId),
          syncStatus: const Value('synced'),
          version: Value(version),
          updatedAt: Value(nowMs()),
        ));
  }

  Future<void> linkPaymentServerSync({
    required int shopId,
    required int localId,
    required String serverId,
    int version = 1,
  }) async {
    await (_db.update(_db.supplierPayments)
          ..where((p) => p.shopId.equals(shopId) & p.id.equals(localId)))
        .write(db.SupplierPaymentsCompanion(
          serverId: Value(serverId),
          syncStatus: const Value('synced'),
          version: Value(version),
        ));
  }

  Future<void> linkReceiptServerSync({
    required int shopId,
    required int localId,
    required String serverId,
    int version = 1,
  }) async {
    await (_db.update(_db.purchaseReceipts)
          ..where((r) => r.shopId.equals(shopId) & r.id.equals(localId)))
        .write(db.PurchaseReceiptsCompanion(
          serverId: Value(serverId),
          syncStatus: const Value('synced'),
          version: Value(version),
        ));
  }

  // ---------------------------------------------------------------------------
  // Resolution helpers for remote upsert
  // ---------------------------------------------------------------------------

  Future<int?> _resolvePoLocalId(int shopId, String serverId) async {
    final row = await (_db.select(_db.purchaseOrders)
          ..where((p) => p.shopId.equals(shopId) & p.serverId.equals(serverId))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int?> _resolveInvoiceLocalId(int shopId, String serverId) async {
    final row = await (_db.select(_db.supplierInvoices)
          ..where((i) => i.shopId.equals(shopId) & i.serverId.equals(serverId))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int?> _resolvePoItemLocalId(int shopId, String serverId) async {
    final row = await (_db.select(_db.purchaseOrderItems)
          ..where((i) => i.shopId.equals(shopId) & i.serverId.equals(serverId))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }
}
