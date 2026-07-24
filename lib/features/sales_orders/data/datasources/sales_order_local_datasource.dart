import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/device_id_storage.dart';
import '../../../../core/utils/time.dart';
import '../../../inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import '../../../sales/data/datasources/local/sales_local_datasource.dart';
import '../../../sales/domain/entities/sale_entities.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/sales_order_sync_rules.dart';

class SalesOrderLocalDatasource {
  SalesOrderLocalDatasource(this._db, {DeviceIdStorage? deviceIds})
      : _deviceIds = deviceIds;

  final db.AppDatabase _db;
  final DeviceIdStorage? _deviceIds;

  Future<String?> _currentDeviceId() async {
    final storage = _deviceIds;
    if (storage == null) return null;
    return storage.getOrCreate();
  }

  Future<db.SalesOrdersCompanion> _stampCompanion({
    required int userId,
    required int ts,
    required int nextVersion,
    String? status,
    Value<String?> notes = const Value.absent(),
  }) async {
    final deviceId = await _currentDeviceId();
    return db.SalesOrdersCompanion(
      status: status != null ? Value(status) : const Value.absent(),
      notes: notes,
      updatedAt: Value(ts),
      updatedBy: Value(userId),
      deviceId: Value(deviceId),
      version: Value(nextVersion),
      syncStatus: const Value('pending'),
    );
  }

  Future<String> nextOrderNumber(int shopId) async {
    final rows = await (_db.select(_db.salesOrders)
          ..where((t) => t.shopId.equals(shopId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .get();
    final next = rows.isEmpty ? 1 : rows.first.id + 1;
    return 'SO-${next.toString().padLeft(5, '0')}';
  }

  Future<String> nextDeliveryNumber(int shopId) async {
    final rows = await (_db.select(_db.salesOrderDeliveries)
          ..where((t) => t.shopId.equals(shopId)))
        .get();
    return 'DL-${(rows.length + 1).toString().padLeft(5, '0')}';
  }

  Future<List<SalesOrder>> listOrders({
    required int shopId,
    SalesOrderStatus? status,
    String? search,
  }) async {
    final query = _db.select(_db.salesOrders)
      ..where((t) => t.shopId.equals(shopId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (status != null) {
      query.where((t) => t.status.equals(status.code));
    }
    final rows = await query.get();
    final result = <SalesOrder>[];
    for (final row in rows) {
      final order = await findOrder(shopId: shopId, id: row.id);
      if (order == null) continue;
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!order.number.toLowerCase().contains(q) &&
            !order.customerName.toLowerCase().contains(q)) {
          continue;
        }
      }
      result.add(order);
    }
    return result;
  }

  Future<SalesOrder?> findOrder({
    required int shopId,
    required int id,
  }) async {
    final row = await (_db.select(_db.salesOrders)
          ..where((t) => t.shopId.equals(shopId) & t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapOrder(row, includeDetails: true);
  }

  Future<SalesOrder> createOrder({
    required int shopId,
    required int userId,
    required int customerId,
    required String number,
    required List<SalesOrderLineInput> items,
    String? notes,
    int? orderedAt,
  }) async {
    if (items.isEmpty) {
      throw const ValidationFailure('Ajoutez au moins un produit.');
    }
    final ts = nowMs();
    final ordered = orderedAt ?? ts;
    final subtotal = items.fold(0, (s, i) => s + i.lineTotal);

    return _db.transaction(() async {
      final deviceId = await _currentDeviceId();
      final orderId = await _db.into(_db.salesOrders).insert(
            db.SalesOrdersCompanion.insert(
              shopId: shopId,
              customerId: customerId,
              number: number,
              status: const Value('draft'),
              orderedAt: ordered,
              subtotal: subtotal,
              total: subtotal,
              notes: Value(notes),
              createdBy: userId,
              createdAt: ts,
              updatedAt: ts,
              updatedBy: Value(userId),
              deviceId: Value(deviceId),
              syncStatus: const Value('pending'),
            ),
          );

      for (final item in items) {
        await _db.into(_db.salesOrderItems).insert(
              db.SalesOrderItemsCompanion.insert(
                shopId: shopId,
                salesOrderId: orderId,
                productId: item.productId,
                quantityOrdered: item.quantityOrdered,
                unitPrice: item.unitPrice,
                lineTotal: item.lineTotal,
                syncStatus: const Value('pending'),
              ),
            );
      }

      await _addHistory(
        shopId: shopId,
        orderId: orderId,
        userId: userId,
        action: SalesOrderHistoryAction.created.code,
        details: 'Commande créée',
        ts: ts,
        payload: {
          'number': number,
          'customerId': customerId,
          'itemCount': items.length,
          'subtotal': subtotal,
        },
      );

      final order = await findOrder(shopId: shopId, id: orderId);
      return order!;
    });
  }

  Future<SalesOrder> updateDraft({
    required int shopId,
    required int userId,
    required int orderId,
    int? customerId,
    List<SalesOrderLineInput>? items,
    String? notes,
  }) async {
    final existing = await findOrder(shopId: shopId, id: orderId);
    if (existing == null) {
      throw const NotFoundFailure('Commande introuvable.');
    }
    if (existing.status != SalesOrderStatus.draft) {
      throw const ValidationFailure(
        'Seuls les brouillons peuvent être modifiés.',
      );
    }
    final ts = nowMs();

    return _db.transaction(() async {
      if (items != null) {
        if (items.isEmpty) {
          throw const ValidationFailure('Ajoutez au moins un produit.');
        }
        await (_db.delete(_db.salesOrderItems)
              ..where((t) => t.salesOrderId.equals(orderId)))
            .go();
        final subtotal = items.fold(0, (s, i) => s + i.lineTotal);
        for (final item in items) {
          await _db.into(_db.salesOrderItems).insert(
                db.SalesOrderItemsCompanion.insert(
                  shopId: shopId,
                  salesOrderId: orderId,
                  productId: item.productId,
                  quantityOrdered: item.quantityOrdered,
                  unitPrice: item.unitPrice,
                  lineTotal: item.lineTotal,
                  syncStatus: const Value('pending'),
                ),
              );
        }
        await (_db.update(_db.salesOrders)
              ..where((t) => t.id.equals(orderId)))
            .write(
          db.SalesOrdersCompanion(
            customerId: customerId != null
                ? Value(customerId)
                : const Value.absent(),
            subtotal: Value(subtotal),
            total: Value(subtotal),
            notes: notes != null ? Value(notes) : const Value.absent(),
            updatedAt: Value(ts),
            version: Value(existing.id), // bump via re-read
            syncStatus: const Value('pending'),
          ),
        );
      } else {
        await (_db.update(_db.salesOrders)
              ..where((t) => t.id.equals(orderId)))
            .write(
          db.SalesOrdersCompanion(
            customerId: customerId != null
                ? Value(customerId)
                : const Value.absent(),
            notes: notes != null ? Value(notes) : const Value.absent(),
            updatedAt: Value(ts),
            syncStatus: const Value('pending'),
          ),
        );
      }

      // Fix version bump properly
      final row = await (_db.select(_db.salesOrders)
            ..where((t) => t.id.equals(orderId)))
          .getSingle();
      final deviceId = await _currentDeviceId();
      await (_db.update(_db.salesOrders)..where((t) => t.id.equals(orderId)))
          .write(
        db.SalesOrdersCompanion(
          version: Value(row.version + 1),
          updatedAt: Value(ts),
          updatedBy: Value(userId),
          deviceId: Value(deviceId),
          syncStatus: const Value('pending'),
        ),
      );

      await _addHistory(
        shopId: shopId,
        orderId: orderId,
        userId: userId,
        action: SalesOrderHistoryAction.updated.code,
        details: 'Brouillon modifié',
        ts: ts,
        payload: {
          if (customerId != null) 'customerId': customerId,
          if (items != null) 'itemCount': items.length,
        },
      );

      return (await findOrder(shopId: shopId, id: orderId))!;
    });
  }

  Future<SalesOrder> confirmOrder({
    required int shopId,
    required int userId,
    required int orderId,
  }) async {
    return _transition(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
      allowed: {SalesOrderStatus.draft},
      next: SalesOrderStatus.confirmed,
      action: SalesOrderHistoryAction.confirmed.code,
      details: 'Commande confirmée',
    );
  }

  Future<SalesOrder> markPreparing({
    required int shopId,
    required int userId,
    required int orderId,
  }) async {
    return _transition(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
      allowed: {SalesOrderStatus.confirmed, SalesOrderStatus.preparing},
      next: SalesOrderStatus.preparing,
      action: SalesOrderHistoryAction.preparing.code,
      details: 'Mise en préparation',
    );
  }

  Future<SalesOrder> cancelOrder({
    required int shopId,
    required int userId,
    required int orderId,
    String? reason,
  }) async {
    final existing = await findOrder(shopId: shopId, id: orderId);
    if (existing == null) {
      throw const NotFoundFailure('Commande introuvable.');
    }
    if (!existing.canCancel) {
      throw const ValidationFailure(
        'Impossible d\'annuler : des livraisons existent déjà.',
      );
    }
    return _transition(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
      allowed: {
        SalesOrderStatus.draft,
        SalesOrderStatus.confirmed,
        SalesOrderStatus.preparing,
      },
      next: SalesOrderStatus.cancelled,
      action: SalesOrderHistoryAction.cancelled.code,
      details: reason ?? 'Commande annulée',
    );
  }

  Future<SalesOrder> closeOrder({
    required int shopId,
    required int userId,
    required int orderId,
  }) async {
    return _transition(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
      allowed: {SalesOrderStatus.delivered},
      next: SalesOrderStatus.closed,
      action: SalesOrderHistoryAction.closed.code,
      details: 'Commande clôturée',
    );
  }

  /// Valide une livraison : vente (accepté + remplacé) + pertes éventuelles.
  Future<SalesOrderDeliverResult> deliver({
    required int shopId,
    required int userId,
    required int orderId,
    required List<DeliveryLineInput> lines,
    required PaymentMethod paymentMethod,
    String? notes,
    String? driverName,
    String? vehiclePlate,
    SalesOrderRemainingReason? remainingReason,
    int? amountCash,
    int? amountMomo,
    int? amountCredit,
  }) async {
    if (lines.isEmpty) {
      throw const ValidationFailure('Aucune ligne de livraison.');
    }

    final order = await findOrder(shopId: shopId, id: orderId);
    if (order == null) {
      throw const NotFoundFailure('Commande introuvable.');
    }
    if (!order.canDeliver) {
      throw ValidationFailure(
        'Livraison impossible (statut : ${order.status.labelFr}).',
      );
    }

    var remainingAfter = 0;
    for (final item in order.items) {
      DeliveryLineInput? line;
      for (final l in lines) {
        if (l.salesOrderItemId == item.id) {
          line = l;
          break;
        }
      }
      final consumed = line == null
          ? 0
          : line.quantityAccepted +
              line.quantityRefused +
              line.quantityReplaced;
      remainingAfter += (item.quantityRemaining - consumed).clamp(0, item.quantityRemaining);
    }
    if (remainingAfter > 0 && remainingReason == null) {
      throw const ValidationFailure(
        'Indiquez pourquoi un reliquat reste après cette livraison.',
      );
    }
    final storedRemainingReason =
        remainingAfter > 0 ? remainingReason : null;

    final ts = nowMs();
    final salesLocal = SalesLocalDatasource(_db);
    final lotDs = InventoryLotLocalDatasource(_db);
    final stockLosses = <SalesOrderStockLoss>[];

    return _db.transaction(() async {
      final acceptedSnapshots =
          <({db.Product product, SaleLineDraft line, int lineTotal})>[];
      var acceptedSubtotal = 0;
      final reservedByProduct = <int, int>{};

      int available(db.Product product) =>
          product.quantityInStock - (reservedByProduct[product.id] ?? 0);

      void reserve(int productId, int qty) {
        reservedByProduct[productId] =
            (reservedByProduct[productId] ?? 0) + qty;
      }

      for (final line in lines) {
        SalesOrderItem? item;
        for (final i in order.items) {
          if (i.id == line.salesOrderItemId) {
            item = i;
            break;
          }
        }
        if (item == null) {
          throw const ValidationFailure('Ligne de commande introuvable.');
        }
        if (line.quantityAccepted < 0 ||
            line.quantityRefused < 0 ||
            line.quantityReplaced < 0) {
          throw const ValidationFailure('Quantités invalides.');
        }
        if (line.quantityAccepted +
                line.quantityRefused +
                line.quantityReplaced <=
            0) {
          throw const ValidationFailure(
            'Indiquez une quantité acceptée, refusée ou remplacée.',
          );
        }
        if (line.quantitySent !=
            line.quantityAccepted +
                line.quantityRefused +
                line.quantityReplaced) {
          throw const ValidationFailure(
            'Envoyé doit égaler accepté + refusé + remplacé.',
          );
        }
        if (line.quantitySent > item.quantityRemaining) {
          throw ValidationFailure(
            'Trop pour ${item.productName} '
            '(reste ${item.quantityRemaining}).',
          );
        }
        if (line.quantityRefused > 0 && line.refusalReason == null) {
          throw const ValidationFailure(
            'Motif de refus requis pour les quantités refusées.',
          );
        }
        if (line.quantityRefused > 0 && line.refusalDestination == null) {
          throw const ValidationFailure(
            'Destination du refus requise (retour stock ou perte).',
          );
        }
        if (line.quantityReplaced > 0) {
          if (line.replacementProductId == null ||
              line.replacementUnitPrice == null) {
            throw const ValidationFailure(
              'Produit et prix de remplacement requis.',
            );
          }
          if (line.replacementProductId == item.productId) {
            throw const ValidationFailure(
              'Le produit de remplacement doit être différent.',
            );
          }
        }

        if (line.quantityAccepted > 0) {
          final product = await salesLocal.findProduct(shopId, item.productId);
          if (product == null) {
            throw ValidationFailure('Produit introuvable : ${item.productName}');
          }
          if (available(product) < line.quantityAccepted) {
            throw ValidationFailure(
              'Stock insuffisant pour ${item.productName} '
              '(${available(product)}).',
            );
          }
          reserve(product.id, line.quantityAccepted);
          final lineTotal = line.quantityAccepted * item.unitPrice;
          acceptedSubtotal += lineTotal;
          acceptedSnapshots.add((
            product: product,
            line: SaleLineDraft(
              productId: item.productId,
              quantity: line.quantityAccepted,
              unitPrice: item.unitPrice,
            ),
            lineTotal: lineTotal,
          ));
        }

        if (line.quantityReplaced > 0) {
          final replacement = await salesLocal.findProduct(
            shopId,
            line.replacementProductId!,
          );
          if (replacement == null) {
            throw const ValidationFailure(
              'Produit de remplacement introuvable.',
            );
          }
          if (available(replacement) < line.quantityReplaced) {
            throw ValidationFailure(
              'Stock insuffisant pour ${replacement.name} '
              '(${available(replacement)}).',
            );
          }
          reserve(replacement.id, line.quantityReplaced);
          final unitPrice = line.replacementUnitPrice!;
          final lineTotal = line.quantityReplaced * unitPrice;
          acceptedSubtotal += lineTotal;
          acceptedSnapshots.add((
            product: replacement,
            line: SaleLineDraft(
              productId: replacement.id,
              quantity: line.quantityReplaced,
              unitPrice: unitPrice,
            ),
            lineTotal: lineTotal,
          ));
        }

        if (line.quantityRefused > 0 &&
            line.refusalDestination == SalesOrderRefusalDestination.loss) {
          final product = await salesLocal.findProduct(shopId, item.productId);
          if (product == null) {
            throw ValidationFailure('Produit introuvable : ${item.productName}');
          }
          if (available(product) < line.quantityRefused) {
            throw ValidationFailure(
              'Stock insuffisant pour enregistrer la perte '
              '(${item.productName} : ${available(product)}).',
            );
          }
          reserve(product.id, line.quantityRefused);
          final reason =
              'Perte livraison ${order.number} — '
              '${line.refusalReason?.labelFr ?? 'refus'}';
          stockLosses.add(
            SalesOrderStockLoss(
              productId: product.id,
              quantity: line.quantityRefused,
              reason: reason,
            ),
          );
        }
      }

      // Sorties stock : vente d'abord, puis pertes (FIFO cohérent).
      int? saleId;
      if (acceptedSnapshots.isNotEmpty) {
        final credit = amountCredit ??
            (paymentMethod == PaymentMethod.credit ? acceptedSubtotal : 0);
        final cash = amountCash ??
            (paymentMethod == PaymentMethod.cash ? acceptedSubtotal : 0);
        final momo = amountMomo ?? 0;
        final paid = cash + momo;
        final receipt = await salesLocal.nextReceiptNumber(shopId, ts);

        saleId = await _db.into(_db.sales).insert(
              db.SalesCompanion.insert(
                shopId: shopId,
                userId: userId,
                customerId: Value(order.customerId),
                receiptNumber: Value(receipt),
                saleType: const Value('standard'),
                subtotal: Value(acceptedSubtotal),
                totalAmount: acceptedSubtotal,
                amountPaid: Value(paid),
                amountCash: Value(cash),
                amountMomo: Value(momo),
                amountCredit: Value(credit),
                paymentMethod: Value(paymentMethod.code),
                status: const Value('completed'),
                note: Value(
                  notes ?? 'Livraison commande ${order.number}',
                ),
                createdAt: ts,
                updatedAt: Value(ts),
              ),
            );

        for (final snap in acceptedSnapshots) {
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

        if (credit > 0) {
          await _db.into(_db.debts).insert(
                db.DebtsCompanion.insert(
                  shopId: shopId,
                  customerId: order.customerId,
                  saleId: Value(saleId),
                  originalAmount: credit,
                  amountRemaining: credit,
                  createdAt: ts,
                ),
              );
        }
      }

      for (final loss in stockLosses) {
        final product = await salesLocal.findProduct(shopId, loss.productId);
        if (product == null) {
          throw ValidationFailure(
            'Produit introuvable pour perte #${loss.productId}',
          );
        }
        await _applyStockLoss(
          lotDs: lotDs,
          shopId: shopId,
          userId: userId,
          product: product,
          quantity: loss.quantity,
          reason: loss.reason,
          ts: ts,
        );
      }

      final deliveryNumber = await nextDeliveryNumber(shopId);
      final deliveryId = await _db.into(_db.salesOrderDeliveries).insert(
            db.SalesOrderDeliveriesCompanion.insert(
              shopId: shopId,
              salesOrderId: orderId,
              number: deliveryNumber,
              status: const Value('completed'),
              deliveredAt: ts,
              deliveredBy: userId,
              saleId: Value(saleId),
              notes: Value(notes),
              driverName: Value(driverName),
              vehiclePlate: Value(vehiclePlate),
              remainingReason: Value(storedRemainingReason?.code),
              createdAt: ts,
              syncStatus: const Value('pending'),
            ),
          );

      for (final line in lines) {
        final item =
            order.items.firstWhere((i) => i.id == line.salesOrderItemId);
        await _db.into(_db.salesOrderDeliveryItems).insert(
              db.SalesOrderDeliveryItemsCompanion.insert(
                shopId: shopId,
                deliveryId: deliveryId,
                salesOrderItemId: line.salesOrderItemId,
                productId: item.productId,
                quantitySent: line.quantitySent,
                quantityAccepted: line.quantityAccepted,
                quantityRefused: Value(line.quantityRefused),
                refusalReason: Value(line.refusalReason?.code),
                refusalDestination: Value(line.refusalDestination?.code),
                quantityReplaced: Value(line.quantityReplaced),
                replacementProductId: Value(line.replacementProductId),
                replacementUnitPrice: Value(line.replacementUnitPrice),
                unitPrice: item.unitPrice,
                syncStatus: const Value('pending'),
              ),
            );

        await (_db.update(_db.salesOrderItems)
              ..where((t) => t.id.equals(item.id)))
            .write(
          db.SalesOrderItemsCompanion(
            quantityDelivered:
                Value(item.quantityDelivered + line.quantityAccepted),
            quantityRefused:
                Value(item.quantityRefused + line.quantityRefused),
            quantityReplaced:
                Value(item.quantityReplaced + line.quantityReplaced),
            syncStatus: const Value('pending'),
          ),
        );
      }

      final refreshedItems = await _loadItems(shopId, orderId);
      final nextStatus = SalesOrder.statusAfterFulfillment(
        items: refreshedItems,
        current: order.status == SalesOrderStatus.confirmed
            ? SalesOrderStatus.preparing
            : order.status,
      );

      final row = await (_db.select(_db.salesOrders)
            ..where((t) => t.id.equals(orderId)))
          .getSingle();
      await (_db.update(_db.salesOrders)..where((t) => t.id.equals(orderId)))
          .write(
        await _stampCompanion(
          userId: userId,
          ts: ts,
          nextVersion: row.version + 1,
          status: nextStatus.code,
        ),
      );

      final historyParts = <String>[
        'Livraison $deliveryNumber',
        if (stockLosses.isNotEmpty) 'perte inventaire',
        if (lines.any((l) => l.quantityReplaced > 0)) 'remplacement',
      ];
      await _addHistory(
        shopId: shopId,
        orderId: orderId,
        userId: userId,
        action: SalesOrderHistoryAction.delivered.code,
        details: historyParts.join(' · '),
        ts: ts,
        payload: {
          'deliveryNumber': deliveryNumber,
          'deliveryId': deliveryId,
          'saleId': saleId,
          'status': nextStatus.code,
          if (storedRemainingReason != null)
            'remainingReason': storedRemainingReason.code,
          'accepted': lines.fold<int>(0, (s, l) => s + l.quantityAccepted),
          'refused': lines.fold<int>(0, (s, l) => s + l.quantityRefused),
          'replaced': lines.fold<int>(0, (s, l) => s + l.quantityReplaced),
        },
      );

      final deliveries = await _loadDeliveries(shopId, orderId);
      final delivery = deliveries.firstWhere((d) => d.id == deliveryId);
      return SalesOrderDeliverResult(
        delivery: delivery,
        stockLosses: List.unmodifiable(stockLosses),
      );
    });
  }

  Future<void> _applyStockLoss({
    required InventoryLotLocalDatasource lotDs,
    required int shopId,
    required int userId,
    required db.Product product,
    required int quantity,
    required String reason,
    required int ts,
  }) async {
    final quantityBefore = product.quantityInStock;
    final slices = await lotDs.allocateFifo(
      shopId: shopId,
      productId: product.id,
      quantity: quantity,
    );
    final unitCost = InventoryLotLocalDatasource.weightedUnitCost(slices);
    final productAfter = await (_db.select(_db.products)
          ..where(
            (t) => t.shopId.equals(shopId) & t.id.equals(product.id),
          ))
        .getSingleOrNull();
    final quantityAfter =
        productAfter?.quantityInStock ?? (quantityBefore - quantity);

    if (productAfter != null) {
      await (_db.update(_db.products)..where((t) => t.id.equals(product.id)))
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
            type: 'loss',
            quantityChange: -quantity,
            quantityBefore: quantityBefore,
            quantityAfter: quantityAfter,
            unitCost: Value(unitCost),
            reason: Value(reason),
            createdAt: ts,
          ),
        );
  }

  Future<SalesOrder> _transition({
    required int shopId,
    required int userId,
    required int orderId,
    required Set<SalesOrderStatus> allowed,
    required SalesOrderStatus next,
    required String action,
    required String details,
  }) async {
    final existing = await findOrder(shopId: shopId, id: orderId);
    if (existing == null) {
      throw const NotFoundFailure('Commande introuvable.');
    }
    if (!allowed.contains(existing.status)) {
      throw ValidationFailure(
        'Transition impossible depuis « ${existing.status.labelFr} ».',
      );
    }
    final ts = nowMs();
    final current = await (_db.select(_db.salesOrders)
          ..where((t) => t.id.equals(orderId)))
        .getSingle();
    await (_db.update(_db.salesOrders)..where((t) => t.id.equals(orderId)))
        .write(
      await _stampCompanion(
        userId: userId,
        ts: ts,
        nextVersion: current.version + 1,
        status: next.code,
      ),
    );
    await _addHistory(
      shopId: shopId,
      orderId: orderId,
      userId: userId,
      action: action,
      details: details,
      ts: ts,
      payload: {
        'fromStatus': existing.status.code,
        'toStatus': next.code,
      },
    );
    return (await findOrder(shopId: shopId, id: orderId))!;
  }

  Future<void> _addHistory({
    required int shopId,
    required int orderId,
    required int userId,
    required String action,
    required String details,
    required int ts,
    Map<String, dynamic>? payload,
  }) async {
    await _db.into(_db.salesOrderHistoryEntries).insert(
          db.SalesOrderHistoryEntriesCompanion.insert(
            shopId: shopId,
            salesOrderId: orderId,
            action: action,
            performedBy: userId,
            performedAt: ts,
            details: Value(details),
            payload: Value(
              payload == null || payload.isEmpty ? null : jsonEncode(payload),
            ),
          ),
        );
  }

  Future<SalesOrder> _mapOrder(
    db.SalesOrder row, {
    required bool includeDetails,
  }) async {
    final customer = await (_db.select(_db.customers)
          ..where((t) => t.id.equals(row.customerId)))
        .getSingleOrNull();
    final items = await _loadItems(row.shopId, row.id);
    final deliveries =
        includeDetails ? await _loadDeliveries(row.shopId, row.id) : const <SalesOrderDelivery>[];
    final history =
        includeDetails ? await _loadHistory(row.shopId, row.id) : const <SalesOrderHistoryEntry>[];

    return SalesOrder(
      id: row.id,
      shopId: row.shopId,
      customerId: row.customerId,
      customerName: customer?.name ?? 'Client #${row.customerId}',
      number: row.number,
      status: SalesOrderStatus.fromCode(row.status),
      orderedAt: row.orderedAt,
      subtotal: row.subtotal,
      discount: row.discount,
      tax: row.tax,
      total: row.total,
      notes: row.notes,
      createdBy: row.createdBy,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
      updatedBy: row.updatedBy,
      deviceId: row.deviceId,
      serverId: row.serverId,
      items: items,
      deliveries: deliveries,
      history: history,
    );
  }

  Future<List<SalesOrderItem>> _loadItems(int shopId, int orderId) async {
    final rows = await (_db.select(_db.salesOrderItems)
          ..where((t) =>
              t.shopId.equals(shopId) & t.salesOrderId.equals(orderId)))
        .get();
    final result = <SalesOrderItem>[];
    for (final row in rows) {
      final product = await (_db.select(_db.products)
            ..where((t) => t.id.equals(row.productId)))
          .getSingleOrNull();
      result.add(
        SalesOrderItem(
          id: row.id,
          salesOrderId: row.salesOrderId,
          productId: row.productId,
          productName: product?.name ?? 'Produit #${row.productId}',
          quantityOrdered: row.quantityOrdered,
          quantityDelivered: row.quantityDelivered,
          quantityRefused: row.quantityRefused,
          quantityReplaced: row.quantityReplaced,
          unitPrice: row.unitPrice,
          lineTotal: row.lineTotal,
          quantityInStock: product?.quantityInStock,
          serverId: row.serverId,
        ),
      );
    }
    return result;
  }

  Future<List<SalesOrderDelivery>> _loadDeliveries(
    int shopId,
    int orderId,
  ) async {
    final rows = await (_db.select(_db.salesOrderDeliveries)
          ..where((t) =>
              t.shopId.equals(shopId) & t.salesOrderId.equals(orderId))
          ..orderBy([(t) => OrderingTerm.desc(t.deliveredAt)]))
        .get();
    final result = <SalesOrderDelivery>[];
    for (final row in rows) {
      final itemRows = await (_db.select(_db.salesOrderDeliveryItems)
            ..where((t) => t.deliveryId.equals(row.id)))
          .get();
      final items = <SalesOrderDeliveryItem>[];
      for (final ir in itemRows) {
        final product = await (_db.select(_db.products)
              ..where((t) => t.id.equals(ir.productId)))
            .getSingleOrNull();
        String? replacementName;
        if (ir.replacementProductId != null) {
          final rp = await (_db.select(_db.products)
                ..where((t) => t.id.equals(ir.replacementProductId!)))
              .getSingleOrNull();
          replacementName = rp?.name;
        }
        items.add(
          SalesOrderDeliveryItem(
            id: ir.id,
            deliveryId: ir.deliveryId,
            salesOrderItemId: ir.salesOrderItemId,
            productId: ir.productId,
            productName: product?.name ?? 'Produit #${ir.productId}',
            quantitySent: ir.quantitySent,
            quantityAccepted: ir.quantityAccepted,
            quantityRefused: ir.quantityRefused,
            quantityReplaced: ir.quantityReplaced,
            unitPrice: ir.unitPrice,
            refusalReason:
                SalesOrderRefusalReason.fromCode(ir.refusalReason),
            refusalDestination: SalesOrderRefusalDestination.fromCode(
              ir.refusalDestination,
            ),
            replacementProductId: ir.replacementProductId,
            replacementProductName: replacementName,
            replacementUnitPrice: ir.replacementUnitPrice,
          ),
        );
      }
      result.add(
        SalesOrderDelivery(
          id: row.id,
          salesOrderId: row.salesOrderId,
          number: row.number,
          status: row.status,
          deliveredAt: row.deliveredAt,
          deliveredBy: row.deliveredBy,
          saleId: row.saleId,
          notes: row.notes,
          driverName: row.driverName,
          vehiclePlate: row.vehiclePlate,
          remainingReason:
              SalesOrderRemainingReason.fromCode(row.remainingReason),
          items: items,
        ),
      );
    }
    return result;
  }

  Future<List<SalesOrderHistoryEntry>> _loadHistory(
    int shopId,
    int orderId,
  ) async {
    final rows = await (_db.select(_db.salesOrderHistoryEntries)
          ..where((t) =>
              t.shopId.equals(shopId) & t.salesOrderId.equals(orderId))
          ..orderBy([(t) => OrderingTerm.desc(t.performedAt)]))
        .get();
    return rows
        .map(
          (r) {
            Map<String, dynamic>? payload;
            final raw = r.payload;
            if (raw != null && raw.isNotEmpty) {
              try {
                final decoded = jsonDecode(raw);
                if (decoded is Map) {
                  payload = Map<String, dynamic>.from(decoded);
                }
              } catch (_) {}
            }
            return SalesOrderHistoryEntry(
              id: r.id,
              action: r.action,
              performedBy: r.performedBy,
              performedAt: r.performedAt,
              details: r.details,
              payload: payload,
            );
          },
        )
        .toList();
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

    final productAfter = await (_db.select(_db.products)
          ..where((t) =>
              t.shopId.equals(shopId) & t.id.equals(product.id)))
        .getSingleOrNull();
    final quantityAfter =
        productAfter?.quantityInStock ?? (quantityBefore - qty);

    if (productAfter != null) {
      await (_db.update(_db.products)..where((t) => t.id.equals(product.id)))
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
            reason: const Value('Livraison commande client'),
            createdAt: ts,
          ),
        );
  }

  Future<void> markSynced({
    required int orderId,
    required String serverId,
    required int syncedAt,
  }) async {
    await (_db.update(_db.salesOrders)..where((t) => t.id.equals(orderId)))
        .write(
      db.SalesOrdersCompanion(
        serverId: Value(serverId),
        syncedAt: Value(syncedAt),
        syncStatus: const Value('synced'),
      ),
    );
  }

  /// Applique le snapshot remote (ids serveur commande + lignes).
  Future<void> applyRemoteSalesOrderSnapshot(
    int shopId,
    int localOrderId,
    Map<String, dynamic> remote,
  ) async {
    final remoteId = (remote['id'] as num?)?.toInt();
    if (remoteId == null) return;
    final ts = nowMs();
    await markSynced(
      orderId: localOrderId,
      serverId: '$remoteId',
      syncedAt: ts,
    );

    final remoteItems = remote['items'];
    if (remoteItems is! List) return;

    for (final raw in remoteItems) {
      final map = Map<String, dynamic>.from(raw as Map);
      final remoteProductId = (map['productId'] as num?)?.toInt();
      final itemId = (map['id'] as num?)?.toInt();
      if (remoteProductId == null || itemId == null) continue;

      final localProductId =
          await _resolveProductLocalId(shopId, '$remoteProductId');
      if (localProductId == null) continue;

      final existingItem = await (_db.select(_db.salesOrderItems)
            ..where(
              (t) =>
                  t.shopId.equals(shopId) &
                  t.salesOrderId.equals(localOrderId) &
                  t.productId.equals(localProductId),
            ))
          .getSingleOrNull();
      if (existingItem == null) continue;

      await (_db.update(_db.salesOrderItems)
            ..where((t) => t.id.equals(existingItem.id)))
          .write(
        db.SalesOrderItemsCompanion(
          serverId: Value('$itemId'),
          syncedAt: Value(ts),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  static int? coerceRemoteInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Future<db.SalesOrder?> findOrderRowByServerId(
    int shopId,
    String serverId,
  ) async {
    return (_db.select(_db.salesOrders)
          ..where(
            (t) => t.shopId.equals(shopId) & t.serverId.equals(serverId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> clearSyncConflict(int orderId) async {
    await (_db.update(_db.salesOrders)..where((t) => t.id.equals(orderId)))
        .write(
      db.SalesOrdersCompanion(
        syncStatus: const Value('synced'),
        syncedAt: Value(nowMs()),
      ),
    );
  }

  Future<void> markPendingSync(int orderId) async {
    await (_db.update(_db.salesOrders)..where((t) => t.id.equals(orderId)))
        .write(
      const db.SalesOrdersCompanion(syncStatus: Value('pending')),
    );
  }

  /// Importe / met à jour une commande depuis le cloud.
  /// Retourne l’id local, ou `null` si skip (version locale ≥ remote) / données insuffisantes.
  Future<int?> upsertOrderFromRemote({
    required int shopId,
    required Map<String, dynamic> remote,
    required int importUserId,
    bool force = false,
  }) async {
    final remoteId = coerceRemoteInt(remote['id']);
    if (remoteId == null) return null;
    final serverId = '$remoteId';
    final remoteVersion = coerceRemoteInt(remote['version']) ?? 1;
    final number = remote['number'] as String?;
    if (number == null || number.isEmpty) return null;

    var local = await findOrderRowByServerId(shopId, serverId);
    local ??= await (_db.select(_db.salesOrders)
          ..where((t) => t.shopId.equals(shopId) & t.number.equals(number))
          ..limit(1))
        .getSingleOrNull();

    if (shouldSkipSalesOrderRemoteUpsert(
      localVersion: local?.version,
      remoteVersion: remoteVersion,
      force: force,
    )) {
      return local?.id;
    }

    final remoteCustomerId = coerceRemoteInt(remote['customerId']);
    if (remoteCustomerId == null) return null;
    final localCustomerId =
        await _resolveCustomerLocalId(shopId, '$remoteCustomerId');
    if (localCustomerId == null) return null;

    final ts = nowMs();
    final status = (remote['status'] as String?) ?? 'draft';
    final orderedAt = coerceRemoteInt(remote['orderedAt']) ?? ts;
    final subtotal = coerceRemoteInt(remote['subtotal']) ?? 0;
    final discount = coerceRemoteInt(remote['discount']) ?? 0;
    final tax = coerceRemoteInt(remote['tax']) ?? 0;
    final total = coerceRemoteInt(remote['total']) ?? subtotal;
    final notes = remote['notes'] as String?;
    final updatedBy = coerceRemoteInt(remote['updatedBy']);
    final deviceId = remote['deviceId'] as String?;
    final createdAt = coerceRemoteInt(remote['createdAt']) ?? orderedAt;
    final updatedAt = coerceRemoteInt(remote['updatedAt']) ?? ts;
    final createdByRemote = coerceRemoteInt(remote['createdBy']);
    final createdByLocal = createdByRemote != null
        ? await _resolveUserLocalId(shopId, createdByRemote) ?? importUserId
        : importUserId;

    late final int localOrderId;
    if (local == null) {
      localOrderId = await _db.into(_db.salesOrders).insert(
            db.SalesOrdersCompanion.insert(
              shopId: shopId,
              customerId: localCustomerId,
              number: number,
              status: Value(status),
              orderedAt: orderedAt,
              subtotal: subtotal,
              discount: Value(discount),
              tax: Value(tax),
              total: total,
              notes: Value(notes),
              createdBy: createdByLocal,
              createdAt: createdAt,
              updatedAt: updatedAt,
              updatedBy: Value(updatedBy),
              deviceId: Value(deviceId),
              version: Value(remoteVersion),
              serverId: Value(serverId),
              syncedAt: Value(ts),
              syncStatus: const Value('synced'),
            ),
          );
    } else {
      localOrderId = local.id;
      await (_db.update(_db.salesOrders)..where((t) => t.id.equals(localOrderId)))
          .write(
        db.SalesOrdersCompanion(
          customerId: Value(localCustomerId),
          status: Value(status),
          orderedAt: Value(orderedAt),
          subtotal: Value(subtotal),
          discount: Value(discount),
          tax: Value(tax),
          total: Value(total),
          notes: Value(notes),
          updatedAt: Value(updatedAt),
          updatedBy: Value(updatedBy),
          deviceId: Value(deviceId),
          version: Value(remoteVersion),
          serverId: Value(serverId),
          syncedAt: Value(ts),
          syncStatus: const Value('synced'),
        ),
      );
    }

    await _upsertRemoteItems(
      shopId: shopId,
      localOrderId: localOrderId,
      remoteItems: remote['items'],
      ts: ts,
    );

    final deliveries = remote['deliveries'];
    if (deliveries is List) {
      await _upsertRemoteDeliveries(
        shopId: shopId,
        localOrderId: localOrderId,
        remoteDeliveries: deliveries,
        importUserId: importUserId,
        ts: ts,
      );
    }

    if (force) {
      await _addHistory(
        shopId: shopId,
        orderId: localOrderId,
        userId: importUserId,
        action: SalesOrderHistoryAction.updated.code,
        details: 'Résolution conflit — version serveur',
        ts: ts,
        payload: {
          'resolution': 'keep_server',
          'remoteVersion': remoteVersion,
        },
      );
    }

    return localOrderId;
  }

  Future<void> _upsertRemoteItems({
    required int shopId,
    required int localOrderId,
    required Object? remoteItems,
    required int ts,
  }) async {
    if (remoteItems is! List) return;

    for (final raw in remoteItems) {
      final map = Map<String, dynamic>.from(raw as Map);
      final remoteProductId = coerceRemoteInt(map['productId']);
      final itemServerId = coerceRemoteInt(map['id']);
      if (remoteProductId == null) continue;

      final localProductId =
          await _resolveProductLocalId(shopId, '$remoteProductId');
      if (localProductId == null) continue;

      final qtyOrdered = coerceRemoteInt(map['quantityOrdered']) ?? 0;
      final qtyDelivered = coerceRemoteInt(map['quantityDelivered']) ?? 0;
      final qtyRefused = coerceRemoteInt(map['quantityRefused']) ?? 0;
      final qtyReplaced = coerceRemoteInt(map['quantityReplaced']) ?? 0;
      final unitPrice = coerceRemoteInt(map['unitPrice']) ?? 0;
      final lineTotal =
          coerceRemoteInt(map['lineTotal']) ?? qtyOrdered * unitPrice;

      db.SalesOrderItem? existing;
      if (itemServerId != null) {
        existing = await (_db.select(_db.salesOrderItems)
              ..where(
                (t) =>
                    t.shopId.equals(shopId) &
                    t.salesOrderId.equals(localOrderId) &
                    t.serverId.equals('$itemServerId'),
              )
              ..limit(1))
            .getSingleOrNull();
      }
      existing ??= await (_db.select(_db.salesOrderItems)
            ..where(
              (t) =>
                  t.shopId.equals(shopId) &
                  t.salesOrderId.equals(localOrderId) &
                  t.productId.equals(localProductId),
            )
            ..limit(1))
          .getSingleOrNull();

      if (existing == null) {
        await _db.into(_db.salesOrderItems).insert(
              db.SalesOrderItemsCompanion.insert(
                shopId: shopId,
                salesOrderId: localOrderId,
                productId: localProductId,
                quantityOrdered: qtyOrdered,
                quantityDelivered: Value(qtyDelivered),
                quantityRefused: Value(qtyRefused),
                quantityReplaced: Value(qtyReplaced),
                unitPrice: unitPrice,
                lineTotal: lineTotal,
                serverId: Value(itemServerId?.toString()),
                syncedAt: Value(ts),
                syncStatus: const Value('synced'),
              ),
            );
      } else {
        await (_db.update(_db.salesOrderItems)
              ..where((t) => t.id.equals(existing!.id)))
            .write(
          db.SalesOrderItemsCompanion(
            quantityOrdered: Value(qtyOrdered),
            quantityDelivered: Value(qtyDelivered),
            quantityRefused: Value(qtyRefused),
            quantityReplaced: Value(qtyReplaced),
            unitPrice: Value(unitPrice),
            lineTotal: Value(lineTotal),
            serverId: Value(itemServerId?.toString() ?? existing.serverId),
            syncedAt: Value(ts),
            syncStatus: const Value('synced'),
          ),
        );
      }
    }
  }

  Future<void> _upsertRemoteDeliveries({
    required int shopId,
    required int localOrderId,
    required List<dynamic> remoteDeliveries,
    required int importUserId,
    required int ts,
  }) async {
    for (final raw in remoteDeliveries) {
      final map = Map<String, dynamic>.from(raw as Map);
      final deliveryServerId = coerceRemoteInt(map['id']);
      final deliveryNumber = map['number'] as String?;
      if (deliveryNumber == null || deliveryNumber.isEmpty) continue;

      db.SalesOrderDelivery? existing;
      if (deliveryServerId != null) {
        existing = await (_db.select(_db.salesOrderDeliveries)
              ..where(
                (t) =>
                    t.shopId.equals(shopId) &
                    t.salesOrderId.equals(localOrderId) &
                    t.serverId.equals('$deliveryServerId'),
              )
              ..limit(1))
            .getSingleOrNull();
      }
      existing ??= await (_db.select(_db.salesOrderDeliveries)
            ..where(
              (t) =>
                  t.shopId.equals(shopId) &
                  t.salesOrderId.equals(localOrderId) &
                  t.number.equals(deliveryNumber),
            )
            ..limit(1))
          .getSingleOrNull();

      final deliveredAt = coerceRemoteInt(map['deliveredAt']) ?? ts;
      final deliveredByRemote = coerceRemoteInt(map['deliveredBy']);
      final deliveredBy = deliveredByRemote != null
          ? await _resolveUserLocalId(shopId, deliveredByRemote) ??
              importUserId
          : importUserId;
      final remainingReason = map['remainingReason'] as String?;

      late final int localDeliveryId;
      if (existing == null) {
        localDeliveryId = await _db.into(_db.salesOrderDeliveries).insert(
              db.SalesOrderDeliveriesCompanion.insert(
                shopId: shopId,
                salesOrderId: localOrderId,
                number: deliveryNumber,
                status: Value((map['status'] as String?) ?? 'completed'),
                deliveredAt: deliveredAt,
                deliveredBy: deliveredBy,
                notes: Value(map['notes'] as String?),
                driverName: Value(map['driverName'] as String?),
                vehiclePlate: Value(map['vehiclePlate'] as String?),
                remainingReason: Value(remainingReason),
                createdAt: coerceRemoteInt(map['createdAt']) ?? deliveredAt,
                serverId: Value(deliveryServerId?.toString()),
                syncedAt: Value(ts),
                syncStatus: const Value('synced'),
              ),
            );
      } else {
        localDeliveryId = existing.id;
        await (_db.update(_db.salesOrderDeliveries)
              ..where((t) => t.id.equals(localDeliveryId)))
            .write(
          db.SalesOrderDeliveriesCompanion(
            status: Value((map['status'] as String?) ?? existing.status),
            deliveredAt: Value(deliveredAt),
            notes: Value(map['notes'] as String?),
            driverName: Value(map['driverName'] as String?),
            vehiclePlate: Value(map['vehiclePlate'] as String?),
            remainingReason: Value(remainingReason),
            serverId: Value(deliveryServerId?.toString() ?? existing.serverId),
            syncedAt: Value(ts),
            syncStatus: const Value('synced'),
          ),
        );
      }

      final items = map['items'];
      if (items is! List) continue;
      for (final rawItem in items) {
        final line = Map<String, dynamic>.from(rawItem as Map);
        final remoteSoItemId = coerceRemoteInt(line['salesOrderItemId']);
        final remoteProductId = coerceRemoteInt(line['productId']);
        if (remoteProductId == null) continue;

        final localProductId =
            await _resolveProductLocalId(shopId, '$remoteProductId');
        if (localProductId == null) continue;

        int? localSoItemId;
        if (remoteSoItemId != null) {
          final byServer = await (_db.select(_db.salesOrderItems)
                ..where(
                  (t) =>
                      t.shopId.equals(shopId) &
                      t.salesOrderId.equals(localOrderId) &
                      t.serverId.equals('$remoteSoItemId'),
                )
                ..limit(1))
              .getSingleOrNull();
          localSoItemId = byServer?.id;
        }
        localSoItemId ??= (await (_db.select(_db.salesOrderItems)
                  ..where(
                    (t) =>
                        t.shopId.equals(shopId) &
                        t.salesOrderId.equals(localOrderId) &
                        t.productId.equals(localProductId),
                  )
                  ..limit(1))
                .getSingleOrNull())
            ?.id;
        if (localSoItemId == null) continue;

        final existingDi = await (_db.select(_db.salesOrderDeliveryItems)
              ..where(
                (t) =>
                    t.deliveryId.equals(localDeliveryId) &
                    t.salesOrderItemId.equals(localSoItemId!),
              )
              ..limit(1))
            .getSingleOrNull();

        final qtySent = coerceRemoteInt(line['quantitySent']) ?? 0;
        final qtyAccepted = coerceRemoteInt(line['quantityAccepted']) ?? 0;
        final qtyRefused = coerceRemoteInt(line['quantityRefused']) ?? 0;
        final qtyReplaced = coerceRemoteInt(line['quantityReplaced']) ?? 0;
        final unitPrice = coerceRemoteInt(line['unitPrice']) ?? 0;
        final refusalReason = line['refusalReason'] as String?;
        final refusalDestination = line['refusalDestination'] as String?;
        final repProductRemote = coerceRemoteInt(line['replacementProductId']);
        final repProductLocal = repProductRemote != null
            ? await _resolveProductLocalId(shopId, '$repProductRemote')
            : null;

        if (existingDi == null) {
          await _db.into(_db.salesOrderDeliveryItems).insert(
                db.SalesOrderDeliveryItemsCompanion.insert(
                  shopId: shopId,
                  deliveryId: localDeliveryId,
                  salesOrderItemId: localSoItemId,
                  productId: localProductId,
                  quantitySent: qtySent,
                  quantityAccepted: qtyAccepted,
                  quantityRefused: Value(qtyRefused),
                  quantityReplaced: Value(qtyReplaced),
                  refusalReason: Value(refusalReason),
                  refusalDestination: Value(refusalDestination),
                  replacementProductId: Value(repProductLocal),
                  replacementUnitPrice:
                      Value(coerceRemoteInt(line['replacementUnitPrice'])),
                  unitPrice: unitPrice,
                  serverId: Value(coerceRemoteInt(line['id'])?.toString()),
                  syncedAt: Value(ts),
                  syncStatus: const Value('synced'),
                ),
              );
        } else {
          await (_db.update(_db.salesOrderDeliveryItems)
                ..where((t) => t.id.equals(existingDi.id)))
              .write(
            db.SalesOrderDeliveryItemsCompanion(
              quantitySent: Value(qtySent),
              quantityAccepted: Value(qtyAccepted),
              quantityRefused: Value(qtyRefused),
              quantityReplaced: Value(qtyReplaced),
              refusalReason: Value(refusalReason),
              refusalDestination: Value(refusalDestination),
              replacementProductId: Value(repProductLocal),
              replacementUnitPrice:
                  Value(coerceRemoteInt(line['replacementUnitPrice'])),
              unitPrice: Value(unitPrice),
              serverId: Value(
                coerceRemoteInt(line['id'])?.toString() ?? existingDi.serverId,
              ),
              syncedAt: Value(ts),
              syncStatus: const Value('synced'),
            ),
          );
        }
      }
    }
  }

  Future<int?> _resolveCustomerLocalId(int shopId, String serverId) async {
    final row = await (_db.select(_db.customers)
          ..where((c) => c.shopId.equals(shopId) & c.serverId.equals(serverId))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int?> _resolveUserLocalId(int shopId, int remoteUserId) async {
    final row = await (_db.select(_db.users)
          ..where(
            (u) =>
                u.shopId.equals(shopId) & u.serverId.equals('$remoteUserId'),
          )
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int> resolveFallbackUserId(int shopId) async {
    final row = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(shopId))
          ..limit(1))
        .getSingleOrNull();
    return row?.id ?? 1;
  }

  Future<int?> _resolveProductLocalId(int shopId, String serverId) async {
    final row = await (_db.select(_db.products)
          ..where((p) => p.shopId.equals(shopId) & p.serverId.equals(serverId))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  Future<void> markSyncConflict({
    required int orderId,
    required String message,
  }) async {
    await (_db.update(_db.salesOrders)..where((t) => t.id.equals(orderId)))
        .write(
      db.SalesOrdersCompanion(
        syncStatus: const Value('conflict'),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  /// Commandes ouvertes avec reliquat (feed notifications).
  Future<({int count, String? previewNumber})> countOpenWithRemaining(
    int shopId,
  ) async {
    final rows = await (_db.select(_db.salesOrders)
          ..where(
            (t) =>
                t.shopId.equals(shopId) &
                t.status.isIn([
                  SalesOrderStatus.confirmed.code,
                  SalesOrderStatus.preparing.code,
                  SalesOrderStatus.partiallyDelivered.code,
                ]),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    var count = 0;
    String? preview;
    for (final row in rows) {
      final items = await _loadItems(shopId, row.id);
      final remaining = items.fold(0, (s, i) => s + i.quantityRemaining);
      if (remaining <= 0) continue;
      count++;
      preview ??= row.number;
    }
    return (count: count, previewNumber: preview);
  }

  Future<SalesOrderFulfillmentReport> fulfillmentReport({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final deliveries = await (_db.select(_db.salesOrderDeliveries)
          ..where(
            (t) =>
                t.shopId.equals(shopId) &
                t.deliveredAt.isBiggerOrEqualValue(fromMs) &
                t.deliveredAt.isSmallerOrEqualValue(toMs),
          ))
        .get();

    final reasonQty = <String, int>{};
    final destQty = <String, int>{};
    final remainingCount = <String, int>{};

    for (final d in deliveries) {
      if (d.remainingReason != null && d.remainingReason!.isNotEmpty) {
        remainingCount[d.remainingReason!] =
            (remainingCount[d.remainingReason!] ?? 0) + 1;
      }
      final items = await (_db.select(_db.salesOrderDeliveryItems)
            ..where((t) => t.deliveryId.equals(d.id)))
          .get();
      for (final it in items) {
        if (it.quantityRefused <= 0) continue;
        final reason = it.refusalReason ?? 'other';
        reasonQty[reason] = (reasonQty[reason] ?? 0) + it.quantityRefused;
        final dest = it.refusalDestination ?? 'return_to_stock';
        destQty[dest] = (destQty[dest] ?? 0) + it.quantityRefused;
      }
    }

    List<SalesOrderReportBucket> mapReasons(Map<String, int> raw) {
      final buckets = <SalesOrderReportBucket>[];
      for (final e in raw.entries) {
        final known = SalesOrderRefusalReason.fromCode(e.key);
        buckets.add(
          SalesOrderReportBucket(
            code: e.key,
            labelFr: known?.labelFr ?? e.key,
            value: e.value,
          ),
        );
      }
      buckets.sort((a, b) => b.value.compareTo(a.value));
      return buckets;
    }

    List<SalesOrderReportBucket> mapDest(Map<String, int> raw) {
      final buckets = <SalesOrderReportBucket>[];
      for (final e in raw.entries) {
        final known = SalesOrderRefusalDestination.fromCode(e.key);
        buckets.add(
          SalesOrderReportBucket(
            code: e.key,
            labelFr: known?.labelFr ?? e.key,
            value: e.value,
          ),
        );
      }
      buckets.sort((a, b) => b.value.compareTo(a.value));
      return buckets;
    }

    List<SalesOrderReportBucket> mapRemaining(Map<String, int> raw) {
      final buckets = <SalesOrderReportBucket>[];
      for (final e in raw.entries) {
        final known = SalesOrderRemainingReason.fromCode(e.key);
        buckets.add(
          SalesOrderReportBucket(
            code: e.key,
            labelFr: known?.labelFr ?? e.key,
            value: e.value,
          ),
        );
      }
      buckets.sort((a, b) => b.value.compareTo(a.value));
      return buckets;
    }

    return SalesOrderFulfillmentReport(
      fromMs: fromMs,
      toMs: toMs,
      byRefusalReason: mapReasons(reasonQty),
      byDestination: mapDest(destQty),
      byRemainingReason: mapRemaining(remainingCount),
    );
  }
}
