import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../../core/sync/sync_constants.dart';
import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/errors/failures.dart';
import '../../../../../core/shop/shop_hierarchy.dart';
import '../../../../../core/utils/time.dart';
import '../../../inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../../inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import '../../../inventory/domain/entities/inventory_lot_entities.dart';
import '../../domain/entities/stock_transfer.dart';
import '../utils/stock_transfer_qr_payload.dart';

class StockTransferLocalDatasource {
  StockTransferLocalDatasource(this._db);

  final db.AppDatabase _db;

  Future<List<ShopOption>> listOtherShops(int currentShopId) async {
    final allShops = await _db.select(_db.shops).get();
    final groupIds =
        ShopHierarchy.groupShopIds(allShops, currentShopId).toSet();
    final rows = allShops
        .where(
          (s) =>
              s.id != currentShopId &&
              s.isActive &&
              groupIds.contains(s.id),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return rows
        .map(
          (s) => ShopOption(
            id: s.id,
            name: s.name,
            serverId: s.serverId,
            address: s.address,
          ),
        )
        .toList();
  }

  Future<String> nextReference(int shopId) async {
    final groupIds = await ShopHierarchy.groupShopIdsFromDb(_db, shopId);
    final rows = await (_db.select(_db.stockTransfers)
          ..where((t) => t.sourceShopId.isIn(groupIds)))
        .get();

    final seq = _maxTransferSequence(
      rows.map((row) => row.reference).toList(growable: false),
    ) + 1;
    return 'TRF-${seq.toString().padLeft(5, '0')}';
  }

  int _maxTransferSequence(List<String> references) {
    var maxSeq = 0;
    for (final reference in references) {
      final match = RegExp(r'^(?:TRF|RET)-(\d+)', caseSensitive: false)
          .firstMatch(reference.trim());
      if (match == null) continue;
      final seq = int.tryParse(match.group(1) ?? '') ?? 0;
      if (seq > maxSeq) maxSeq = seq;
    }
    return maxSeq;
  }

  Future<bool> isReferenceUsedInGroup({
    required int shopId,
    required String reference,
  }) async {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) return false;

    final groupIds = await ShopHierarchy.groupShopIdsFromDb(_db, shopId);
    final existing = await (_db.select(_db.stockTransfers)
          ..where(
            (t) =>
                t.reference.equals(trimmed) &
                t.sourceShopId.isIn(groupIds),
          )
          ..limit(1))
        .getSingleOrNull();
    return existing != null;
  }

  Future<void> updateTransferReference(int transferId, String reference) async {
    await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(transferId)))
        .write(
      db.StockTransfersCompanion(
        reference: Value(reference),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  Future<List<StockTransfer>> listOutgoing(int shopId) async {
    final shopIds = await localShopIdsInSameCloudShop(shopId);
    final rows = await (_db.select(_db.stockTransfers)
          ..where((t) => t.sourceShopId.isIn(shopIds.toList()))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return _mapTransfers(rows);
  }

  Future<List<StockTransfer>> listIncoming(int shopId) async {
    final shopIds = await localShopIdsInSameCloudShop(shopId);
    final rows = await (_db.select(_db.stockTransfers)
          ..where(
            (t) =>
                t.destinationShopId.isIn(shopIds.toList()) &
                t.status.isIn(StockTransferStatus.incomingTabStatuses),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return _mapTransfers(rows);
  }

  Future<List<StockTransfer>> listInTransit(int shopId) async {
    final shopIds = await localShopIdsInSameCloudShop(shopId);
    final rows = await (_db.select(_db.stockTransfers)
          ..where(
            (t) =>
                t.destinationShopId.isIn(shopIds.toList()) &
                t.status.isIn(StockTransferStatus.inTransitTabStatuses),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    final transfers = await _mapTransfers(rows);
    return transfers
        .where((transfer) => transfer.pendingReceptionQuantity > 0)
        .toList(growable: false);
  }

  Future<StockTransferReportSummary> buildReportSummary(int shopId) async {
    final outgoing = await listOutgoing(shopId);
    final incoming = await listIncoming(shopId);

    final seen = <int>{};
    final transferIds = <int>[];
    for (final transfer in [...outgoing, ...incoming]) {
      if (seen.add(transfer.id)) transferIds.add(transfer.id);
    }

    final rows = transferIds.isEmpty
        ? const <db.StockTransfer>[]
        : await (_db.select(_db.stockTransfers)
              ..where((t) => t.id.isIn(transferIds)))
            .get();
    final all = await _mapTransfers(rows, includeItems: true);

    var inTransit = 0;
    var discrepancyCount = 0;
    var totalShipped = 0;
    var totalReceived = 0;
    final discrepancies = <StockTransferDiscrepancyRow>[];

    for (final transfer in all) {
      if (transfer.status == StockTransferStatus.partiallyShipped ||
          transfer.status == StockTransferStatus.shipped ||
          transfer.status == StockTransferStatus.partiallyReceived) {
        inTransit++;
      }

      totalShipped += transfer.totalQuantityShipped;
      totalReceived += transfer.totalQuantityReceived;

      for (final item in transfer.items ?? []) {
        final openGap = item.openDiscrepancyQuantity(transfer.discrepancies ?? []);
        if (openGap > 0) {
          discrepancyCount++;
          discrepancies.add(
            StockTransferDiscrepancyRow(
              transferId: transfer.id,
              reference: transfer.reference,
              productName: item.productName ?? 'Produit #${item.sourceProductId}',
              quantityShipped: item.quantityShipped,
              quantityReceived: item.quantityReceived,
              status: transfer.status,
            ),
          );
        }
      }
    }

    return StockTransferReportSummary(
      totalTransfers: all.length,
      inTransitCount: inTransit,
      discrepancyCount: discrepancyCount,
      totalUnitsShipped: totalShipped,
      totalUnitsReceived: totalReceived,
      discrepancies: discrepancies,
    );
  }

  Future<StockTransfer?> findTransfer(
    int transferId, {
    bool cloudSyncEnabled = false,
  }) async {
    final row = await (_db.select(_db.stockTransfers)
          ..where((t) => t.id.equals(transferId)))
        .getSingleOrNull();
    if (row == null) return null;
    final transfers = await _mapTransfers([row], includeItems: true);
    var transfer = transfers.firstOrNull;
    if (transfer == null) return null;
    if (cloudSyncEnabled) {
      final pending = await fetchAllPendingSyncOperations(
        transferId: transferId,
        sourceShopId: transfer.sourceShopId,
        destinationShopId: transfer.destinationShopId,
      );
      transfer = transfer.copyWith(
        pendingSyncOperations: pending,
        cloudSyncEnabled: true,
      );
    }
    return transfer;
  }

  Future<List<String>> fetchAllPendingSyncOperations({
    required int transferId,
    required int sourceShopId,
    required int destinationShopId,
  }) async {
    final pending = <String>{
      ...await fetchPendingSyncOperations(
        shopId: sourceShopId,
        transferId: transferId,
      ),
      ...await fetchPendingSyncOperations(
        shopId: destinationShopId,
        transferId: transferId,
      ),
    };
    return pending.toList();
  }

  Future<List<String>> fetchPendingSyncOperations({
    required int shopId,
    required int transferId,
  }) async {
    final rows = await (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.entityTable.equals(SyncEntityTable.stockTransfers) &
                q.recordId.equals(transferId) &
                q.status.equals('pending'),
          ))
        .get();
    return rows.map((row) => row.operation).toList();
  }

  Future<String?> _lookupShopNameById(int shopId) async {
    final byId = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(shopId)))
        .getSingleOrNull();
    if (byId != null && byId.name.trim().isNotEmpty) {
      return byId.name.trim();
    }

    final byServerId = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('$shopId')))
        .getSingleOrNull();
    if (byServerId != null && byServerId.name.trim().isNotEmpty) {
      return byServerId.name.trim();
    }

    return null;
  }

  String? _pickShopName(String? first, [String? second, String? third]) {
    for (final candidate in [first, second, third]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Future<StockTransfer> createTransfer({
    required int sourceShopId,
    required int destinationShopId,
    required int userId,
    required String reference,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    if (sourceShopId == destinationShopId) {
      throw const ValidationFailure(
        'La boutique source et la destination doivent être différentes.',
      );
    }
    if (items.isEmpty) {
      throw const ValidationFailure('Ajoutez au moins un produit.');
    }

    final trimmedReference = reference.trim();
    if (trimmedReference.isEmpty) {
      throw const ValidationFailure('Référence obligatoire.');
    }
    if (await isReferenceUsedInGroup(
      shopId: sourceShopId,
      reference: trimmedReference,
    )) {
      throw ValidationFailure(
        'La référence « $trimmedReference » est déjà utilisée '
        'dans votre réseau commercial.',
      );
    }

    final inventoryLocal = InventoryLocalDatasource(_db);
    final timestamp = nowMs();
    final sourceShopName = await _lookupShopNameById(sourceShopId);
    final destinationShopName = await _lookupShopNameById(destinationShopId);

    return _db.transaction(() async {
      final transferId = await _db.into(_db.stockTransfers).insert(
            db.StockTransfersCompanion.insert(
              reference: trimmedReference,
              sourceShopId: sourceShopId,
              destinationShopId: destinationShopId,
              sourceShopName: Value(sourceShopName),
              destinationShopName: Value(destinationShopName),
              status: const Value(StockTransferStatus.draft),
              notes: Value(notes),
              createdBy: userId,
              createdAt: timestamp,
              updatedAt: timestamp,
              syncStatus: const Value('pending'),
            ),
          );

      for (final it in items) {
        final productId = it['productId'] as int;
        final qty = it['quantityRequested'] as int;
        if (qty <= 0) {
          throw const ValidationFailure('Quantité invalide.');
        }

        final product = await inventoryLocal.findProduct(sourceShopId, productId);
        if (product == null) {
          throw ValidationFailure('Produit #$productId introuvable.');
        }

        await _db.into(_db.stockTransferItems).insert(
              db.StockTransferItemsCompanion.insert(
                transferId: transferId,
                sourceProductId: productId,
                productServerId: Value(product.serverId),
                quantityRequested: qty,
              ),
            );
      }

      final created = await findTransfer(transferId);
      if (created == null) {
        throw StateError('Transfert introuvable après création.');
      }
      await _insertTransferEvent(
        transferId: transferId,
        shopId: sourceShopId,
        eventType: StockTransferEventType.created,
        actorUserId: userId,
        createdAt: timestamp,
      );
      return created;
    });
  }

  Future<StockTransfer> validateTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (transfer.sourceShopId != sourceShopId) {
      throw const ValidationFailure('Transfert non accessible depuis cette boutique.');
    }
    if (transfer.status != StockTransferStatus.draft &&
        transfer.status != StockTransferStatus.pendingApproval) {
      throw ValidationFailure(
        'Impossible de valider un transfert en statut « ${StockTransferStatus.label(transfer.status)} ».',
      );
    }

    final inventoryLocal = InventoryLocalDatasource(_db);
    final lotDs = InventoryLotLocalDatasource(_db);
    final timestamp = nowMs();

    return _db.transaction(() async {
      for (final item in transfer.items ?? []) {
        final product =
            await inventoryLocal.findProduct(sourceShopId, item.sourceProductId);
        if (product == null) {
          throw ValidationFailure(
            'Produit « ${item.productName ?? item.sourceProductId} » introuvable.',
          );
        }

        await lotDs.ensureLotsForAllocation(
          shopId: sourceShopId,
          productId: item.sourceProductId,
        );

        await _reserveFifoForItem(
          shopId: sourceShopId,
          transferItemId: item.id,
          productId: item.sourceProductId,
          quantity: item.quantityRequested,
          productLabel: product.name,
        );
      }

      await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(transferId)))
          .write(
        db.StockTransfersCompanion(
          status: const Value(StockTransferStatus.validated),
          validatedBy: Value(userId),
          validatedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncStatus: const Value('pending'),
        ),
      );

      await _insertTransferEvent(
        transferId: transferId,
        shopId: sourceShopId,
        eventType: StockTransferEventType.validated,
        actorUserId: userId,
        createdAt: timestamp,
      );

      final updated = await findTransfer(transferId);
      if (updated == null) {
        throw StateError('Transfert introuvable après validation.');
      }
      return updated;
    });
  }

  Future<StockTransfer> shipTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
    required String shipmentLabel,
    String? shipmentNotes,
    String? driverName,
    String? vehiclePlate,
    Map<int, int>? quantitiesByItemId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (transfer.sourceShopId != sourceShopId) {
      throw const ValidationFailure('Transfert non accessible depuis cette boutique.');
    }
    if (!StockTransferStatus.canShip(transfer.status)) {
      throw ValidationFailure(
        'Impossible d\'expédier un transfert en statut « ${StockTransferStatus.label(transfer.status)} ».',
      );
    }

    final inventoryLocal = InventoryLocalDatasource(_db);
    final timestamp = nowMs();

    return _db.transaction(() async {
      final shipmentReference = await _nextShipmentReference(
        transferId,
        transfer.reference,
      );
      final shipmentId = await _db.into(_db.stockTransferShipments).insert(
            db.StockTransferShipmentsCompanion.insert(
              transferId: transferId,
              reference: Value(shipmentReference),
              label: shipmentLabel.trim().isEmpty ? 'Expédition' : shipmentLabel.trim(),
              notes: Value(shipmentNotes),
              driverName: Value(driverName?.trim()),
              vehiclePlate: Value(vehiclePlate?.trim()),
              shippedBy: userId,
              shippedAt: timestamp,
            ),
          );

      var anyShippedThisRun = false;

      for (final item in transfer.items ?? []) {
        final qtyToShip = quantitiesByItemId?[item.id] ?? item.quantityPendingShip;
        if (qtyToShip <= 0) continue;

        if (qtyToShip > item.quantityPendingShip) {
          throw ValidationFailure(
            'Quantité expédiée trop élevée pour « ${item.productName ?? item.sourceProductId} ».',
          );
        }

        final product =
            await inventoryLocal.findProduct(sourceShopId, item.sourceProductId);
        if (product == null) {
          throw ValidationFailure(
            'Produit « ${item.productName ?? item.sourceProductId} » introuvable.',
          );
        }

        await InventoryLotLocalDatasource(_db).ensureLotsForAllocation(
          shopId: sourceShopId,
          productId: item.sourceProductId,
        );

        await _ensureReservationsForQuantity(
          shopId: sourceShopId,
          transferItemId: item.id,
          productId: item.sourceProductId,
          quantityNeeded: qtyToShip,
          productLabel: product.name,
        );

        final int qtyBefore = product.quantityInStock;
        final slices = await _consumeReservationsForShip(
          transferItemId: item.id,
          quantity: qtyToShip,
        );

        for (final slice in slices) {
          await _db.into(_db.stockTransferLotLines).insert(
                db.StockTransferLotLinesCompanion.insert(
                  transferItemId: item.id,
                  shipmentId: Value(shipmentId),
                  sourceLotId: Value(slice.lotId),
                  quantity: slice.quantity,
                  unitCost: slice.unitCost,
                ),
              );
        }

        final newShipped = item.quantityShipped + qtyToShip;
        await (_db.update(_db.stockTransferItems)
              ..where((i) => i.id.equals(item.id)))
            .write(
          db.StockTransferItemsCompanion(
            quantityShipped: Value(newShipped),
          ),
        );

        final productAfter =
            await inventoryLocal.findProduct(sourceShopId, item.sourceProductId);
        final int qtyAfter = (productAfter?.quantityInStock ??
                qtyBefore - qtyToShip)
            .toInt();

        await inventoryLocal.insertStockMovement(
          shopId: sourceShopId,
          productId: item.sourceProductId,
          userId: userId,
          type: 'transfer_out',
          quantityChange: -qtyToShip,
          quantityBefore: qtyBefore,
          quantityAfter: qtyAfter,
          reason: 'Transfert ${transfer.reference} · $shipmentLabel',
          unitCost: slices.isNotEmpty ? slices.first.unitCost : null,
        );

        anyShippedThisRun = true;
      }

      if (!anyShippedThisRun) {
        throw const ValidationFailure('Aucune quantité à expédier.');
      }

      final refreshed = await findTransfer(transferId);
      final items = refreshed?.items ?? [];
      var fullyShipped = true;
      for (final it in items) {
        if (it.quantityShipped < it.quantityRequested) {
          fullyShipped = false;
          break;
        }
      }

      final nextStatus = fullyShipped
          ? StockTransferStatus.shipped
          : StockTransferStatus.partiallyShipped;

      await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(transferId)))
          .write(
        db.StockTransfersCompanion(
          status: Value(nextStatus),
          shippedBy: Value(userId),
          shippedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncStatus: const Value('pending'),
        ),
      );

      await ensureDestinationProductsAtShip(
        destinationShopId: transfer.destinationShopId,
        sourceShopId: sourceShopId,
        transferId: transferId,
      );

      await _insertTransferEvent(
        transferId: transferId,
        shopId: sourceShopId,
        eventType: StockTransferEventType.shipped,
        actorUserId: userId,
        notes: shipmentNotes,
        payloadJson: '{"shipmentId":$shipmentId,"reference":"$shipmentReference"}',
        createdAt: timestamp,
      );

      final updated = await findTransfer(transferId);
      if (updated == null) {
        throw StateError('Transfert introuvable après expédition.');
      }
      return updated;
    });
  }

  Future<StockTransfer> receiveTransfer({
    required int destinationShopId,
    required int userId,
    required int transferId,
    Map<int, int>? quantitiesByItemId,
    Map<int, StockTransferReceiveRefusal>? refusalsByItemId,
    int? shipmentId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (!await isSameCloudShop(transfer.destinationShopId, destinationShopId)) {
      throw const ValidationFailure(
        'Ce transfert doit être réceptionné depuis la boutique destination.',
      );
    }
    final inventoryShopId = await canonicalLocalShopId(destinationShopId);
    if (!StockTransferStatus.canReceive(transfer.status)) {
      throw ValidationFailure(
        'Impossible de réceptionner un transfert en statut « ${StockTransferStatus.label(transfer.status)} ».',
      );
    }

    if (shipmentId != null) {
      final shipmentExists = (transfer.shipments ?? [])
          .any((shipment) => shipment.id == shipmentId);
      if (!shipmentExists) {
        throw const ValidationFailure('Expédition introuvable.');
      }
    }

    final inventoryLocal = InventoryLocalDatasource(_db);
    final lotDs = InventoryLotLocalDatasource(_db);
    final timestamp = nowMs();

    await _ensureLotLinesReadyForReceive(
      destinationShopId: inventoryShopId,
      transferId: transferId,
      inventoryLocal: inventoryLocal,
    );
    final readyTransfer = await findTransfer(transferId);
    if (readyTransfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }

    final received = await _db.transaction(() async {
      var anyPartial = false;
      var anyRefused = false;
      final plannedReceive = <int, int>{};
      final plannedRefusal = <int, StockTransferReceiveRefusal>{};

      for (final item in readyTransfer.items ?? []) {
        final maxForScope = shipmentId != null
            ? item.quantityPendingReceiveInShipment(shipmentId)
            : item.quantityPendingReceive;

        final refusal = refusalsByItemId?[item.id];
        final toRefuse = refusal?.quantity ?? 0;
        int toReceive;
        if (quantitiesByItemId != null || refusalsByItemId != null) {
          toReceive = quantitiesByItemId?[item.id] ?? 0;
        } else {
          toReceive = maxForScope;
        }

        if (toReceive <= 0 && toRefuse <= 0) continue;
        if (toReceive + toRefuse > maxForScope) {
          throw ValidationFailure(
            'Quantités reçues/refusées trop élevées pour '
            '« ${item.productName ?? item.sourceProductId} ».',
          );
        }
        if (toRefuse > 0 &&
            (refusal == null ||
                refusal.reason.isEmpty ||
                refusal.resolution.isEmpty)) {
          throw const ValidationFailure(
            'Motif et résolution requis pour toute quantité refusée.',
          );
        }

        if (toReceive > 0) plannedReceive[item.id] = toReceive;
        if (toRefuse > 0 && refusal != null) {
          plannedRefusal[item.id] = refusal;
        }
      }

      if (plannedReceive.isEmpty && plannedRefusal.isEmpty) {
        throw const ValidationFailure('Aucune quantité à traiter.');
      }

      final receiptReference = await _nextReceiptReference(
        transferId: transferId,
        transferReference: readyTransfer.reference,
      );
      final receiptId = await _db.into(_db.stockTransferReceipts).insert(
            db.StockTransferReceiptsCompanion.insert(
              transferId: transferId,
              shipmentId: Value(shipmentId),
              reference: receiptReference,
              receivedBy: userId,
              receivedAt: timestamp,
              createdAt: timestamp,
            ),
          );

      for (final item in readyTransfer.items ?? []) {
        final toReceive = plannedReceive[item.id] ?? 0;
        final refusal = plannedRefusal[item.id];
        final toRefuse = refusal?.quantity ?? 0;
        if (toReceive <= 0 && toRefuse <= 0) continue;

        final maxForScope = shipmentId != null
            ? item.quantityPendingReceiveInShipment(shipmentId)
            : item.quantityPendingReceive;

        if (toReceive + toRefuse > maxForScope) {
          throw ValidationFailure(
            'Quantités reçues/refusées trop élevées pour '
            '« ${item.productName ?? item.sourceProductId} ».',
          );
        }

        int? destProductId;
        if (toReceive > 0) {
          destProductId = await _resolveDestinationProductId(
            inventoryLocal: inventoryLocal,
            destinationShopId: inventoryShopId,
            sourceShopId: readyTransfer.sourceShopId,
            item: item,
          );
          if (destProductId == null) {
            throw ValidationFailure(
              'Produit « ${item.productName ?? item.sourceProductId} » introuvable '
              'dans la boutique destination. Créez-le ou synchronisez le catalogue.',
            );
          }

          await (_db.update(_db.stockTransferItems)
                ..where((i) => i.id.equals(item.id)))
              .write(
            db.StockTransferItemsCompanion(
              destinationProductId: Value(destProductId),
            ),
          );
        }

        if (toReceive > 0 && destProductId != null) {
          var remaining = toReceive;
          final lotLines = item.lotLines ?? [];
          final int productBefore =
              (await inventoryLocal.findProduct(inventoryShopId, destProductId))
                  ?.quantityInStock ??
              0;

          for (final line in lotLines) {
            if (remaining <= 0) break;
            if (shipmentId != null && line.shipmentId != shipmentId) continue;
            final pending = line.quantityPendingReceive;
            if (pending <= 0) continue;

            final int take = pending < remaining ? pending : remaining;
            final db.InventoryLot? sourceLot;
            if (line.sourceLotId != null) {
              sourceLot = await (_db.select(_db.inventoryLots)
                    ..where((l) => l.id.equals(line.sourceLotId!)))
                  .getSingleOrNull();
            } else {
              sourceLot = null;
            }

            final destLotId = await lotDs.createLot(
              shopId: inventoryShopId,
              productId: destProductId,
              sourceType: InventoryLotSourceType.stockTransferIn,
              sourceId: transferId,
              unitCost: line.unitCost,
              quantity: take,
              batchNumber: sourceLot?.batchNumber,
              expiryDate: sourceLot?.expiryDate,
              receivedAt: timestamp,
            );

            await (_db.update(_db.stockTransferLotLines)
                  ..where((l) => l.id.equals(line.id)))
                .write(
              db.StockTransferLotLinesCompanion(
                destinationLotId: Value(destLotId),
                quantityReceived: Value(line.quantityReceived + take),
              ),
            );

            remaining -= take;
          }

          if (remaining > 0) {
            throw ValidationFailure(
              'Lignes de lots insuffisantes pour réceptionner « ${item.productName} ».',
            );
          }

          final newReceived = item.quantityReceived + toReceive;
          await (_db.update(_db.stockTransferItems)
                ..where((i) => i.id.equals(item.id)))
              .write(
            db.StockTransferItemsCompanion(
              quantityReceived: Value(newReceived),
            ),
          );

          final productAfter =
              await inventoryLocal.findProduct(inventoryShopId, destProductId);
          final int qtyAfter = (productAfter?.quantityInStock ??
                  productBefore + toReceive)
              .toInt();

          await inventoryLocal.insertStockMovement(
            shopId: inventoryShopId,
            productId: destProductId,
            userId: userId,
            type: 'transfer_in',
            quantityChange: toReceive,
            quantityBefore: productBefore,
            quantityAfter: qtyAfter,
            reason: 'Transfert ${readyTransfer.reference} · $receiptReference',
            unitCost: lotLines.isNotEmpty ? lotLines.first.unitCost : null,
          );

          if (newReceived < item.quantityShipped) {
            anyPartial = true;
          }
        }

        if (toReceive > 0 || toRefuse > 0) {
          await _db.into(_db.stockTransferReceiptItems).insert(
                db.StockTransferReceiptItemsCompanion.insert(
                  receiptId: receiptId,
                  transferItemId: item.id,
                  quantityReceived: toReceive,
                  quantityRefused: Value(toRefuse),
                  refusalReason: Value(refusal?.reason),
                  refusalResolution: Value(refusal?.resolution),
                  createdAt: timestamp,
                ),
              );
        }

        if (toRefuse > 0 && refusal != null) {
          anyRefused = true;
          anyPartial = true;
          await _insertTransferEvent(
            transferId: transferId,
            shopId: inventoryShopId,
            eventType: StockTransferEventType.refused,
            actorUserId: userId,
            payloadJson:
                '{"itemId":${item.id},"quantity":$toRefuse,"reason":"${refusal.reason}","resolution":"${refusal.resolution}"}',
            createdAt: timestamp,
          );
        }
      }

      if (anyRefused) {
        anyPartial = true;
      }

      final refreshed = await findTransfer(transferId);
      final items = refreshed?.items ?? [];
      var complete = true;
      var partial = false;
      for (final it in items) {
        if (it.quantityReceived < it.quantityShipped) {
          complete = false;
          if (it.quantityReceived > 0) partial = true;
        }
      }

      final nextStatus = complete
          ? StockTransferStatus.received
          : (partial || anyPartial)
              ? StockTransferStatus.partiallyReceived
              : refreshed?.status ?? StockTransferStatus.shipped;

      await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(transferId)))
          .write(
        db.StockTransfersCompanion(
          status: Value(nextStatus),
          receivedBy: Value(userId),
          receivedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncStatus: const Value('pending'),
        ),
      );

      await _insertTransferEvent(
        transferId: transferId,
        shopId: inventoryShopId,
        eventType: StockTransferEventType.received,
        actorUserId: userId,
        payloadJson:
            '{"receiptId":$receiptId,"reference":"$receiptReference","shipmentId":${shipmentId ?? 'null'}}',
        createdAt: timestamp,
      );

      final updated = await findTransfer(transferId);
      if (updated == null) {
        throw StateError('Transfert introuvable après réception.');
      }
      return updated;
    });
    await clearObsoleteTransferQueueOps(transferId);
    return received;
  }

  Future<void> cancelTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (transfer.sourceShopId != sourceShopId) {
      throw const ValidationFailure('Transfert non accessible.');
    }

    final timestamp = nowMs();

    if (StockTransferStatus.canCancel(transfer.status)) {
      await _db.transaction(() async {
        if (transfer.status == StockTransferStatus.validated) {
          for (final item in transfer.items ?? []) {
            await _releaseItemReservations(item.id);
          }
        }

        await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(transferId)))
            .write(
          db.StockTransfersCompanion(
            status: const Value(StockTransferStatus.cancelled),
            updatedAt: Value(timestamp),
            syncStatus: const Value('pending'),
          ),
        );

        await _insertTransferEvent(
          transferId: transferId,
          shopId: sourceShopId,
          eventType: StockTransferEventType.cancelled,
          actorUserId: userId,
          createdAt: timestamp,
        );
      });
      return;
    }

    if (StockTransferStatus.canCancelWithRestock(transfer.status)) {
      throw const ValidationFailure(
        'Utilisez la clôture et la résolution d\'écart plutôt que l\'annulation.',
      );
    }

    throw const ValidationFailure('Ce transfert ne peut pas être annulé.');
  }

  Future<StockTransfer> closeTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
    String? notes,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (transfer.sourceShopId != sourceShopId) {
      throw const ValidationFailure('Transfert non accessible.');
    }
    if (!StockTransferStatus.canClose(transfer.status)) {
      throw ValidationFailure(
        'Impossible de clôturer un transfert en statut « ${StockTransferStatus.label(transfer.status)} ».',
      );
    }

    final timestamp = nowMs();
    final hasOpen = transfer.hasOpenDiscrepancy;
    final nextStatus = hasOpen
        ? StockTransferStatus.closedWithException
        : StockTransferStatus.closed;

    await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(transferId)))
        .write(
      db.StockTransfersCompanion(
        status: Value(nextStatus),
        closedBy: Value(userId),
        closedAt: Value(timestamp),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );

    await _insertTransferEvent(
      transferId: transferId,
      shopId: sourceShopId,
      eventType: hasOpen
          ? StockTransferEventType.closedWithException
          : StockTransferEventType.closed,
      actorUserId: userId,
      notes: notes,
      payloadJson: '{"hasOpenDiscrepancy":$hasOpen}',
      createdAt: timestamp,
    );

    final updated = await findTransfer(transferId);
    if (updated == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    return updated;
  }

  Future<StockTransfer> resolveDiscrepancy({
    required int sourceShopId,
    required int userId,
    required int transferId,
    required int itemId,
    required int quantity,
    required String reason,
    required String resolution,
    String? notes,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (transfer.sourceShopId != sourceShopId) {
      throw const ValidationFailure('Transfert non accessible.');
    }
    if (!StockTransferStatus.canResolveDiscrepancy(transfer.status)) {
      throw ValidationFailure(
        'Impossible de résoudre un écart en statut « ${StockTransferStatus.label(transfer.status)} ».',
      );
    }

    StockTransferItem? item;
    for (final row in transfer.items ?? []) {
      if (row.id == itemId) {
        item = row;
        break;
      }
    }
    if (item == null) {
      throw const ValidationFailure('Article introuvable.');
    }

    final openQty = item.openDiscrepancyQuantity(transfer.discrepancies ?? []);
    if (quantity <= 0 || quantity > openQty) {
      throw ValidationFailure('Quantité d\'écart invalide (max $openQty).');
    }

    final inventoryLocal = InventoryLocalDatasource(_db);
    final lotDs = InventoryLotLocalDatasource(_db);
    final timestamp = nowMs();

    if (resolution == StockTransferDiscrepancyResolution.restockSource) {
      await _restockUnreceivedLots(
        sourceShopId: sourceShopId,
        userId: userId,
        transfer: transfer,
        item: item,
        quantity: quantity,
        inventoryLocal: inventoryLocal,
        lotDs: lotDs,
        timestamp: timestamp,
      );
    }

    await _db.transaction(() async {
      await _db.into(_db.stockTransferDiscrepancies).insert(
            db.StockTransferDiscrepanciesCompanion.insert(
              transferId: transferId,
              transferItemId: itemId,
              quantity: quantity,
              reason: reason,
              resolution: resolution,
              notes: Value(notes),
              resolvedBy: userId,
              resolvedAt: timestamp,
              createdAt: timestamp,
            ),
          );

      await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(transferId)))
          .write(
        db.StockTransfersCompanion(
          updatedAt: Value(timestamp),
          syncStatus: const Value('pending'),
        ),
      );
    });

    await _insertTransferEvent(
      transferId: transferId,
      shopId: sourceShopId,
      eventType: StockTransferEventType.discrepancyResolved,
      actorUserId: userId,
      notes: notes,
      payloadJson:
          '{"itemId":$itemId,"quantity":$quantity,"reason":"$reason","resolution":"$resolution"}',
      createdAt: timestamp,
    );

    final updated = await findTransfer(transferId);
    if (updated == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    return updated;
  }

  Future<void> _restockUnreceivedLots({
    required int sourceShopId,
    required int userId,
    required StockTransfer transfer,
    required StockTransferItem item,
    required int quantity,
    required InventoryLocalDatasource inventoryLocal,
    required InventoryLotLocalDatasource lotDs,
    required int timestamp,
  }) async {
    final product =
        await inventoryLocal.findProduct(sourceShopId, item.sourceProductId);
    if (product == null) {
      throw ValidationFailure(
        'Produit « ${item.productName ?? item.sourceProductId} » introuvable.',
      );
    }

    var remaining = quantity;
    for (final line in item.lotLines ?? []) {
      if (remaining <= 0) break;
      if (line.quantityReceived > 0) continue;
      if (line.sourceLotId == null) continue;

      final int take =
          line.quantity < remaining ? line.quantity : remaining;
      final lot = await (_db.select(_db.inventoryLots)
            ..where((l) => l.id.equals(line.sourceLotId!)))
          .getSingleOrNull();
      if (lot == null) continue;

      final int newRemaining = lot.quantityRemaining + take;
      await (_db.update(_db.inventoryLots)..where((l) => l.id.equals(lot.id)))
          .write(
        db.InventoryLotsCompanion(
          quantityRemaining: Value(newRemaining),
          status: Value(
            newRemaining > 0 ? InventoryLotStatus.active : lot.status,
          ),
          version: Value(lot.version + 1),
        ),
      );
      remaining -= take;
    }

    if (remaining > 0) {
      throw const ValidationFailure(
        'Impossible de restocker la quantité demandée.',
      );
    }

    await lotDs.refreshProductStockFromLots(
      shopId: sourceShopId,
      productId: item.sourceProductId,
    );

    final productAfter =
        await inventoryLocal.findProduct(sourceShopId, item.sourceProductId);
    final qtyAfter =
        productAfter?.quantityInStock ?? product.quantityInStock + quantity;

    await inventoryLocal.insertStockMovement(
      shopId: sourceShopId,
      productId: item.sourceProductId,
      userId: userId,
      type: 'transfer_in',
      quantityChange: quantity,
      quantityBefore: product.quantityInStock,
      quantityAfter: qtyAfter,
      reason: 'Écart ${transfer.reference} · restock source',
      unitCost:
          item.lotLines?.isNotEmpty == true ? item.lotLines!.first.unitCost : null,
    );
  }

  Future<void> _insertTransferEvent({
    required int transferId,
    required int shopId,
    required String eventType,
    required int actorUserId,
    String? notes,
    String? payloadJson,
    required int createdAt,
  }) async {
    await _db.into(_db.stockTransferEvents).insert(
          db.StockTransferEventsCompanion.insert(
            transferId: transferId,
            shopId: shopId,
            eventType: eventType,
            actorUserId: actorUserId,
            notes: Value(notes),
            payloadJson: Value(payloadJson),
            createdAt: createdAt,
          ),
        );
  }

  Future<List<StockTransferEvent>> _loadEvents(int transferId) async {
    final rows = await (_db.select(_db.stockTransferEvents)
          ..where((e) => e.transferId.equals(transferId))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .get();
    return rows
        .map(
          (e) => StockTransferEvent(
            id: e.id,
            transferId: e.transferId,
            shopId: e.shopId,
            eventType: e.eventType,
            actorUserId: e.actorUserId,
            notes: e.notes,
            payloadJson: e.payloadJson,
            createdAt: e.createdAt,
          ),
        )
        .toList();
  }

  Future<List<StockTransferDiscrepancy>> _loadDiscrepancies(int transferId) async {
    final rows = await (_db.select(_db.stockTransferDiscrepancies)
          ..where((d) => d.transferId.equals(transferId))
          ..orderBy([(d) => OrderingTerm.asc(d.createdAt)]))
        .get();
    return rows
        .map(
          (d) => StockTransferDiscrepancy(
            id: d.id,
            transferId: d.transferId,
            transferItemId: d.transferItemId,
            quantity: d.quantity,
            reason: d.reason,
            resolution: d.resolution,
            notes: d.notes,
            resolvedBy: d.resolvedBy,
            resolvedAt: d.resolvedAt,
            createdAt: d.createdAt,
          ),
        )
        .toList();
  }

  Future<List<StockTransferReceipt>> _loadReceipts(int transferId) async {
    final rows = await (_db.select(_db.stockTransferReceipts)
          ..where((r) => r.transferId.equals(transferId))
          ..orderBy([(r) => OrderingTerm.desc(r.receivedAt)]))
        .get();

    final receipts = <StockTransferReceipt>[];
    for (final row in rows) {
      final itemRows = await (_db.select(_db.stockTransferReceiptItems)
            ..where((i) => i.receiptId.equals(row.id)))
          .get();
      receipts.add(
        StockTransferReceipt(
          id: row.id,
          transferId: row.transferId,
          shipmentId: row.shipmentId,
          reference: row.reference,
          notes: row.notes,
          receivedBy: row.receivedBy,
          receivedAt: row.receivedAt,
          items: itemRows
              .map(
                (item) => StockTransferReceiptItem(
                  id: item.id,
                  receiptId: item.receiptId,
                  transferItemId: item.transferItemId,
                  quantityReceived: item.quantityReceived,
                  quantityRefused: item.quantityRefused,
                  refusalReason: item.refusalReason,
                  refusalResolution: item.refusalResolution,
                ),
              )
              .toList(),
        ),
      );
    }
    return receipts;
  }

  Future<String> _nextReceiptReference({
    required int transferId,
    required String transferReference,
  }) async {
    final count = await (_db.selectOnly(_db.stockTransferReceipts)
          ..addColumns([_db.stockTransferReceipts.id.count()])
          ..where(_db.stockTransferReceipts.transferId.equals(transferId)))
        .getSingle()
        .then((row) => row.read(_db.stockTransferReceipts.id.count()) ?? 0);
    final safeRef = transferReference.replaceAll(RegExp(r'\s+'), '-');
    return 'RCP-$safeRef-${count + 1}';
  }

  Future<void> _reserveFifoForItem({
    required int shopId,
    required int transferItemId,
    required int productId,
    required int quantity,
    required String productLabel,
  }) async {
    final lots = await (_db.select(_db.inventoryLots)
          ..where(
            (l) =>
                l.shopId.equals(shopId) &
                l.productId.equals(productId) &
                l.quantityRemaining.isBiggerThanValue(0),
          )
          ..orderBy([
            (l) => OrderingTerm.asc(l.receivedAt),
            (l) => OrderingTerm.asc(l.id),
          ]))
        .get();

    var remaining = quantity;
    for (final lot in lots) {
      if (remaining <= 0) break;
      final available = lot.quantityRemaining - lot.quantityReserved;
      if (available <= 0) continue;
      final take = available < remaining ? available : remaining;

      await (_db.update(_db.inventoryLots)..where((l) => l.id.equals(lot.id)))
          .write(
        db.InventoryLotsCompanion(
          quantityReserved: Value(lot.quantityReserved + take),
          version: Value(lot.version + 1),
        ),
      );

      await _db.into(_db.stockTransferLotReservations).insert(
            db.StockTransferLotReservationsCompanion.insert(
              transferItemId: transferItemId,
              lotId: lot.id,
              quantity: take,
              unitCost: lot.unitCost,
            ),
          );

      remaining -= take;
    }

    if (remaining > 0) {
      throw ValidationFailure(
        'Stock insuffisant pour « $productLabel » '
        '(manque $remaining unité(s) disponible(s)).',
      );
    }
  }

  Future<int> _pendingReservationQuantity(int transferItemId) async {
    final reservationRows = await (_db.select(_db.stockTransferLotReservations)
          ..where((r) => r.transferItemId.equals(transferItemId)))
        .get();

    var pending = 0;
    for (final reservation in reservationRows) {
      pending += reservation.quantity - reservation.quantityShipped;
    }
    return pending;
  }

  /// Complète les réservations FIFO manquantes (ex. transfert validé côté cloud
  /// sans réservation locale).
  Future<void> _ensureReservationsForQuantity({
    required int shopId,
    required int transferItemId,
    required int productId,
    required int quantityNeeded,
    required String productLabel,
  }) async {
    if (quantityNeeded <= 0) return;

    final pending = await _pendingReservationQuantity(transferItemId);
    final missing = quantityNeeded - pending;
    if (missing <= 0) return;

    await _reserveFifoForItem(
      shopId: shopId,
      transferItemId: transferItemId,
      productId: productId,
      quantity: missing,
      productLabel: productLabel,
    );
  }

  Future<void> ensureTransferItemReservations({
    required int sourceShopId,
    required int transferId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) return;
    if (!StockTransferStatus.canShip(transfer.status)) return;

    final inventoryLocal = InventoryLocalDatasource(_db);
    final lotDs = InventoryLotLocalDatasource(_db);

    for (final item in transfer.items ?? []) {
      final pendingShip = item.quantityPendingShip;
      if (pendingShip <= 0) continue;

      final product =
          await inventoryLocal.findProduct(sourceShopId, item.sourceProductId);
      if (product == null) continue;

      await lotDs.ensureLotsForAllocation(
        shopId: sourceShopId,
        productId: item.sourceProductId,
      );

      await _ensureReservationsForQuantity(
        shopId: sourceShopId,
        transferItemId: item.id,
        productId: item.sourceProductId,
        quantityNeeded: pendingShip,
        productLabel: product.name,
      );
    }
  }

  Future<List<({int lotId, int quantity, int unitCost})>>
      _consumeReservationsForShip({
    required int transferItemId,
    required int quantity,
  }) async {
    final reservationRows = await (_db.select(_db.stockTransferLotReservations)
          ..where((r) => r.transferItemId.equals(transferItemId)))
        .get();

    final lotIds = reservationRows.map((r) => r.lotId).toSet().toList();
    final lotsById = <int, db.InventoryLot>{};
    if (lotIds.isNotEmpty) {
      final lots = await (_db.select(_db.inventoryLots)
            ..where((l) => l.id.isIn(lotIds)))
          .get();
      for (final lot in lots) {
        lotsById[lot.id] = lot;
      }
    }

    reservationRows.sort((a, b) {
      final lotA = lotsById[a.lotId];
      final lotB = lotsById[b.lotId];
      final cmp = (lotA?.receivedAt ?? 0).compareTo(lotB?.receivedAt ?? 0);
      if (cmp != 0) return cmp;
      return a.lotId.compareTo(b.lotId);
    });

    var remaining = quantity;
    final slices = <({int lotId, int quantity, int unitCost})>[];

    for (final reservation in reservationRows) {
      if (remaining <= 0) break;
      final pending = reservation.quantity - reservation.quantityShipped;
      if (pending <= 0) continue;

      final take = pending < remaining ? pending : remaining;
      final lot = lotsById[reservation.lotId];
      if (lot == null) {
        throw ValidationFailure('Lot #${reservation.lotId} introuvable.');
      }

      final newRemaining = lot.quantityRemaining - take;
      final newReserved = lot.quantityReserved - take;
      if (newReserved < 0) {
        throw ValidationFailure('Réservation incohérente sur le lot #${lot.id}.');
      }

      await (_db.update(_db.inventoryLots)..where((l) => l.id.equals(lot.id)))
          .write(
        db.InventoryLotsCompanion(
          quantityRemaining: Value(newRemaining),
          quantityReserved: Value(newReserved),
          status: Value(
            newRemaining <= 0
                ? InventoryLotStatus.depleted
                : InventoryLotStatus.active,
          ),
          version: Value(lot.version + 1),
        ),
      );

      lotsById[lot.id] = lot.copyWith(
        quantityRemaining: newRemaining,
        quantityReserved: newReserved,
      );

      await (_db.update(_db.stockTransferLotReservations)
            ..where((r) => r.id.equals(reservation.id)))
          .write(
        db.StockTransferLotReservationsCompanion(
          quantityShipped: Value(reservation.quantityShipped + take),
        ),
      );

      slices.add((lotId: lot.id, quantity: take, unitCost: reservation.unitCost));
      remaining -= take;
    }

    if (remaining > 0) {
      throw ValidationFailure(
        'Réservations insuffisantes pour expédier $quantity unité(s).',
      );
    }

    return slices;
  }

  Future<void> _releaseItemReservations(int transferItemId) async {
    final reservations = await (_db.select(_db.stockTransferLotReservations)
          ..where((r) => r.transferItemId.equals(transferItemId)))
        .get();

    for (final reservation in reservations) {
      final unshipped = reservation.quantity - reservation.quantityShipped;
      if (unshipped <= 0) continue;

      final lot = await (_db.select(_db.inventoryLots)
            ..where((l) => l.id.equals(reservation.lotId)))
          .getSingleOrNull();
      if (lot == null) continue;

      final newReserved = lot.quantityReserved - unshipped;
      await (_db.update(_db.inventoryLots)..where((l) => l.id.equals(lot.id)))
          .write(
        db.InventoryLotsCompanion(
          quantityReserved: Value(newReserved < 0 ? 0 : newReserved),
          version: Value(lot.version + 1),
        ),
      );
    }

    await (_db.delete(_db.stockTransferLotReservations)
          ..where((r) => r.transferItemId.equals(transferItemId)))
        .go();
  }

  Future<String> nextReturnReference(int shopId, String parentReference) {
    final suffix = parentReference.replaceFirst(RegExp(r'^(TRF|RET)-'), '');
    return Future.value('RET-$suffix');
  }

  Future<List<PendingIncomingTransfer>> listPendingIncomingForNotifications(
    int shopId,
  ) async {
    final rows = await (_db.select(_db.stockTransfers)
          ..where(
            (t) =>
                t.destinationShopId.equals(shopId) &
                t.status.isIn([
                  StockTransferStatus.partiallyShipped,
                  StockTransferStatus.shipped,
                  StockTransferStatus.partiallyReceived,
                ]),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.shippedAt)]))
        .get();

    final result = <PendingIncomingTransfer>[];
    for (final row in rows) {
      final transfer = await findTransfer(row.id);
      if (transfer == null) continue;
      final pendingUnits = (transfer.items ?? []).fold<int>(
        0,
        (sum, item) => sum + item.quantityPendingReceive,
      );
      if (pendingUnits <= 0) continue;
      result.add(
        PendingIncomingTransfer(
          transferId: transfer.id,
          reference: transfer.reference,
          sourceShopName: transfer.sourceShopName,
          pendingUnits: pendingUnits,
          status: transfer.status,
        ),
      );
    }
    return result;
  }

  Future<StockTransferQrReceiveIntent> resolveQrReceiveIntent({
    required String rawPayload,
    required int destinationShopId,
  }) async {
    final payload = StockTransferQrPayload.decode(rawPayload);
    if (payload.reference.isEmpty || payload.items.isEmpty) {
      throw const ValidationFailure('QR expédition incomplet.');
    }

    final candidates = await (_db.select(_db.stockTransfers)
          ..where(
            (t) =>
                t.reference.equals(payload.reference) &
                t.destinationShopId.equals(destinationShopId),
          ))
        .get();

    if (candidates.isEmpty) {
      throw ValidationFailure(
        'Transfert « ${payload.reference} » introuvable dans cette boutique.',
      );
    }

    db.StockTransfer? matchRow;
    for (final row in candidates) {
      if (payload.destinationShopServerId != null) {
        final destServer = await resolveShopServerId(row.destinationShopId);
        if (destServer?.toString() != payload.destinationShopServerId) {
          continue;
        }
      }
      matchRow = row;
      break;
    }
    matchRow ??= candidates.first;

    final transfer = await findTransfer(matchRow.id);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (!StockTransferStatus.canReceive(transfer.status)) {
      throw ValidationFailure(
        'Le transfert « ${transfer.reference} » n\'est pas réceptionnable.',
      );
    }

    StockTransferShipment? shipment;
    for (final s in transfer.shipments ?? []) {
      if (s.label == payload.shipmentLabel &&
          s.shippedAt == payload.shippedAt) {
        shipment = s;
        break;
      }
    }

    final quantities = <int, int>{};
    for (final qrItem in payload.items) {
      if (qrItem.quantity <= 0 || qrItem.productServerId.isEmpty) continue;

      StockTransferItem? localItem;
      for (final item in transfer.items ?? []) {
        if (item.productServerId == qrItem.productServerId) {
          localItem = item;
          break;
        }
      }
      if (localItem == null) {
        throw ValidationFailure(
          'Produit « ${qrItem.productName ?? qrItem.productServerId} » '
          'introuvable sur ce transfert.',
        );
      }

      final maxQty = shipment != null
          ? localItem.quantityInShipment(shipment.id)
          : localItem.quantityPendingReceive;
      final take = qrItem.quantity <= maxQty ? qrItem.quantity : maxQty;
      if (take <= 0) continue;
      if (take > localItem.quantityPendingReceive) {
        throw ValidationFailure(
          'Quantité QR trop élevée pour « ${localItem.productName} ».',
        );
      }
      quantities[localItem.id] = take;
    }

    if (quantities.isEmpty) {
      throw const ValidationFailure('Aucune quantité réceptionnable dans ce QR.');
    }

    return StockTransferQrReceiveIntent(
      transferId: transfer.id,
      shipmentId: shipment?.id,
      reference: transfer.reference,
      shipmentLabel: payload.shipmentLabel,
      quantitiesByItemId: quantities,
    );
  }

  Future<StockTransfer> createReturnTransfer({
    required int shopId,
    required int userId,
    required int parentTransferId,
    Map<int, int>? quantitiesByParentItemId,
  }) async {
    final parent = await findTransfer(parentTransferId);
    if (parent == null) {
      throw const NotFoundFailure('Transfert d\'origine introuvable.');
    }
    if (parent.destinationShopId != shopId) {
      throw const ValidationFailure(
        'Le retour doit être créé depuis la boutique qui a reçu le transfert.',
      );
    }
    if (!StockTransferStatus.canCreateReturn(parent.status, parent.transferType)) {
      throw ValidationFailure(
        'Impossible de créer un retour pour un transfert en statut '
        '« ${StockTransferStatus.label(parent.status)} ».',
      );
    }

    final inventoryLocal = InventoryLocalDatasource(_db);
    final timestamp = nowMs();
    final reference = await nextReturnReference(shopId, parent.reference);

    return _db.transaction(() async {
      final transferId = await _db.into(_db.stockTransfers).insert(
            db.StockTransfersCompanion.insert(
              reference: reference,
              sourceShopId: parent.destinationShopId,
              destinationShopId: parent.sourceShopId,
              sourceShopName: Value(
                _pickShopName(
                  parent.destinationShopName,
                  await _lookupShopNameById(parent.destinationShopId),
                ),
              ),
              destinationShopName: Value(
                _pickShopName(
                  parent.sourceShopName,
                  await _lookupShopNameById(parent.sourceShopId),
                ),
              ),
              transferType: const Value(StockTransferType.returnTransfer),
              parentTransferId: Value(parentTransferId),
              status: const Value(StockTransferStatus.draft),
              notes: Value('Retour de ${parent.reference}'),
              createdBy: userId,
              createdAt: timestamp,
              updatedAt: timestamp,
              syncStatus: const Value('pending'),
            ),
          );

      var anyItem = false;
      for (final parentItem in parent.items ?? []) {
        final defaultQty = parentItem.quantityReceived;
        final qty = quantitiesByParentItemId?[parentItem.id] ?? defaultQty;
        if (qty <= 0) continue;

        if (qty > parentItem.quantityReceived) {
          throw ValidationFailure(
            'Quantité retour trop élevée pour « ${parentItem.productName} ».',
          );
        }

        final sourceProductId = parentItem.destinationProductId;
        if (sourceProductId == null) {
          throw ValidationFailure(
            'Produit « ${parentItem.productName} » sans correspondance locale.',
          );
        }

        final product = await inventoryLocal.findProduct(shopId, sourceProductId);
        if (product == null) {
          throw ValidationFailure(
            'Produit « ${parentItem.productName} » introuvable.',
          );
        }

        await _db.into(_db.stockTransferItems).insert(
              db.StockTransferItemsCompanion.insert(
                transferId: transferId,
                sourceProductId: sourceProductId,
                productServerId: Value(parentItem.productServerId),
                quantityRequested: qty,
              ),
            );
        anyItem = true;
      }

      if (!anyItem) {
        throw const ValidationFailure(
          'Aucun article reçu disponible pour un retour.',
        );
      }

      final created = await findTransfer(transferId);
      if (created == null) {
        throw StateError('Retour introuvable après création.');
      }
      return created;
    });
  }

  static const _transferImportCategoryName = 'Transferts inter-boutiques';

  Future<int> resolveTransferImportCategoryId(int shopId) =>
      _resolveTransferImportCategoryId(shopId);

  Future<int> _resolveTransferImportCategoryId(int shopId) async {
    final inventoryLocal = InventoryLocalDatasource(_db);
    final existing =
        await inventoryLocal.findCategoryByName(shopId, _transferImportCategoryName);
    if (existing != null && existing.isActive) return existing.id;

    final categories =
        await inventoryLocal.listCategories(shopId: shopId, activeOnly: true);
    if (categories.isNotEmpty) return categories.first.id;

    return inventoryLocal.upsertCategoryFromRemote(
      shopId: shopId,
      name: _transferImportCategoryName,
      description: 'Produits créés à la réception d\'un transfert',
      isActive: true,
      sortOrder: 999,
    );
  }

  Future<List<TransferMissingDestinationProduct>> listMissingDestinationProducts({
    required int destinationShopId,
    required int transferId,
    Map<int, int>? quantitiesByItemId,
    int? shipmentId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) return [];

    final inventoryLocal = InventoryLocalDatasource(_db);
    final missing = <TransferMissingDestinationProduct>[];

    for (final item in transfer.items ?? []) {
      final maxForScope = shipmentId != null
          ? item.quantityPendingReceiveInShipment(shipmentId)
          : item.quantityPendingReceive;
      final toReceive =
          quantitiesByItemId?[item.id] ?? maxForScope;
      if (toReceive <= 0) continue;

      final destProductId = await _resolveDestinationProductId(
        inventoryLocal: inventoryLocal,
        destinationShopId: destinationShopId,
        sourceShopId: transfer.sourceShopId,
        item: item,
      );
      if (destProductId != null) continue;

      final sourceProduct = await inventoryLocal.findProduct(
        transfer.sourceShopId,
        item.sourceProductId,
      );
      final unitCost = item.lotLines?.isNotEmpty == true
          ? item.lotLines!.first.unitCost
          : null;

      missing.add(
        TransferMissingDestinationProduct(
          itemId: item.id,
          productName: item.productName ?? 'Produit #${item.sourceProductId}',
          productServerId: item.productServerId,
          suggestedPriceBuy: unitCost ?? sourceProduct?.priceBuy,
          suggestedPriceSell: sourceProduct?.priceSell,
        ),
      );
    }

    return missing;
  }

  int defaultSalePriceForMissingProduct(TransferMissingDestinationProduct product) {
    final sell = product.suggestedPriceSell;
    if (sell != null && sell > 0) return sell;

    final buy = product.suggestedPriceBuy;
    if (buy != null && buy > 0) return buy;

    return 1;
  }

  Future<({Map<int, int> productIds, Set<int> newlyCreatedItemIds})>
      createDestinationProductsForReceive({
    required int destinationShopId,
    required int sourceShopId,
    required Map<int, int> salePriceByItemId,
    required List<TransferMissingDestinationProduct> products,
  }) async {
    if (products.isEmpty) {
      return (
        productIds: const <int, int>{},
        newlyCreatedItemIds: const <int>{},
      );
    }

    final inventoryLocal = InventoryLocalDatasource(_db);
    final categoryId = await _resolveTransferImportCategoryId(destinationShopId);
    final defaultThreshold =
        await inventoryLocal.getDefaultAlertThreshold(destinationShopId);
    final created = <int, int>{};
    final newlyCreated = <int>{};

    await _db.transaction(() async {
      for (final product in products) {
        final priceSell = salePriceByItemId[product.itemId] ??
            defaultSalePriceForMissingProduct(product);
        if (priceSell <= 0) {
          throw ValidationFailure(
            'Prix de vente invalide pour « ${product.productName} ».',
          );
        }

        final transferItem = await (_db.select(_db.stockTransferItems)
              ..where((i) => i.id.equals(product.itemId)))
            .getSingleOrNull();
        if (transferItem != null) {
          final existingId = await _resolveDestinationProductId(
            inventoryLocal: inventoryLocal,
            destinationShopId: destinationShopId,
            sourceShopId: sourceShopId,
            item: StockTransferItem(
              id: transferItem.id,
              transferId: transferItem.transferId,
              sourceProductId: transferItem.sourceProductId,
              destinationProductId: transferItem.destinationProductId,
              productName: product.productName,
              productServerId: product.productServerId,
              quantityRequested: transferItem.quantityRequested,
              quantityShipped: transferItem.quantityShipped,
              quantityReceived: transferItem.quantityReceived,
            ),
          );
          if (existingId != null) {
            created[product.itemId] = existingId;
            await (_db.update(_db.stockTransferItems)
                  ..where((i) => i.id.equals(product.itemId)))
                .write(
              db.StockTransferItemsCompanion(
                destinationProductId: Value(existingId),
              ),
            );
            continue;
          }
        }

        final productId = await inventoryLocal.insertProduct(
          shopId: destinationShopId,
          categoryId: categoryId,
          name: product.productName,
          quantityInStock: 0,
          alertThreshold: defaultThreshold,
          priceBuy: product.suggestedPriceBuy,
          priceSell: priceSell,
        );
        created[product.itemId] = productId;
        newlyCreated.add(product.itemId);

        if (product.productServerId != null &&
            product.productServerId!.trim().isNotEmpty) {
          await inventoryLocal.updateProductRow(
            productId,
            db.ProductsCompanion(
              serverId: Value(product.productServerId!.trim()),
            ),
          );
        }

        await (_db.update(_db.stockTransferItems)
              ..where((i) => i.id.equals(product.itemId)))
            .write(
          db.StockTransferItemsCompanion(
            destinationProductId: Value(productId),
          ),
        );
      }
    });

    return (productIds: created, newlyCreatedItemIds: newlyCreated);
  }

  /// Crée ou lie les produits destination dès l'expédition (pull boutique B).
  Future<void> ensureDestinationProductsAtShip({
    required int destinationShopId,
    required int sourceShopId,
    required int transferId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) return;

    final inventoryLocal = InventoryLocalDatasource(_db);
    final categoryId = await _resolveTransferImportCategoryId(destinationShopId);
    final defaultThreshold =
        await inventoryLocal.getDefaultAlertThreshold(destinationShopId);

    for (final item in transfer.items ?? []) {
      if (item.quantityShipped <= 0) continue;

      final existingId = await _resolveDestinationProductId(
        inventoryLocal: inventoryLocal,
        destinationShopId: destinationShopId,
        sourceShopId: sourceShopId,
        item: item,
      );
      if (existingId != null) {
        if (item.destinationProductId != existingId) {
          await (_db.update(_db.stockTransferItems)
                ..where((i) => i.id.equals(item.id)))
              .write(
            db.StockTransferItemsCompanion(
              destinationProductId: Value(existingId),
            ),
          );
        }
        continue;
      }

      final sourceProduct = await inventoryLocal.findProduct(
        sourceShopId,
        item.sourceProductId,
      );
      final priceSell = sourceProduct?.priceSell ??
          (item.lotLines?.isNotEmpty == true
              ? item.lotLines!.first.unitCost
              : 1);

      final productId = await inventoryLocal.insertProduct(
        shopId: destinationShopId,
        categoryId: categoryId,
        name: item.productName ?? sourceProduct?.name ?? 'Produit transféré',
        quantityInStock: 0,
        alertThreshold: defaultThreshold,
        priceBuy: sourceProduct?.priceBuy,
        priceSell: priceSell > 0 ? priceSell : 1,
      );

      if (item.productServerId != null &&
          item.productServerId!.trim().isNotEmpty) {
        await inventoryLocal.updateProductRow(
          productId,
          db.ProductsCompanion(
            serverId: Value(item.productServerId!.trim()),
          ),
        );
      }

      await (_db.update(_db.stockTransferItems)
            ..where((i) => i.id.equals(item.id)))
          .write(
        db.StockTransferItemsCompanion(
          destinationProductId: Value(productId),
        ),
      );
    }
  }

  Future<StockTransfer> submitTransferForApproval({
    required int sourceShopId,
    required int userId,
    required int transferId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (transfer.sourceShopId != sourceShopId) {
      throw const ValidationFailure('Transfert non accessible.');
    }
    if (!StockTransferStatus.canSubmitForApproval(transfer.status)) {
      throw const ValidationFailure(
        'Seul un brouillon peut être soumis pour approbation.',
      );
    }

    final timestamp = nowMs();
    await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(transferId)))
        .write(
      db.StockTransfersCompanion(
        status: const Value(StockTransferStatus.pendingApproval),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );

    await _insertTransferEvent(
      transferId: transferId,
      shopId: sourceShopId,
      eventType: StockTransferEventType.submittedForApproval,
      actorUserId: userId,
      createdAt: timestamp,
    );

    final updated = await findTransfer(transferId);
    if (updated == null) {
      throw StateError('Transfert introuvable après soumission.');
    }
    return updated;
  }

  Future<StockTransfer> approveTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }
    if (transfer.sourceShopId != sourceShopId) {
      throw const ValidationFailure('Transfert non accessible.');
    }
    if (!StockTransferStatus.canApprove(transfer.status)) {
      throw const ValidationFailure(
        'Seul un transfert en attente d\'approbation peut être approuvé.',
      );
    }

    return validateTransfer(
      sourceShopId: sourceShopId,
      userId: userId,
      transferId: transferId,
    );
  }

  Future<int?> _resolveDestinationProductId({
    required InventoryLocalDatasource inventoryLocal,
    required int destinationShopId,
    required StockTransferItem item,
    int? sourceShopId,
  }) async {
    final shopIds = await localShopIdsInSameCloudShop(destinationShopId);
    for (final shopId in shopIds) {
      final found = await _resolveDestinationProductIdInShop(
        inventoryLocal: inventoryLocal,
        destinationShopId: shopId,
        sourceShopId: sourceShopId,
        item: item,
      );
      if (found != null) return found;
    }
    return null;
  }

  Future<int?> _resolveDestinationProductIdInShop({
    required InventoryLocalDatasource inventoryLocal,
    required int destinationShopId,
    required StockTransferItem item,
    int? sourceShopId,
  }) async {
    if (item.destinationProductId != null) {
      final existing = await inventoryLocal.findProduct(
        destinationShopId,
        item.destinationProductId!,
      );
      if (existing != null) return existing.id;
    }

    final serverId = item.productServerId?.trim();
    if (serverId != null && serverId.isNotEmpty) {
      final localId = await inventoryLocal.findLocalProductIdByServerId(
        destinationShopId,
        serverId,
      );
      if (localId != null) return localId;
    }

    final name = item.productName?.trim();
    if (name != null && name.isNotEmpty) {
      final byName =
          await inventoryLocal.findLocalProductIdByName(destinationShopId, name);
      if (byName != null) return byName;
    }

    if (sourceShopId != null) {
      final sourceProduct = await inventoryLocal.findProduct(
        sourceShopId,
        item.sourceProductId,
      );
      if (sourceProduct != null) {
        final sourceServerId = sourceProduct.serverId?.trim();
        if (sourceServerId != null &&
            sourceServerId.isNotEmpty &&
            sourceServerId != serverId) {
          final bySourceServerId = await inventoryLocal.findLocalProductIdByServerId(
            destinationShopId,
            sourceServerId,
          );
          if (bySourceServerId != null) return bySourceServerId;
        }

        if (name == null || name.isEmpty) {
          final bySourceName = await inventoryLocal.findLocalProductIdByName(
            destinationShopId,
            sourceProduct.name,
          );
          if (bySourceName != null) return bySourceName;
        }
      }
    }

    return null;
  }

  Future<List<StockTransfer>> _mapTransfers(
    List<db.StockTransfer> rows, {
    bool includeItems = false,
  }) async {
    final result = <StockTransfer>[];
    for (final row in rows) {
      final sourceShop = await (_db.select(_db.shops)
            ..where((s) => s.id.equals(row.sourceShopId)))
          .getSingleOrNull();
      final destShop = await (_db.select(_db.shops)
            ..where((s) => s.id.equals(row.destinationShopId)))
          .getSingleOrNull();

      List<StockTransferItem>? items;
      List<StockTransferShipment>? shipments;
      List<StockTransferReceipt>? receipts;
      List<StockTransferEvent>? events;
      List<StockTransferDiscrepancy>? discrepancies;
      if (includeItems) {
        items = await _loadItems(row.id);
        shipments = await _loadShipments(row.id);
        receipts = await _loadReceipts(row.id);
        events = await _loadEvents(row.id);
        discrepancies = await _loadDiscrepancies(row.id);
      }

      String? parentReference;
      if (row.parentTransferId != null) {
        final parent = await (_db.select(_db.stockTransfers)
              ..where((t) => t.id.equals(row.parentTransferId!)))
            .getSingleOrNull();
        parentReference = parent?.reference;
      }

      result.add(
        StockTransfer(
          id: row.id,
          reference: row.reference,
          sourceShopId: row.sourceShopId,
          destinationShopId: row.destinationShopId,
          sourceShopName: _pickShopName(sourceShop?.name, row.sourceShopName),
          destinationShopName:
              _pickShopName(destShop?.name, row.destinationShopName),
          status: row.status,
          transferType: row.transferType,
          parentTransferId: row.parentTransferId,
          parentReference: parentReference,
          notes: row.notes,
          createdBy: row.createdBy,
          validatedBy: row.validatedBy,
          shippedBy: row.shippedBy,
          receivedBy: row.receivedBy,
          closedBy: row.closedBy,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          validatedAt: row.validatedAt,
          shippedAt: row.shippedAt,
          receivedAt: row.receivedAt,
          closedAt: row.closedAt,
          items: items,
          shipments: shipments,
          receipts: receipts,
          events: events,
          discrepancies: discrepancies,
          serverId: row.serverId,
          syncStatus: row.syncStatus,
        ),
      );
    }
    return result;
  }

  Future<List<StockTransferShipment>> _loadShipments(int transferId) async {
    final rows = await (_db.select(_db.stockTransferShipments)
          ..where((s) => s.transferId.equals(transferId))
          ..orderBy([(s) => OrderingTerm.asc(s.shippedAt)]))
        .get();
    return rows
        .map(
          (s) => StockTransferShipment(
            id: s.id,
            transferId: s.transferId,
            reference: s.reference,
            label: s.label,
            notes: s.notes,
            driverName: s.driverName,
            vehiclePlate: s.vehiclePlate,
            shippedBy: s.shippedBy,
            shippedAt: s.shippedAt,
          ),
        )
        .toList();
  }

  Future<List<StockTransferItem>> _loadItems(int transferId) async {
    final itemRows = await (_db.select(_db.stockTransferItems)
          ..where((i) => i.transferId.equals(transferId)))
        .get();

    final items = <StockTransferItem>[];
    for (final row in itemRows) {
      final product = await (_db.select(_db.products)
            ..where((p) => p.id.equals(row.sourceProductId)))
          .getSingleOrNull();

      final lotRows = await (_db.select(_db.stockTransferLotLines)
            ..where((l) => l.transferItemId.equals(row.id)))
          .get();

      items.add(
        StockTransferItem(
          id: row.id,
          transferId: row.transferId,
          sourceProductId: row.sourceProductId,
          destinationProductId: row.destinationProductId,
          productServerId: row.productServerId,
          productName: product?.name,
          quantityRequested: row.quantityRequested,
          quantityShipped: row.quantityShipped,
          quantityReceived: row.quantityReceived,
          lotLines: lotRows
              .map(
                (l) => StockTransferLotLine(
                  id: l.id,
                  transferItemId: l.transferItemId,
                  shipmentId: l.shipmentId,
                  sourceLotId: l.sourceLotId,
                  destinationLotId: l.destinationLotId,
                  quantity: l.quantity,
                  quantityReceived: l.quantityReceived,
                  unitCost: l.unitCost,
                ),
              )
              .toList(),
        ),
      );
    }
    return items;
  }

  Future<String> _nextShipmentReference(
    int transferId,
    String transferReference,
  ) async {
    final existing = await (_db.select(_db.stockTransferShipments)
          ..where((s) => s.transferId.equals(transferId)))
        .get();
    final seq = existing.length + 1;
    final safeRef = transferReference.replaceAll(RegExp(r'\s+'), '-');
    return 'SHP-$safeRef-$seq';
  }

  String _shipmentReference(StockTransfer transfer, int shipmentId) {
    for (final shipment in transfer.shipments ?? []) {
      if (shipment.id == shipmentId) {
        return shipment.reference;
      }
    }
    return 'expédition';
  }

  int? resolveRemoteShipmentId({
    required StockTransfer transfer,
    required int localShipmentId,
    required List<Map<String, dynamic>> remoteShipments,
  }) {
    StockTransferShipment? localShipment;
    for (final shipment in transfer.shipments ?? []) {
      if (shipment.id == localShipmentId) {
        localShipment = shipment;
        break;
      }
    }
    if (localShipment == null) return null;

    for (final remote in remoteShipments) {
      final remoteReference = remote['reference']?.toString().trim();
      if (remoteReference != null &&
          remoteReference.isNotEmpty &&
          remoteReference == localShipment.reference) {
        return coerceRemoteInt(remote['id']);
      }
    }

    for (final remote in remoteShipments) {
      final remoteLabel = remote['label']?.toString().trim();
      final remoteShippedAt = coerceRemoteInt(remote['shippedAt']);
      if (remoteLabel == localShipment.label &&
          remoteShippedAt == localShipment.shippedAt) {
        return coerceRemoteInt(remote['id']);
      }
    }

    return null;
  }

  int? resolveLocalShipmentIdFromRemote({
    required StockTransfer transfer,
    required int remoteShipmentId,
    required List<Map<String, dynamic>> remoteShipments,
  }) {
    Map<String, dynamic>? remoteShipment;
    for (final remote in remoteShipments) {
      if (coerceRemoteInt(remote['id']) == remoteShipmentId) {
        remoteShipment = remote;
        break;
      }
    }
    if (remoteShipment == null) return null;

    final remoteReference = remoteShipment['reference']?.toString().trim();
    if (remoteReference != null && remoteReference.isNotEmpty) {
      for (final local in transfer.shipments ?? []) {
        if (local.reference == remoteReference) return local.id;
      }
    }

    final remoteLabel = remoteShipment['label']?.toString().trim();
    final remoteShippedAt = coerceRemoteInt(remoteShipment['shippedAt']);
    for (final local in transfer.shipments ?? []) {
      if (local.label == remoteLabel && local.shippedAt == remoteShippedAt) {
        return local.id;
      }
    }
    return null;
  }

  Future<int?> resolveShopServerId(int shopId) async {
    for (final localId in await localShopIdsInSameCloudShop(shopId)) {
      final row = await (_db.select(_db.shops)..where((s) => s.id.equals(localId)))
          .getSingleOrNull();
      final parsed = int.tryParse(row?.serverId ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Tous les ids locaux désignant la même boutique cloud (doublons SQLite).
  Future<Set<int>> localShopIdsInSameCloudShop(int shopId) async {
    final row = await (_db.select(_db.shops)..where((s) => s.id.equals(shopId)))
        .getSingleOrNull();
    if (row == null) return {shopId};

    final serverId = row.serverId?.trim();
    if (serverId != null && serverId.isNotEmpty) {
      final rows = await (_db.select(_db.shops)
            ..where((s) => s.serverId.equals(serverId)))
          .get();
      if (rows.isNotEmpty) {
        return rows.map((r) => r.id).toSet();
      }
    }

    final linked = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('$shopId')))
        .get();
    if (linked.isNotEmpty) {
      return {shopId, ...linked.map((r) => r.id)};
    }

    return {shopId};
  }

  Future<bool> isSameCloudShop(int leftShopId, int rightShopId) async {
    if (leftShopId == rightShopId) return true;
    final leftServer = await resolveShopServerId(leftShopId);
    final rightServer = await resolveShopServerId(rightShopId);
    if (leftServer != null && rightServer != null) {
      return leftServer == rightServer;
    }
    final leftIds = await localShopIdsInSameCloudShop(leftShopId);
    final rightIds = await localShopIdsInSameCloudShop(rightShopId);
    return leftIds.intersection(rightIds).isNotEmpty;
  }

  Future<int> canonicalLocalShopId(int shopId) async {
    final ids = await localShopIdsInSameCloudShop(shopId);
    return ids.reduce((a, b) => a < b ? a : b);
  }

  Future<int?> resolveProductServerId(int shopId, int productId) async {
    final inventoryLocal = InventoryLocalDatasource(_db);
    final product = await inventoryLocal.findProduct(shopId, productId);
    if (product == null) return null;
    final raw = product.serverId?.trim();
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  static int? coerceRemoteInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// Met à jour les métadonnées produit des lignes locales depuis le snapshot cloud.
  Future<void> linkRemoteTransferItemsFromSnapshot(
    int localTransferId,
    List<Map<String, dynamic>> remoteItems,
  ) async {
    if (remoteItems.isEmpty) return;

    final transfer = await findTransfer(localTransferId);
    if (transfer == null) return;

    final usedRemoteIds = <int>{};
    for (final localItem in transfer.items ?? []) {
      final remoteItem = await _matchRemoteTransferItem(
        localItem: localItem,
        sourceShopId: transfer.sourceShopId,
        remoteItems: remoteItems,
        excludeRemoteIds: usedRemoteIds,
      );
      if (remoteItem == null) continue;

      final remoteItemId = coerceRemoteInt(remoteItem['id']);
      if (remoteItemId != null) usedRemoteIds.add(remoteItemId);

      final remoteCatalogId = remoteItem['productServerId']?.toString().trim();
      if (remoteCatalogId != null && remoteCatalogId.isNotEmpty) {
        await (_db.update(_db.stockTransferItems)
              ..where((i) => i.id.equals(localItem.id)))
            .write(
          db.StockTransferItemsCompanion(
            productServerId: Value(remoteCatalogId),
          ),
        );
      }
    }
  }

  Future<String> describeUnmappedTransferItems({
    required StockTransfer transfer,
    required List<Map<String, dynamic>> remoteItems,
  }) async {
    final usedRemoteIds = <int>{};
    final missing = <String>[];

    for (final localItem in transfer.items ?? []) {
      final remoteItem = await _matchRemoteTransferItem(
        localItem: localItem,
        sourceShopId: transfer.sourceShopId,
        remoteItems: remoteItems,
        excludeRemoteIds: usedRemoteIds,
      );
      if (remoteItem != null) {
        final remoteItemId = coerceRemoteInt(remoteItem['id']);
        if (remoteItemId != null) usedRemoteIds.add(remoteItemId);
        continue;
      }
      missing.add(localItem.productName ?? 'Produit #${localItem.sourceProductId}');
    }

    if (missing.isEmpty) {
      return 'Articles du transfert non correspondants côté serveur.';
    }
    return 'Produit(s) non reconnus côté serveur : ${missing.join(', ')}. '
        'Synchronisez le catalogue depuis la boutique source puis réessayez.';
  }

  /// Associe les lignes locales aux lignes serveur pour create/ship/receive sync.
  Future<List<Map<String, dynamic>>> buildRemoteItemMapping({
    required StockTransfer transfer,
    required List<Map<String, dynamic>> remoteItems,
  }) async {
    final mapping = <Map<String, dynamic>>[];
    final usedRemoteIds = <int>{};

    for (final localItem in transfer.items ?? []) {
      final remoteItem = await _matchRemoteTransferItem(
        localItem: localItem,
        sourceShopId: transfer.sourceShopId,
        remoteItems: remoteItems,
        excludeRemoteIds: usedRemoteIds,
      );
      if (remoteItem == null) continue;

      final remoteItemId = coerceRemoteInt(remoteItem['id']);
      if (remoteItemId == null) continue;

      usedRemoteIds.add(remoteItemId);
      mapping.add({
        'localItemId': localItem.id,
        'remoteItemId': remoteItemId,
      });
    }

    return mapping;
  }

  Future<Map<String, dynamic>?> _matchRemoteTransferItem({
    required StockTransferItem localItem,
    required int sourceShopId,
    required List<Map<String, dynamic>> remoteItems,
    Set<int>? excludeRemoteIds,
  }) async {
    final excluded = excludeRemoteIds ?? const {};

    Map<String, dynamic>? pick(bool Function(Map<String, dynamic> ri) test) {
      for (final ri in remoteItems) {
        final id = coerceRemoteInt(ri['id']);
        if (id == null || excluded.contains(id)) continue;
        if (test(ri)) return ri;
      }
      return null;
    }

    final cloudProductId =
        await resolveProductServerId(sourceShopId, localItem.sourceProductId);
    if (cloudProductId != null) {
      final byProductId = pick(
        (ri) => coerceRemoteInt(ri['sourceProductId']) == cloudProductId,
      );
      if (byProductId != null) return byProductId;
    }

    final localProductServerId = localItem.productServerId?.trim();
    if (localProductServerId != null && localProductServerId.isNotEmpty) {
      final byStoredUuid = pick(
        (ri) => ri['productServerId']?.toString().trim() == localProductServerId,
      );
      if (byStoredUuid != null) return byStoredUuid;

      final bySourceAsUuid = pick(
        (ri) => ri['sourceProductId']?.toString().trim() == localProductServerId,
      );
      if (bySourceAsUuid != null) return bySourceAsUuid;
    }

    final inventoryLocal = InventoryLocalDatasource(_db);
    final product =
        await inventoryLocal.findProduct(sourceShopId, localItem.sourceProductId);
    final productServerId = product?.serverId?.trim();
    if (productServerId != null && productServerId.isNotEmpty) {
      final byCatalogServerId = pick(
        (ri) => ri['sourceProductId']?.toString().trim() == productServerId,
      );
      if (byCatalogServerId != null) return byCatalogServerId;

      final byCatalogUuid = pick(
        (ri) => ri['productServerId']?.toString().trim() == productServerId,
      );
      if (byCatalogUuid != null) return byCatalogUuid;

      final catalogNumeric = int.tryParse(productServerId);
      if (catalogNumeric != null) {
        final byNumericCatalog = pick(
          (ri) => coerceRemoteInt(ri['sourceProductId']) == catalogNumeric,
        );
        if (byNumericCatalog != null) return byNumericCatalog;
      }
    }

    // Dernier recours : quantité demandée identique (transfert mono-article fréquent).
    final available = remoteItems.where((ri) {
      final id = coerceRemoteInt(ri['id']);
      return id != null && !excluded.contains(id);
    }).toList();
    if (available.length == 1) {
      final only = available.first;
      final remoteQty = coerceRemoteInt(only['quantityRequested']);
      if (remoteQty == localItem.quantityRequested) return only;
    }

    return null;
  }

  Map<int, int> resolveShipQuantitiesForSync({
    required StockTransfer transfer,
    required Map<String, dynamic> payload,
  }) {
    final fromPayload = _readQuantitiesMap(payload['quantitiesByItemId']);
    if (fromPayload.isNotEmpty) return fromPayload;

    for (final item in transfer.items ?? []) {
      if (item.quantityPendingShip > 0) {
        fromPayload[item.id] = item.quantityPendingShip;
      }
    }
    if (fromPayload.isNotEmpty) return fromPayload;

    final label = payload['label'] as String?;
    StockTransferShipment? shipment;
    if (label != null && label.isNotEmpty) {
      for (final s in transfer.shipments ?? []) {
        if (s.label == label) shipment = s;
      }
    }
    shipment ??=
        (transfer.shipments?.isNotEmpty ?? false) ? transfer.shipments!.last : null;

    if (shipment != null) {
      for (final item in transfer.items ?? []) {
        final qty = item.quantityInShipment(shipment.id);
        if (qty > 0) fromPayload[item.id] = qty;
      }
    }

    if (fromPayload.isEmpty &&
        (transfer.shipments?.length ?? 0) == 1 &&
        transfer.shipments!.first.label == label) {
      for (final item in transfer.items ?? []) {
        if (item.quantityShipped > 0) {
          fromPayload[item.id] = item.quantityShipped;
        }
      }
    }

    return fromPayload;
  }

  Map<int, int> resolveReceiveQuantitiesForSync({
    required StockTransfer transfer,
    required Map<String, dynamic> payload,
  }) {
    final fromPayload = _readQuantitiesMap(payload['quantitiesByItemId']);
    if (fromPayload.isNotEmpty) return fromPayload;

    for (final item in transfer.items ?? []) {
      if (item.quantityPendingReceive > 0) {
        fromPayload[item.id] = item.quantityPendingReceive;
      }
    }
    return fromPayload;
  }

  Map<int, int> _readQuantitiesMap(Object? raw) {
    final quantities = <int, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final id = int.tryParse(key.toString());
        final qty = (value as num?)?.toInt();
        if (id != null && qty != null && qty > 0) {
          quantities[id] = qty;
        }
      });
    }
    return quantities;
  }

  Future<String?> findTransferServerId(int transferId) async {
    final row = await (_db.select(_db.stockTransfers)
          ..where((t) => t.id.equals(transferId)))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<int?> findTransferLocalIdByServerId(String serverId) async {
    final rows = await (_db.select(_db.stockTransfers)
          ..where((t) => t.serverId.equals(serverId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(1))
        .get();
    return rows.firstOrNull?.id;
  }

  Future<int?> findTransferLocalIdByReference({
    required int shopId,
    required String reference,
  }) async {
    final rows = await (_db.select(_db.stockTransfers)
          ..where(
            (t) =>
                t.reference.equals(reference) &
                (t.sourceShopId.equals(shopId) |
                    t.destinationShopId.equals(shopId)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(1))
        .get();
    return rows.firstOrNull?.id;
  }

  Future<int> resolveLocalShopId(int serverShopId) async {
    final strict = await _findLocalShopIdForServerShopId(serverShopId);
    if (strict != null) return strict;

    final shopCount = await _db.select(_db.shops).get();
    if (shopCount.length == 1) {
      final only = shopCount.first;
      final mapped = int.tryParse(only.serverId?.trim() ?? '');
      if (mapped == null || mapped == serverShopId) {
        if (mapped == null) {
          await (_db.update(_db.shops)..where((s) => s.id.equals(only.id))).write(
            db.ShopsCompanion(
              serverId: Value('$serverShopId'),
              syncedAt: Value(nowMs()),
            ),
          );
        }
        return only.id;
      }
    }

    final timestamp = nowMs();
    return _db.into(_db.shops).insert(
          db.ShopsCompanion.insert(
            name: const Value('Boutique'),
            createdAt: timestamp,
            serverId: Value('$serverShopId'),
            syncedAt: Value(timestamp),
          ),
        );
  }

  Future<int?> _findLocalShopIdForServerShopId(int serverShopId) async {
    final rows = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('$serverShopId')))
        .get();
    if (rows.isEmpty) return null;
    rows.sort((a, b) => a.id.compareTo(b.id));
    return rows.first.id;
  }

  Future<({int sourceShopId, int destinationShopId})> _resolveTransferEndpointsFromRemote(
    Map<String, dynamic> remote,
  ) async {
    final remoteSourceShopId = coerceRemoteInt(remote['sourceShopId']);
    final remoteDestinationShopId = coerceRemoteInt(remote['destinationShopId']);
    if (remoteSourceShopId == null || remoteDestinationShopId == null) {
      throw const ValidationFailure('Transfert cloud incomplet (boutiques manquantes).');
    }
    if (remoteSourceShopId == remoteDestinationShopId) {
      throw const ValidationFailure('Transfert cloud invalide (même boutique source et destination).');
    }

    final localSourceShopId = await resolveLocalShopId(remoteSourceShopId);
    final localDestinationShopId =
        await resolveLocalShopId(remoteDestinationShopId);

    return (
      sourceShopId: localSourceShopId,
      destinationShopId: localDestinationShopId,
    );
  }

  /// Supprime les opérations cloud devenues inutiles une fois le transfert connu du serveur.
  Future<void> clearObsoleteTransferQueueOps(int transferId) async {
    final serverId = await findTransferServerId(transferId);
    if (serverId == null) return;

    await (_db.delete(_db.syncQueue)
          ..where(
            (q) =>
                q.entityTable.equals(SyncEntityTable.stockTransfers) &
                q.recordId.equals(transferId) &
                q.operation.isIn([
                  SyncOperation.create,
                  SyncOperation.validate,
                  SyncOperation.submit,
                  SyncOperation.approve,
                ]) &
                q.status.equals('pending'),
          ))
        .go();
  }

  /// Supprime toute la file sync en attente pour un transfert jamais poussé (annulation locale).
  Future<void> purgePendingTransferSyncOps(int transferId) async {
    await (_db.delete(_db.syncQueue)
          ..where(
            (q) =>
                q.entityTable.equals(SyncEntityTable.stockTransfers) &
                q.recordId.equals(transferId) &
                q.status.equals('pending'),
          ))
        .go();
  }

  Future<int> resolveFallbackUserId(int shopId) async {
    final rows = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(shopId))
          ..orderBy([(u) => OrderingTerm.asc(u.id)])
          ..limit(1))
        .get();
    return rows.firstOrNull?.id ?? 1;
  }

  Future<int> resolveImportUserId({
    required int shopId,
    required int fallbackUserId,
    int? remoteUserId,
  }) async {
    if (remoteUserId != null) {
      final rows = await (_db.select(_db.users)
            ..where(
              (u) =>
                  u.shopId.equals(shopId) &
                  u.serverId.equals('$remoteUserId'),
            )
            ..limit(1))
          .get();
      if (rows.isNotEmpty) return rows.first.id;
    }
    return fallbackUserId;
  }

  /// Importe ou met à jour un transfert depuis le détail serveur.
  Future<int?> upsertTransferFromRemoteDetail({
    required int currentShopId,
    required Map<String, dynamic> detail,
    required int importUserId,
  }) async {
    final serverId = detail['id']?.toString();
    if (serverId == null || serverId.isEmpty) return null;

    final remoteSourceShopId = coerceRemoteInt(detail['sourceShopId']);
    final remoteDestinationShopId = coerceRemoteInt(detail['destinationShopId']);
    if (remoteSourceShopId == null || remoteDestinationShopId == null) {
      return null;
    }

    final localSourceShopId = await resolveLocalShopId(remoteSourceShopId);
    final localDestinationShopId =
        await resolveLocalShopId(remoteDestinationShopId);

    final currentServerId = await resolveShopServerId(currentShopId);
    final involvesCurrentShop = currentServerId != null
        ? remoteSourceShopId == currentServerId ||
            remoteDestinationShopId == currentServerId
        : localSourceShopId == currentShopId ||
            localDestinationShopId == currentShopId;
    if (!involvesCurrentShop) {
      return null;
    }

    var localTransferId = await findTransferLocalIdByServerId(serverId);
    final reference = detail['reference'] as String?;
    if (localTransferId == null && reference != null && reference.isNotEmpty) {
      localTransferId = await findTransferLocalIdByReference(
        shopId: currentShopId,
        reference: reference,
      );
    }

    if (localTransferId == null) {
      localTransferId = await _insertTransferFromRemoteDetail(
        detail: detail,
        serverId: serverId,
        localSourceShopId: localSourceShopId,
        localDestinationShopId: localDestinationShopId,
        importUserId: importUserId,
      );
    }

    if (localTransferId == null) return null;

    await applyRemoteStockTransferSnapshot(localTransferId, detail);
    return localTransferId;
  }

  Future<int?> _insertTransferFromRemoteDetail({
    required Map<String, dynamic> detail,
    required String serverId,
    required int localSourceShopId,
    required int localDestinationShopId,
    required int importUserId,
  }) async {
    final reference = detail['reference'] as String?;
    if (reference == null || reference.isEmpty) return null;

    final remoteItems = (detail['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final inventoryLocal = InventoryLocalDatasource(_db);
    final resolvedItems = <Map<String, dynamic>>[];

    for (final remoteItem in remoteItems) {
      final localProductId = await _resolveLocalSourceProductId(
        inventoryLocal: inventoryLocal,
        localSourceShopId: localSourceShopId,
        remoteItem: remoteItem,
      );
      if (localProductId == null) continue;

      resolvedItems.add({
        'localProductId': localProductId,
        'remoteItem': remoteItem,
      });
    }

    final createdBy = await resolveImportUserId(
      shopId: localSourceShopId,
      fallbackUserId: importUserId,
      remoteUserId: coerceRemoteInt(detail['createdBy']),
    );

    int? parentTransferId;
    final parentServerId = coerceRemoteInt(detail['parentTransferId']);
    if (parentServerId != null) {
      parentTransferId =
          await findTransferLocalIdByServerId('$parentServerId');
    }

    final timestamp = coerceRemoteInt(detail['createdAt']) ?? nowMs();
    final status = detail['status'] as String? ?? StockTransferStatus.draft;
    final sourceShopName = _pickShopName(
      await _lookupShopNameById(localSourceShopId),
      detail['sourceShopName'] as String?,
    );
    final destinationShopName = _pickShopName(
      await _lookupShopNameById(localDestinationShopId),
      detail['destinationShopName'] as String?,
    );

    return _db.transaction(() async {
      final transferId = await _db.into(_db.stockTransfers).insert(
            db.StockTransfersCompanion.insert(
              reference: reference,
              sourceShopId: localSourceShopId,
              destinationShopId: localDestinationShopId,
              sourceShopName: Value(sourceShopName),
              destinationShopName: Value(destinationShopName),
              status: Value(status),
              transferType: Value(
                detail['transferType'] as String? ?? StockTransferType.outbound,
              ),
              parentTransferId: Value(parentTransferId),
              notes: Value(detail['notes'] as String?),
              createdBy: createdBy,
              createdAt: timestamp,
              updatedAt: coerceRemoteInt(detail['updatedAt']) ?? timestamp,
              validatedAt: Value(coerceRemoteInt(detail['validatedAt'])),
              shippedAt: Value(coerceRemoteInt(detail['shippedAt'])),
              receivedAt: Value(coerceRemoteInt(detail['receivedAt'])),
              version: Value(coerceRemoteInt(detail['version']) ?? 1),
              serverId: Value(serverId),
              syncStatus: const Value('synced'),
              syncedAt: Value(nowMs()),
            ),
          );

      for (final resolved in resolvedItems) {
        final remoteItem = resolved['remoteItem'] as Map<String, dynamic>;
        final localProductId = resolved['localProductId'] as int;
        final destinationProductId =
            await _resolveDestinationProductIdFromRemote(
          inventoryLocal: inventoryLocal,
          destinationShopId: localDestinationShopId,
          remoteItem: remoteItem,
        );

        await _db.into(_db.stockTransferItems).insert(
              db.StockTransferItemsCompanion.insert(
                transferId: transferId,
                sourceProductId: localProductId,
                destinationProductId: Value(destinationProductId),
                productServerId: Value(
                  remoteItem['productServerId']?.toString() ??
                      remoteItem['sourceProductId']?.toString(),
                ),
                quantityRequested:
                    coerceRemoteInt(remoteItem['quantityRequested']) ?? 0,
                quantityShipped:
                    Value(coerceRemoteInt(remoteItem['quantityShipped']) ?? 0),
                quantityReceived:
                    Value(coerceRemoteInt(remoteItem['quantityReceived']) ?? 0),
              ),
            );
      }

      return transferId;
    });
  }

  Future<int> _resolveReceiveUnitCost({
    required int destinationShopId,
    required StockTransferItem item,
    required int destProductId,
    required InventoryLocalDatasource inventoryLocal,
  }) async {
    for (final line in item.lotLines ?? const <StockTransferLotLine>[]) {
      if (line.unitCost > 0) return line.unitCost;
    }

    final product = await inventoryLocal.findProduct(destinationShopId, destProductId);
    final priceBuy = product?.priceBuy;
    if (priceBuy != null && priceBuy > 0) return priceBuy;

    return 0;
  }

  int _lotLinesPendingQuantity(List<StockTransferLotLine> lotLines) =>
      lotLines.fold(0, (sum, line) => sum + line.quantityPendingReceive);

  Future<void> _insertSyntheticLotLine({
    required int transferItemId,
    required int quantity,
    required int quantityReceived,
    required int unitCost,
    int? shipmentId,
  }) async {
    if (quantity <= 0) return;

    await _db.into(_db.stockTransferLotLines).insert(
          db.StockTransferLotLinesCompanion.insert(
            transferItemId: transferItemId,
            shipmentId: Value(shipmentId),
            sourceLotId: const Value.absent(),
            quantity: quantity,
            quantityReceived: Value(quantityReceived),
            unitCost: unitCost,
          ),
        );
  }

  Future<void> _ensureLotLinesReadyForReceive({
    required int destinationShopId,
    required int transferId,
    required InventoryLocalDatasource inventoryLocal,
  }) async {
    final transfer = await findTransfer(transferId);
    if (transfer == null) return;

    for (final item in transfer.items ?? []) {
      final pendingReceive = item.quantityPendingReceive;
      if (pendingReceive <= 0) continue;

      final lotLines = item.lotLines ?? const <StockTransferLotLine>[];
      final linePending = _lotLinesPendingQuantity(lotLines);
      if (linePending >= pendingReceive) continue;

      final destProductId = await _resolveDestinationProductId(
        inventoryLocal: inventoryLocal,
        destinationShopId: destinationShopId,
        item: item,
      );
      if (destProductId == null) continue;

      final unitCost = await _resolveReceiveUnitCost(
        destinationShopId: destinationShopId,
        item: item,
        destProductId: destProductId,
        inventoryLocal: inventoryLocal,
      );

      if (lotLines.isEmpty) {
        await _insertSyntheticLotLine(
          transferItemId: item.id,
          quantity: item.quantityShipped,
          quantityReceived: item.quantityReceived,
          unitCost: unitCost,
        );
        continue;
      }

      final missing = pendingReceive - linePending;
      if (missing > 0) {
        await _insertSyntheticLotLine(
          transferItemId: item.id,
          quantity: missing,
          quantityReceived: 0,
          unitCost: unitCost,
        );
      }
    }
  }

  Future<void> _syncTransferLotLinesFromRemoteDetail({
    required int localTransferId,
    required int localDestinationShopId,
    required Map<String, dynamic> detail,
  }) async {
    final remoteItems = (detail['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (remoteItems.isEmpty) return;

    final transfer = await findTransfer(localTransferId);
    if (transfer == null) return;

    final inventoryLocal = InventoryLocalDatasource(_db);
    final usedRemoteIds = <int>{};

    for (final localItem in transfer.items ?? []) {
      final remoteItem = await _matchRemoteTransferItem(
        localItem: localItem,
        sourceShopId: transfer.sourceShopId,
        remoteItems: remoteItems,
        excludeRemoteIds: usedRemoteIds,
      );
      if (remoteItem == null) continue;

      final remoteItemId = coerceRemoteInt(remoteItem['id']);
      if (remoteItemId != null) usedRemoteIds.add(remoteItemId);

      final remoteLines = (remoteItem['lotLines'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      final localRows = await (_db.select(_db.stockTransferLotLines)
            ..where((l) => l.transferItemId.equals(localItem.id)))
          .get();
      final usedLocalLineIds = <int>{};

      if (remoteLines.isNotEmpty) {
        for (final remoteLine in remoteLines) {
          final quantity = coerceRemoteInt(remoteLine['quantity']) ?? 0;
          if (quantity <= 0) continue;

          final quantityReceived =
              coerceRemoteInt(remoteLine['quantityReceived']) ?? 0;
          final unitCost = coerceRemoteInt(remoteLine['unitCost']) ?? 0;

          db.StockTransferLotLine? matched;
          for (final localLine in localRows) {
            if (usedLocalLineIds.contains(localLine.id)) continue;
            if (localLine.unitCost == unitCost) {
              matched = localLine;
              break;
            }
          }

          if (matched != null) {
            usedLocalLineIds.add(matched.id);
            await (_db.update(_db.stockTransferLotLines)
                  ..where((l) => l.id.equals(matched!.id)))
                .write(
              db.StockTransferLotLinesCompanion(
                quantity: Value(
                  StockTransferStatus.mergeQuantity(
                    matched.quantity,
                    quantity,
                  ),
                ),
                quantityReceived: Value(
                  StockTransferStatus.mergeQuantity(
                    matched.quantityReceived,
                    quantityReceived,
                  ),
                ),
              ),
            );
            continue;
          }

          await _insertSyntheticLotLine(
            transferItemId: localItem.id,
            quantity: quantity,
            quantityReceived: quantityReceived,
            unitCost: unitCost,
            shipmentId: coerceRemoteInt(remoteLine['shipmentId']),
          );
        }
        continue;
      }

      if (localRows.isEmpty && localItem.quantityShipped > 0) {
        final destProductId = await _resolveDestinationProductId(
          inventoryLocal: inventoryLocal,
          destinationShopId: localDestinationShopId,
          item: localItem,
        );
        if (destProductId == null) continue;

        final unitCost = await _resolveReceiveUnitCost(
          destinationShopId: localDestinationShopId,
          item: localItem,
          destProductId: destProductId,
          inventoryLocal: inventoryLocal,
        );

        await _insertSyntheticLotLine(
          transferItemId: localItem.id,
          quantity: localItem.quantityShipped,
          quantityReceived: localItem.quantityReceived,
          unitCost: unitCost,
        );
      }
    }
  }

  Future<void> _syncTransferItemsFromRemoteDetail({
    required int localTransferId,
    required int localSourceShopId,
    required int localDestinationShopId,
    required Map<String, dynamic> detail,
  }) async {
    final remoteItems = (detail['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (remoteItems.isEmpty) return;

    final transfer = await findTransfer(localTransferId);
    if (transfer == null) return;

    final inventoryLocal = InventoryLocalDatasource(_db);
    final usedRemoteIds = <int>{};

    for (final localItem in transfer.items ?? []) {
      final remoteItem = await _matchRemoteTransferItem(
        localItem: localItem,
        sourceShopId: localSourceShopId,
        remoteItems: remoteItems,
        excludeRemoteIds: usedRemoteIds,
      );
      if (remoteItem == null) continue;

      final remoteItemId = coerceRemoteInt(remoteItem['id']);
      if (remoteItemId != null) usedRemoteIds.add(remoteItemId);

      final destinationProductId = await _resolveDestinationProductIdFromRemote(
        inventoryLocal: inventoryLocal,
        destinationShopId: localDestinationShopId,
        remoteItem: remoteItem,
      );

      await (_db.update(_db.stockTransferItems)
            ..where((i) => i.id.equals(localItem.id)))
          .write(
        db.StockTransferItemsCompanion(
          productServerId: Value(
            remoteItem['productServerId']?.toString() ??
                remoteItem['sourceProductId']?.toString(),
          ),
          destinationProductId: Value(destinationProductId),
          quantityShipped: Value(
            StockTransferStatus.mergeQuantity(
              localItem.quantityShipped,
              coerceRemoteInt(remoteItem['quantityShipped']) ?? 0,
            ),
          ),
          quantityReceived: Value(
            StockTransferStatus.mergeQuantity(
              localItem.quantityReceived,
              coerceRemoteInt(remoteItem['quantityReceived']) ?? 0,
            ),
          ),
        ),
      );
    }

    await _syncTransferLotLinesFromRemoteDetail(
      localTransferId: localTransferId,
      localDestinationShopId: localDestinationShopId,
      detail: detail,
    );
  }

  Future<int?> _resolveLocalSourceProductId({
    required InventoryLocalDatasource inventoryLocal,
    required int localSourceShopId,
    required Map<String, dynamic> remoteItem,
  }) async {
    final productServerId = remoteItem['productServerId']?.toString().trim();
    if (productServerId != null && productServerId.isNotEmpty) {
      final byServerId = await inventoryLocal.findLocalProductIdByServerId(
        localSourceShopId,
        productServerId,
      );
      if (byServerId != null) return byServerId;
    }

    final remoteSourceProductId = coerceRemoteInt(remoteItem['sourceProductId']);
    if (remoteSourceProductId != null) {
      final byRemoteId = await inventoryLocal.findLocalProductIdByServerId(
        localSourceShopId,
        '$remoteSourceProductId',
      );
      if (byRemoteId != null) return byRemoteId;

      final product =
          await inventoryLocal.findProduct(localSourceShopId, remoteSourceProductId);
      if (product != null) return product.id;
    }

    return null;
  }

  Future<int?> _resolveDestinationProductIdFromRemote({
    required InventoryLocalDatasource inventoryLocal,
    required int destinationShopId,
    required Map<String, dynamic> remoteItem,
  }) async {
    final remoteDestinationProductId =
        coerceRemoteInt(remoteItem['destinationProductId']);
    if (remoteDestinationProductId != null) {
      final byRemoteId = await inventoryLocal.findLocalProductIdByServerId(
        destinationShopId,
        '$remoteDestinationProductId',
      );
      if (byRemoteId != null) return byRemoteId;

      final product = await inventoryLocal.findProduct(
        destinationShopId,
        remoteDestinationProductId,
      );
      if (product != null) return product.id;
    }

    final productServerId = remoteItem['productServerId']?.toString().trim();
    if (productServerId != null && productServerId.isNotEmpty) {
      return inventoryLocal.findLocalProductIdByServerId(
        destinationShopId,
        productServerId,
      );
    }

    return null;
  }

  Future<void> applyRemoteStockTransferSnapshot(
    int localTransferId,
    Map<String, dynamic> remote,
  ) async {
    final serverId = remote['id']?.toString();
    final remoteVersion = (remote['version'] as num?)?.toInt() ?? 1;
    final remoteStatus = remote['status'] as String? ?? StockTransferStatus.draft;
    final timestamp = nowMs();

    if (serverId == null) return;

    final current = await (_db.select(_db.stockTransfers)
          ..where((t) => t.id.equals(localTransferId)))
        .getSingleOrNull();
    if (current == null) return;

    final mergedStatus = StockTransferStatus.mergeStatus(
      current.status,
      remoteStatus,
    );
    final mergedVersion =
        current.version > remoteVersion ? current.version : remoteVersion;
    final pending = await fetchAllPendingSyncOperations(
      transferId: localTransferId,
      sourceShopId: current.sourceShopId,
      destinationShopId: current.destinationShopId,
    );
    final syncStatus = pending.isEmpty ? 'synced' : 'pending';

    ({int sourceShopId, int destinationShopId})? endpoints;
    try {
      endpoints = await _resolveTransferEndpointsFromRemote(remote);
    } on ValidationFailure {
      endpoints = null;
    }

    final effectiveSourceShopId =
        endpoints?.sourceShopId ?? current.sourceShopId;
    final effectiveDestinationShopId =
        endpoints?.destinationShopId ?? current.destinationShopId;

    final mergedSourceShopName = _pickShopName(
      remote['sourceShopName'] as String?,
      await _lookupShopNameById(effectiveSourceShopId),
      current.sourceShopName,
    );
    final mergedDestinationShopName = _pickShopName(
      remote['destinationShopName'] as String?,
      await _lookupShopNameById(effectiveDestinationShopId),
      current.destinationShopName,
    );

    if (endpoints != null) {
      await reconcileTransferShopsFromRemote(
        localTransferId,
        remote,
        endpoints: endpoints,
      );
    }

    await (_db.update(_db.stockTransfers)..where((t) => t.id.equals(localTransferId)))
        .write(
      db.StockTransfersCompanion(
        serverId: Value(serverId),
        version: Value(mergedVersion),
        status: Value(mergedStatus),
        sourceShopId: endpoints != null
            ? Value(effectiveSourceShopId)
            : const Value.absent(),
        destinationShopId: endpoints != null
            ? Value(effectiveDestinationShopId)
            : const Value.absent(),
        sourceShopName: Value(mergedSourceShopName),
        destinationShopName: Value(mergedDestinationShopName),
        syncStatus: Value(syncStatus),
        syncedAt: Value(timestamp),
        updatedAt: Value(timestamp),
        validatedAt: Value(
          StockTransferStatus.mergeTimestamp(
            current.validatedAt,
            (remote['validatedAt'] as num?)?.toInt(),
          ),
        ),
        shippedAt: Value(
          StockTransferStatus.mergeTimestamp(
            current.shippedAt,
            (remote['shippedAt'] as num?)?.toInt(),
          ),
        ),
        receivedAt: Value(
          StockTransferStatus.mergeTimestamp(
            current.receivedAt,
            (remote['receivedAt'] as num?)?.toInt(),
          ),
        ),
        closedAt: Value(
          StockTransferStatus.mergeTimestamp(
            current.closedAt,
            (remote['closedAt'] as num?)?.toInt(),
          ),
        ),
      ),
    );

    if (StockTransferStatus.canShip(mergedStatus)) {
      await ensureTransferItemReservations(
        sourceShopId: effectiveSourceShopId,
        transferId: localTransferId,
      );
    }

    final remoteItems = (remote['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (remoteItems.isNotEmpty) {
      await linkRemoteTransferItemsFromSnapshot(localTransferId, remoteItems);
      await _syncTransferItemsFromRemoteDetail(
        localTransferId: localTransferId,
        localSourceShopId: effectiveSourceShopId,
        localDestinationShopId: effectiveDestinationShopId,
        detail: remote,
      );
    }

    await _syncReceiptsFromRemoteDetail(
      localTransferId: localTransferId,
      detail: remote,
    );

    await _syncEventsFromRemoteDetail(
      localTransferId: localTransferId,
      detail: remote,
      importUserId: current.createdBy,
    );

    await _syncDiscrepanciesFromRemoteDetail(
      localTransferId: localTransferId,
      detail: remote,
      importUserId: current.createdBy,
    );

    if (StockTransferStatus.progressionRank(mergedStatus) >=
        StockTransferStatus.progressionRank(
          StockTransferStatus.partiallyShipped,
        )) {
      await ensureDestinationProductsAtShip(
        destinationShopId: effectiveDestinationShopId,
        sourceShopId: effectiveSourceShopId,
        transferId: localTransferId,
      );
    }

    await clearObsoleteTransferQueueOps(localTransferId);
  }

  Future<void> _syncEventsFromRemoteDetail({
    required int localTransferId,
    required Map<String, dynamic> detail,
    required int importUserId,
  }) async {
    final remoteEvents = (detail['events'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList();
    if (remoteEvents == null || remoteEvents.isEmpty) return;

    final transfer = await findTransfer(localTransferId);
    if (transfer == null) return;

    final existing = await _loadEvents(localTransferId);
    final existingKeys = existing
        .map((event) => '${event.eventType}:${event.createdAt}')
        .toSet();

    for (final remoteEvent in remoteEvents) {
      final eventType = remoteEvent['eventType'] as String?;
      final createdAt = coerceRemoteInt(remoteEvent['createdAt']);
      if (eventType == null || createdAt == null) continue;
      if (existingKeys.contains('$eventType:$createdAt')) continue;

      final remoteShopId = coerceRemoteInt(remoteEvent['shopId']);
      final localShopId = remoteShopId != null
          ? await resolveLocalShopId(remoteShopId)
          : transfer.sourceShopId;

      final actorUserId = await resolveImportUserId(
        shopId: localShopId,
        fallbackUserId: importUserId,
        remoteUserId: coerceRemoteInt(remoteEvent['actorUserId']),
      );

      final payload = remoteEvent['payload'];
      String? payloadJson;
      if (payload is Map) {
        payloadJson = jsonEncode(payload);
      } else if (payload is String) {
        payloadJson = payload;
      }

      await _insertTransferEvent(
        transferId: localTransferId,
        shopId: localShopId,
        eventType: eventType,
        actorUserId: actorUserId,
        notes: remoteEvent['notes'] as String?,
        payloadJson: payloadJson,
        createdAt: createdAt,
      );
      existingKeys.add('$eventType:$createdAt');
    }
  }

  Future<void> _syncDiscrepanciesFromRemoteDetail({
    required int localTransferId,
    required Map<String, dynamic> detail,
    required int importUserId,
  }) async {
    final remoteRows = (detail['discrepancies'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList();
    if (remoteRows == null || remoteRows.isEmpty) return;

    final transfer = await findTransfer(localTransferId);
    if (transfer == null) return;

    final remoteItems = (detail['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final itemMapping = await buildRemoteItemMapping(
      transfer: transfer,
      remoteItems: remoteItems,
    );
    final remoteToLocalItem = <int, int>{
      for (final row in itemMapping)
        if (row['remoteItemId'] != null && row['localItemId'] != null)
          row['remoteItemId'] as int: row['localItemId'] as int,
    };

    for (final remoteRow in remoteRows) {
      final remoteItemId = coerceRemoteInt(remoteRow['transferItemId']);
      final localItemId =
          remoteItemId != null ? remoteToLocalItem[remoteItemId] : null;
      if (localItemId == null) continue;

      final quantity = coerceRemoteInt(remoteRow['quantity']) ?? 0;
      final resolvedAt = coerceRemoteInt(remoteRow['resolvedAt']) ?? nowMs();
      final reason = remoteRow['reason'] as String? ?? StockTransferDiscrepancyReason.other;
      final resolution =
          remoteRow['resolution'] as String? ?? StockTransferDiscrepancyResolution.writeOff;

      final exists = await (_db.select(_db.stockTransferDiscrepancies)
            ..where(
              (d) =>
                  d.transferId.equals(localTransferId) &
                  d.transferItemId.equals(localItemId) &
                  d.quantity.equals(quantity) &
                  d.resolvedAt.equals(resolvedAt),
            ))
          .getSingleOrNull();
      if (exists != null) continue;

      final resolvedBy = await resolveImportUserId(
        shopId: transfer.sourceShopId,
        fallbackUserId: importUserId,
        remoteUserId: coerceRemoteInt(remoteRow['resolvedBy']),
      );

      await _db.into(_db.stockTransferDiscrepancies).insert(
            db.StockTransferDiscrepanciesCompanion.insert(
              transferId: localTransferId,
              transferItemId: localItemId,
              quantity: quantity,
              reason: reason,
              resolution: resolution,
              notes: Value(remoteRow['notes'] as String?),
              resolvedBy: resolvedBy,
              resolvedAt: resolvedAt,
              createdAt: coerceRemoteInt(remoteRow['createdAt']) ?? resolvedAt,
            ),
          );
    }
  }

  Future<void> _syncReceiptsFromRemoteDetail({
    required int localTransferId,
    required Map<String, dynamic> detail,
  }) async {
    final remoteReceipts = (detail['receipts'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList();
    if (remoteReceipts == null || remoteReceipts.isEmpty) return;

    final transfer = await findTransfer(localTransferId);
    if (transfer == null) return;

    final remoteItems = (detail['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final itemMapping = await buildRemoteItemMapping(
      transfer: transfer,
      remoteItems: remoteItems,
    );
    final remoteToLocalItem = <int, int>{
      for (final row in itemMapping)
        if (row['remoteItemId'] != null && row['localItemId'] != null)
          row['remoteItemId'] as int: row['localItemId'] as int,
    };

    final remoteShipments = (detail['shipments'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    for (final remoteReceipt in remoteReceipts) {
      final reference = remoteReceipt['reference'] as String?;
      if (reference == null || reference.isEmpty) continue;

      final existing = await (_db.select(_db.stockTransferReceipts)
            ..where(
              (r) =>
                  r.transferId.equals(localTransferId) &
                  r.reference.equals(reference),
            ))
          .getSingleOrNull();

      final remoteShipmentId = coerceRemoteInt(remoteReceipt['shipmentId']);
      final localShipmentId = remoteShipmentId != null
          ? resolveLocalShipmentIdFromRemote(
              transfer: transfer,
              remoteShipmentId: remoteShipmentId,
              remoteShipments: remoteShipments,
            )
          : null;

      final receivedAt =
          coerceRemoteInt(remoteReceipt['receivedAt']) ?? nowMs();
      final receivedBy = await resolveImportUserId(
        shopId: transfer.destinationShopId,
        fallbackUserId: transfer.createdBy,
        remoteUserId: coerceRemoteInt(remoteReceipt['receivedBy']),
      );

      final localReceiptId = existing?.id ??
          await _db.into(_db.stockTransferReceipts).insert(
                db.StockTransferReceiptsCompanion.insert(
                  transferId: localTransferId,
                  shipmentId: Value(localShipmentId),
                  reference: reference,
                  notes: Value(remoteReceipt['notes'] as String?),
                  receivedBy: receivedBy,
                  receivedAt: receivedAt,
                  createdAt: receivedAt,
                ),
              );

      final remoteReceiptItems = (remoteReceipt['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      for (final remoteItem in remoteReceiptItems) {
        final remoteItemId = coerceRemoteInt(remoteItem['transferItemId']);
        final localItemId =
            remoteItemId != null ? remoteToLocalItem[remoteItemId] : null;
        if (localItemId == null) continue;

        final qty = coerceRemoteInt(remoteItem['quantityReceived']) ?? 0;
        final refused = coerceRemoteInt(remoteItem['quantityRefused']) ?? 0;
        if (qty <= 0 && refused <= 0) continue;

        final exists = await (_db.select(_db.stockTransferReceiptItems)
              ..where(
                (i) =>
                    i.receiptId.equals(localReceiptId) &
                    i.transferItemId.equals(localItemId),
              ))
            .getSingleOrNull();
        if (exists != null) continue;

        await _db.into(_db.stockTransferReceiptItems).insert(
              db.StockTransferReceiptItemsCompanion.insert(
                receiptId: localReceiptId,
                transferItemId: localItemId,
                quantityReceived: qty,
                quantityRefused: Value(refused),
                refusalReason: Value(remoteItem['refusalReason'] as String?),
                refusalResolution:
                    Value(remoteItem['refusalResolution'] as String?),
                createdAt: receivedAt,
              ),
            );
      }
    }
  }

  /// Aligne source/destination locales sur le snapshot serveur (ids cloud).
  Future<({int sourceShopId, int destinationShopId})?> reconcileTransferShopsFromRemote(
    int localTransferId,
    Map<String, dynamic> remote, {
    ({int sourceShopId, int destinationShopId})? endpoints,
  }) async {
    final resolved = endpoints ?? await _tryResolveTransferEndpointsFromRemote(remote);
    if (resolved == null) return null;

    final current = await (_db.select(_db.stockTransfers)
          ..where((t) => t.id.equals(localTransferId)))
        .getSingleOrNull();
    if (current == null) return null;

    final localSourceShopId = resolved.sourceShopId;
    final localDestinationShopId = resolved.destinationShopId;

    if (localSourceShopId == current.sourceShopId &&
        localDestinationShopId == current.destinationShopId) {
      return null;
    }

    if (localDestinationShopId != current.destinationShopId) {
      await (_db.update(_db.syncQueue)
            ..where(
              (q) =>
                  q.entityTable.equals(SyncEntityTable.stockTransfers) &
                  q.recordId.equals(localTransferId) &
                  q.operation.equals(SyncOperation.receive) &
                  q.status.equals('pending'),
            ))
          .write(
        db.SyncQueueCompanion(
          shopId: Value(localDestinationShopId),
        ),
      );
    }

    return (
      sourceShopId: localSourceShopId,
      destinationShopId: localDestinationShopId,
    );
  }

  Future<({int sourceShopId, int destinationShopId})?> _tryResolveTransferEndpointsFromRemote(
    Map<String, dynamic> remote,
  ) async {
    try {
      return await _resolveTransferEndpointsFromRemote(remote);
    } on ValidationFailure {
      return null;
    }
  }

  static int? destinationServerIdFromRemote(Map<String, dynamic> remote) =>
      coerceRemoteInt(remote['destinationShopId']);
}

class PendingIncomingTransfer {
  const PendingIncomingTransfer({
    required this.transferId,
    required this.reference,
    required this.pendingUnits,
    required this.status,
    this.sourceShopName,
  });

  final int transferId;
  final String reference;
  final String? sourceShopName;
  final int pendingUnits;
  final String status;
}
