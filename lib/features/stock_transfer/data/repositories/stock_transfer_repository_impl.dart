import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/sync/sync_constants.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_pull_entity.dart';
import '../../../shop/domain/repositories/shop_repository.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/repositories/stock_transfer_repository.dart';
import '../../domain/utils/stock_transfer_cloud_gate.dart';
import '../datasources/stock_transfer_local_datasource.dart';
import '../datasources/stock_transfer_remote_datasource.dart';
import '../utils/stock_transfer_cloud_sync_helper.dart';
import '../utils/stock_transfer_remote_payloads.dart';
import '../utils/stock_transfer_qr_payload.dart';
import '../utils/stock_transfer_qr_payload.dart' as qr_payload;

class StockTransferRepositoryImpl implements StockTransferRepository {
  StockTransferRepositoryImpl({
    required StockTransferLocalDatasource local,
    required StockTransferRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
    required SyncPolicy syncPolicy,
    required ShopRepository shopRepository,
    LocalWriteSyncRecorder? recorder,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _syncPolicy = syncPolicy,
        _shopRepository = shopRepository,
        _recorder = recorder;

  final StockTransferLocalDatasource _local;
  final StockTransferRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;
  final SyncPolicy _syncPolicy;
  final ShopRepository _shopRepository;
  final LocalWriteSyncRecorder? _recorder;

  @override
  Future<List<ShopOption>> listDestinationShops({required int currentShopId}) =>
      _local.listOtherShops(currentShopId);

  @override
  Future<List<StockTransfer>> listOutgoing({required int shopId}) =>
      _local.listOutgoing(shopId);

  @override
  Future<List<StockTransfer>> listIncoming({required int shopId}) =>
      _local.listIncoming(shopId);

  @override
  Future<List<StockTransfer>> listInTransit({required int shopId}) =>
      _local.listInTransit(shopId);

  @override
  Future<StockTransfer?> findTransfer({
    required int transferId,
    required int shopId,
  }) async {
    final cloudEnabled = await _syncPolicy.shouldRunCloudSync(shopId: shopId);
    return _local.findTransfer(
      transferId,
      cloudSyncEnabled: cloudEnabled,
    );
  }

  @override
  Future<List<TransferMissingDestinationProduct>> listMissingDestinationProducts({
    required int destinationShopId,
    required int transferId,
    Map<int, int>? quantitiesByItemId,
    int? shipmentId,
  }) =>
      _local.listMissingDestinationProducts(
        destinationShopId: destinationShopId,
        transferId: transferId,
        quantitiesByItemId: quantitiesByItemId,
        shipmentId: shipmentId,
      );

  Future<void> _assertCloudGateForShip({
    required int sourceShopId,
    required int transferId,
  }) async {
    if (!await _syncPolicy.shouldRunCloudSync(shopId: sourceShopId)) return;
    final transfer = await _local.findTransfer(
      transferId,
      cloudSyncEnabled: true,
    );
    if (transfer == null) return;
    if (!StockTransferCloudGate.canShip(
      transfer: transfer,
      cloudSyncEnabled: true,
    )) {
      throw ValidationFailure(
        StockTransferCloudGate.shipBlockedMessage(transfer) ??
            'Synchronisation cloud en cours.',
      );
    }
  }

  @override
  Future<String> nextReference({required int shopId}) async {
    try {
      await _apiGuard.ensureReady();
      final remoteRef = await _remote.fetchNextReference();
      if (remoteRef.trim().isNotEmpty) {
        return _local.allocateUniqueReference(
          shopId,
          preferred: remoteRef.trim(),
        );
      }
    } catch (_) {
      // Hors ligne ou API indisponible : numérotation locale.
    }
    return _local.allocateUniqueReference(shopId);
  }

  Future<void> _invalidateTransferCaches({
    required int sourceShopId,
    required int destinationShopId,
  }) async {
    await _syncPolicy.invalidateEntitiesForWrite(
      shopId: sourceShopId,
      entityTable: SyncEntityTable.stockTransfers,
    );
    if (destinationShopId != sourceShopId) {
      await _syncPolicy.invalidateEntitiesForWrite(
        shopId: destinationShopId,
        entityTable: SyncEntityTable.stockTransfers,
      );
    }
  }

  @override
  Future<StockTransfer> createTransfer({
    required int sourceShopId,
    required int destinationShopId,
    required int userId,
    required String reference,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final transfer = await _local.createTransfer(
      sourceShopId: sourceShopId,
      destinationShopId: destinationShopId,
      userId: userId,
      reference: reference,
      notes: notes,
      items: items,
    );

    await _recorder?.recordStockTransferCreate(
      shopId: sourceShopId,
      transferId: transfer.id,
      payload: {
        'destinationShopId': destinationShopId,
        'reference': transfer.reference,
        if (notes != null) 'notes': notes,
        'items': items,
      },
    );
    await _invalidateTransferCaches(
      sourceShopId: sourceShopId,
      destinationShopId: destinationShopId,
    );

    _pushTransferCreateInBackground(
      sourceShopId: sourceShopId,
      transfer: transfer,
      destinationShopId: destinationShopId,
      items: items,
    );

    return transfer;
  }

  @override
  Future<StockTransfer> validateTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  }) async {
    final transfer = await _local.validateTransfer(
      sourceShopId: sourceShopId,
      userId: userId,
      transferId: transferId,
    );

    await _recorder?.recordStockTransferValidate(
      shopId: sourceShopId,
      transferId: transferId,
    );
    await _invalidateTransferCaches(
      sourceShopId: sourceShopId,
      destinationShopId: transfer.destinationShopId,
    );

    _pushTransferValidateInBackground(sourceShopId, transferId);
    return transfer;
  }

  @override
  Future<StockTransfer> submitTransferForApproval({
    required int sourceShopId,
    required int userId,
    required int transferId,
  }) async {
    final transfer = await _local.submitTransferForApproval(
      sourceShopId: sourceShopId,
      userId: userId,
      transferId: transferId,
    );

    await _recorder?.recordStockTransferSubmit(
      shopId: sourceShopId,
      transferId: transferId,
    );
    await _invalidateTransferCaches(
      sourceShopId: sourceShopId,
      destinationShopId: transfer.destinationShopId,
    );

    _pushTransferSubmitInBackground(sourceShopId, transferId);
    return transfer;
  }

  @override
  Future<StockTransfer> approveTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  }) async {
    final transfer = await _local.approveTransfer(
      sourceShopId: sourceShopId,
      userId: userId,
      transferId: transferId,
    );

    await _recorder?.recordStockTransferApprove(
      shopId: sourceShopId,
      transferId: transferId,
    );
    await _invalidateTransferCaches(
      sourceShopId: sourceShopId,
      destinationShopId: transfer.destinationShopId,
    );

    _pushTransferApproveInBackground(sourceShopId, transferId);
    return transfer;
  }

  @override
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
    await _assertCloudGateForShip(
      sourceShopId: sourceShopId,
      transferId: transferId,
    );
    final transfer = await _local.shipTransfer(
      sourceShopId: sourceShopId,
      userId: userId,
      transferId: transferId,
      shipmentLabel: shipmentLabel,
      shipmentNotes: shipmentNotes,
      driverName: driverName,
      vehiclePlate: vehiclePlate,
      quantitiesByItemId: quantitiesByItemId,
    );

    final quantitiesForSync = _local.resolveShipQuantitiesForSync(
      transfer: transfer,
      payload: {
        'label': shipmentLabel,
        if (quantitiesByItemId != null)
          'quantitiesByItemId':
              quantitiesByItemId.map((k, v) => MapEntry('$k', v)),
      },
    );

    await _recorder?.recordStockTransferValidate(
      shopId: sourceShopId,
      transferId: transferId,
    );

    await _recorder?.recordStockTransferShip(
      shopId: sourceShopId,
      transferId: transferId,
      payload: {
        'label': shipmentLabel,
        if (shipmentNotes != null) 'notes': shipmentNotes,
        if (driverName != null && driverName.trim().isNotEmpty)
          'driverName': driverName.trim(),
        if (vehiclePlate != null && vehiclePlate.trim().isNotEmpty)
          'vehiclePlate': vehiclePlate.trim(),
        'quantitiesByItemId':
            quantitiesForSync.map((k, v) => MapEntry('$k', v)),
      },
    );
    await _invalidateTransferCaches(
      sourceShopId: sourceShopId,
      destinationShopId: transfer.destinationShopId,
    );

    _pushTransferShipInBackground(
      sourceShopId,
      transferId,
      shipmentLabel: shipmentLabel,
      shipmentNotes: shipmentNotes,
      driverName: driverName,
      vehiclePlate: vehiclePlate,
      quantitiesByItemId: quantitiesForSync,
    );
    return transfer;
  }

  @override
  Future<StockTransferReportSummary> buildReportSummary({required int shopId}) =>
      _local.buildReportSummary(shopId);

  @override
  Future<Set<int>> shopAliases(int shopId) =>
      _local.localShopIdsInSameCloudShop(shopId);

  @override
  Future<StockTransfer> receiveTransfer({
    required int destinationShopId,
    required int userId,
    required int transferId,
    Map<int, int>? quantitiesByItemId,
    Map<int, int>? salePriceByItemId,
    Map<int, StockTransferReceiveRefusal>? refusalsByItemId,
    int? shipmentId,
  }) async {
    final effectiveDestinationShopId =
        await _local.canonicalLocalShopId(destinationShopId);

    final transferForSource = await _local.findTransfer(transferId);
    if (transferForSource == null) {
      throw const NotFoundFailure('Transfert introuvable.');
    }

    final missing = await _local.listMissingDestinationProducts(
      destinationShopId: effectiveDestinationShopId,
      transferId: transferId,
      quantitiesByItemId: quantitiesByItemId,
      shipmentId: shipmentId,
    );

    final effectivePrices = <int, int>{
      ...?salePriceByItemId,
      for (final product in missing)
        product.itemId: salePriceByItemId?[product.itemId] ??
            _local.defaultSalePriceForMissingProduct(product),
    };

    ({Map<int, int> productIds, Set<int> newlyCreatedItemIds})? createResult;
    if (missing.isNotEmpty) {
      createResult = await _local.createDestinationProductsForReceive(
        destinationShopId: effectiveDestinationShopId,
        sourceShopId: transferForSource.sourceShopId,
        salePriceByItemId: effectivePrices,
        products: missing,
      );
      await _recordCreatedProductsForSync(
        shopId: effectiveDestinationShopId,
        products: missing,
        salePriceByItemId: effectivePrices,
        createdProductIds: createResult.productIds,
        newlyCreatedItemIds: createResult.newlyCreatedItemIds,
      );
    }

    final transfer = await _local.receiveTransfer(
      destinationShopId: effectiveDestinationShopId,
      userId: userId,
      transferId: transferId,
      quantitiesByItemId: quantitiesByItemId,
      refusalsByItemId: refusalsByItemId,
      shipmentId: shipmentId,
    );

    final quantitiesForSync = _local.resolveReceiveQuantitiesForSync(
      transfer: transfer,
      payload: {
        if (quantitiesByItemId != null)
          'quantitiesByItemId':
              quantitiesByItemId.map((k, v) => MapEntry('$k', v)),
      },
    );

    final productSetups = missing
        .where(
          (product) =>
              createResult?.newlyCreatedItemIds.contains(product.itemId) ?? false,
        )
        .map(
          (product) => {
            'itemId': product.itemId,
            'name': product.productName,
            'priceSell': effectivePrices[product.itemId],
            if (product.productServerId != null)
              'productServerId': product.productServerId,
            if (product.suggestedPriceBuy != null)
              'priceBuy': product.suggestedPriceBuy,
          },
        )
        .toList();

    await _recorder?.recordStockTransferReceive(
      shopId: effectiveDestinationShopId,
      transferId: transferId,
      payload: {
        'quantitiesByItemId':
            quantitiesForSync.map((k, v) => MapEntry('$k', v)),
        if (shipmentId != null) 'shipmentId': shipmentId,
        if (productSetups.isNotEmpty) 'productSetups': productSetups,
        if (refusalsByItemId != null && refusalsByItemId.isNotEmpty)
          'refusalsByItemId': refusalsByItemId.map(
            (itemId, refusal) => MapEntry(
              '$itemId',
              {
                'quantity': refusal.quantity,
                'reason': refusal.reason,
                'resolution': refusal.resolution,
              },
            ),
          ),
      },
    );
    await _invalidateTransferCaches(
      sourceShopId: transfer.sourceShopId,
      destinationShopId: effectiveDestinationShopId,
    );

    _pushTransferReceiveInBackground(
      destinationShopId: effectiveDestinationShopId,
      transferId: transferId,
      quantitiesByItemId: quantitiesForSync,
      productSetups: productSetups,
      refusalsByItemId: refusalsByItemId,
      shipmentId: shipmentId,
    );

    return transfer;
  }

  Future<void> _recordCreatedProductsForSync({
    required int shopId,
    required List<TransferMissingDestinationProduct> products,
    required Map<int, int> salePriceByItemId,
    required Map<int, int> createdProductIds,
    required Set<int> newlyCreatedItemIds,
  }) async {
    final recorder = _recorder;
    if (recorder == null || products.isEmpty) return;

    final categoryId = await _local.resolveTransferImportCategoryId(shopId);

    for (final product in products) {
      if (!newlyCreatedItemIds.contains(product.itemId)) continue;

      final productId = createdProductIds[product.itemId];
      if (productId == null) continue;

      await recorder.recordProductCreate(
        shopId: shopId,
        productId: productId,
        payload: {
          'name': product.productName,
          'localCategoryId': categoryId,
          'priceSell': salePriceByItemId[product.itemId],
          if (product.suggestedPriceBuy != null)
            'priceBuy': product.suggestedPriceBuy,
          'initialQuantity': 0,
        },
      );
    }
  }

  @override
  Future<void> cancelTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  }) async {
    final before = await _local.findTransfer(transferId);
    await _local.cancelTransfer(
      sourceShopId: sourceShopId,
      userId: userId,
      transferId: transferId,
    );

    if (before != null) {
      await _invalidateTransferCaches(
        sourceShopId: sourceShopId,
        destinationShopId: before.destinationShopId,
      );
    }

    final serverId = await _local.findTransferServerId(transferId);
    if (serverId == null) {
      await _local.purgePendingTransferSyncOps(transferId);
      return;
    }

    await _recorder?.recordStockTransferCancel(
      shopId: sourceShopId,
      transferId: transferId,
    );

    _pushTransferCancelInBackground(sourceShopId, transferId);
  }

  @override
  Future<StockTransfer> closeTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
    String? notes,
  }) async {
    final transfer = await _local.closeTransfer(
      sourceShopId: sourceShopId,
      userId: userId,
      transferId: transferId,
      notes: notes,
    );

    await _recorder?.recordStockTransferClose(
      shopId: sourceShopId,
      transferId: transferId,
      payload: {if (notes != null && notes.isNotEmpty) 'notes': notes},
    );
    await _invalidateTransferCaches(
      sourceShopId: sourceShopId,
      destinationShopId: transfer.destinationShopId,
    );

    _pushTransferCloseInBackground(
      sourceShopId: sourceShopId,
      transferId: transferId,
      notes: notes,
    );
    return transfer;
  }

  @override
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
    final transfer = await _local.resolveDiscrepancy(
      sourceShopId: sourceShopId,
      userId: userId,
      transferId: transferId,
      itemId: itemId,
      quantity: quantity,
      reason: reason,
      resolution: resolution,
      notes: notes,
    );

    await _recorder?.recordStockTransferResolveDiscrepancy(
      shopId: sourceShopId,
      transferId: transferId,
      payload: {
        'itemId': itemId,
        'quantity': quantity,
        'reason': reason,
        'resolution': resolution,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    await _invalidateTransferCaches(
      sourceShopId: sourceShopId,
      destinationShopId: transfer.destinationShopId,
    );

    _pushTransferResolveDiscrepancyInBackground(
      sourceShopId: sourceShopId,
      transferId: transferId,
      itemId: itemId,
      quantity: quantity,
      reason: reason,
      resolution: resolution,
      notes: notes,
    );
    return transfer;
  }

  @override
  Future<StockTransferQrReceiveIntent> resolveQrReceiveIntent({
    required String rawPayload,
    required int destinationShopId,
  }) =>
      _local.resolveQrReceiveIntent(
        rawPayload: rawPayload,
        destinationShopId: destinationShopId,
      );

  @override
  Future<StockTransferQrPayload> buildShipmentQrPayload({
    required int transferId,
    required int shipmentId,
  }) async {
    final transfer = await _local.findTransfer(transferId);
    if (transfer == null) {
      throw StateError('Transfert introuvable.');
    }
    StockTransferShipment? matchedShipment;
    for (final s in transfer.shipments ?? []) {
      if (s.id == shipmentId) {
        matchedShipment = s;
        break;
      }
    }
    if (matchedShipment == null) {
      throw StateError('Expédition introuvable.');
    }

    final sourceShopServerId =
        (await _local.resolveShopServerId(transfer.sourceShopId))?.toString();
    final destinationShopServerId =
        (await _local.resolveShopServerId(transfer.destinationShopId))?.toString();

    return qr_payload.buildShipmentQrPayload(
      transfer: transfer,
      shipment: matchedShipment,
      sourceShopServerId: sourceShopServerId,
      destinationShopServerId: destinationShopServerId,
    );
  }

  @override
  Future<StockTransfer> createReturnTransfer({
    required int shopId,
    required int userId,
    required int parentTransferId,
    Map<int, int>? quantitiesByParentItemId,
  }) async {
    final transfer = await _local.createReturnTransfer(
      shopId: shopId,
      userId: userId,
      parentTransferId: parentTransferId,
      quantitiesByParentItemId: quantitiesByParentItemId,
    );

    await _recorder?.recordStockTransferCreate(
      shopId: shopId,
      transferId: transfer.id,
      payload: {
        'destinationShopId': transfer.destinationShopId,
        'reference': transfer.reference,
        'notes': transfer.notes,
        'transferType': transfer.transferType,
        'parentTransferId': parentTransferId,
        'items': (transfer.items ?? [])
            .map(
              (it) => {
                'productId': it.sourceProductId,
                'quantityRequested': it.quantityRequested,
              },
            )
            .toList(),
      },
    );
    await _invalidateTransferCaches(
      sourceShopId: shopId,
      destinationShopId: transfer.destinationShopId,
    );

    _pushTransferCreateInBackground(
      sourceShopId: shopId,
      transfer: transfer,
      destinationShopId: transfer.destinationShopId,
      items: (transfer.items ?? [])
          .map(
            (it) => {
              'productId': it.sourceProductId,
              'quantityRequested': it.quantityRequested,
            },
          )
          .toList(),
    );

    return transfer;
  }

  @override
  Future<void> syncFromRemote({
    required int shopId,
    bool force = false,
    int? importUserId,
  }) async {
    if (!await _syncPolicy.shouldPullEntity(
      shopId: shopId,
      entity: SyncPullEntity.stockTransfers,
      force: force,
    )) {
      return;
    }

    await _apiGuard.ensureReady();

    try {
      await _shopRepository.listShops();
    } catch (_) {
      // Best-effort : aligner les serverId avant de mapper source/destination.
    }

    final outgoing = await _remote.fetchOutgoing();
    final incoming = await _remote.fetchIncoming();
    List<Map<String, dynamic>> inTransit = const [];
    try {
      inTransit = await _remote.fetchInTransit();
    } catch (_) {}
    final seenServerIds = <String>{};
    final all = <Map<String, dynamic>>[];

    for (final raw in [...outgoing, ...incoming, ...inTransit]) {
      final serverId = raw['id']?.toString();
      if (serverId == null || serverId.isEmpty) continue;
      if (seenServerIds.add(serverId)) {
        all.add(raw);
      }
    }

    all.sort((a, b) {
      final aCreated = (a['createdAt'] as num?)?.toInt() ?? 0;
      final bCreated = (b['createdAt'] as num?)?.toInt() ?? 0;
      return aCreated.compareTo(bCreated);
    });

    final fallbackUserId =
        importUserId ?? await _local.resolveFallbackUserId(shopId);

    for (final raw in all) {
      final serverId = raw['id']?.toString();
      if (serverId == null) continue;

      Map<String, dynamic> detail = raw;
      final serverInt = int.tryParse(serverId);
      if (serverInt != null) {
        try {
          detail = await _remote.fetchTransfer(serverInt);
        } catch (_) {}
      }

      await _local.upsertTransferFromRemoteDetail(
        currentShopId: shopId,
        detail: detail,
        importUserId: fallbackUserId,
      );
    }

    await _syncPolicy.markEntitySynced(
      shopId: shopId,
      entity: SyncPullEntity.stockTransfers,
    );
  }

  void _pushTransferCreateInBackground({
    required int sourceShopId,
    required StockTransfer transfer,
    required int destinationShopId,
    required List<Map<String, dynamic>> items,
  }) {
    Future(() async {
      try {
        if (await _local.findTransferServerId(transfer.id) != null) return;
        await _apiGuard.ensureReady();

        final destServerId = await _local.resolveShopServerId(destinationShopId);
        if (destServerId == null) return;

        final remoteItems = <Map<String, dynamic>>[];
        for (final it in items) {
          final productId = it['productId'] as int;
          final serverProductId = await _local.resolveProductServerId(
            sourceShopId,
            productId,
          );
          if (serverProductId == null) return;
          remoteItems.add({
            'productId': serverProductId,
            'quantityRequested': it['quantityRequested'],
          });
        }

        int? parentServerId;
        if (transfer.parentTransferId != null) {
          final raw =
              await _local.findTransferServerId(transfer.parentTransferId!);
          parentServerId = raw != null ? int.tryParse(raw) : null;
        }

        var working = transfer;
        for (var attempt = 0; attempt < 5; attempt++) {
          try {
            final remote = await _remote.createTransfer(
              StockTransferRemotePayloads.createBody(
                destinationShopId: destServerId,
                reference: working.reference,
                notes: working.notes,
                items: remoteItems,
                transferType: working.transferType,
                parentTransferId: parentServerId,
              ),
            );
            await _local.applyRemoteStockTransferSnapshot(working.id, remote);
            await _invalidateTransferCaches(
              sourceShopId: sourceShopId,
              destinationShopId: destinationShopId,
            );
            return;
          } on Failure catch (error) {
            final message = error.message.toLowerCase();
            final isDuplicate = message.contains('référence') ||
                message.contains('reference') ||
                message.contains('déjà utilisée') ||
                message.contains('already');
            if (!isDuplicate || attempt == 4) return;

            final newRef = await _local.allocateUniqueReference(sourceShopId);
            await _local.updateTransferReference(working.id, newRef);
            final refreshed = await _local.findTransfer(working.id);
            if (refreshed == null) return;
            working = refreshed;
          }
        }
      } catch (_) {}
    });
  }

  void _pushTransferValidateInBackground(int sourceShopId, int transferId) {
    Future(() async {
      try {
        final serverId = await _resolveTransferServerId(transferId);
        if (serverId == null) return;
        final transfer = await _local.findTransfer(transferId);
        if (transfer == null) return;

        await _apiGuard.ensureReady();
        final helper = StockTransferCloudSyncHelper(
          local: _local,
          remote: _remote,
        );
        await helper.ensureValidatedOnServer(
          localTransferId: transferId,
          serverTransferId: serverId,
        );
      } catch (_) {}
    });
  }

  void _pushTransferShipInBackground(
    int sourceShopId,
    int transferId, {
    required String shipmentLabel,
    String? shipmentNotes,
    String? driverName,
    String? vehiclePlate,
    Map<int, int>? quantitiesByItemId,
  }) {
    Future(() async {
      try {
        final serverId = await _resolveTransferServerId(transferId);
        if (serverId == null) return;
        final transfer = await _local.findTransfer(transferId);
        if (transfer == null) return;

        await _apiGuard.ensureReady();

        final helper = StockTransferCloudSyncHelper(
          local: _local,
          remote: _remote,
        );
        final ensured = await helper.ensureValidatedOnServer(
          localTransferId: transferId,
          serverTransferId: serverId,
          requireShippable: true,
        );
        if (!ensured.ok) return;
        if (ensured.alreadyComplete) {
          if (ensured.remote != null) {
            await _local.applyRemoteStockTransferSnapshot(
              transferId,
              ensured.remote!,
            );
          }
          return;
        }

        await helper.runOnSourceShop(
          transfer: transfer,
          action: () async {
            final remoteDetail = ensured.remote ??
                await _remote.fetchTransfer(serverId);
            final remoteItems = (remoteDetail['items'] as List?)
                    ?.whereType<Map<String, dynamic>>()
                    .toList() ??
                [];

            final mapping = await _local.buildRemoteItemMapping(
              transfer: transfer,
              remoteItems: remoteItems,
            );
            if (mapping.isEmpty) return;

            final qtyMap = _local.resolveShipQuantitiesForSync(
              transfer: transfer,
              payload: {
                'label': shipmentLabel,
                if (quantitiesByItemId != null)
                  'quantitiesByItemId':
                      quantitiesByItemId.map((k, v) => MapEntry('$k', v)),
              },
            );
            if (qtyMap.isEmpty) return;

            final body = StockTransferRemotePayloads.shipBody(
              label: shipmentLabel,
              notes: shipmentNotes,
              driverName: driverName,
              vehiclePlate: vehiclePlate,
              quantitiesByItemId: qtyMap,
              remoteItems: mapping,
            );

            final remote = await _remote.shipTransfer(serverId, body);
            await _local.applyRemoteStockTransferSnapshot(transferId, remote);
          },
        );
      } catch (_) {}
    });
  }

  void _pushTransferReceiveInBackground({
    required int destinationShopId,
    required int transferId,
    Map<int, int>? quantitiesByItemId,
    Map<int, StockTransferReceiveRefusal>? refusalsByItemId,
    List<Map<String, dynamic>> productSetups = const [],
    int? shipmentId,
  }) {
    Future(() async {
      try {
        final serverId = await _resolveTransferServerId(transferId);
        if (serverId == null) return;
        var transfer = await _local.findTransfer(transferId);
        if (transfer == null) return;

        final destServerId =
            await _local.resolveShopServerId(transfer.destinationShopId);
        final sourceServerId =
            await _local.resolveShopServerId(transfer.sourceShopId);
        if (destServerId == null && sourceServerId == null) return;

        await _apiGuard.ensureReady();

        Map<String, dynamic>? remoteDetail;
        if (sourceServerId != null) {
          try {
            remoteDetail = await ApiClient.runScopedToServerShop(
              sourceServerId,
              () => _remote.fetchTransfer(serverId),
            );
          } catch (_) {}
        }

        var receiveScopeId = remoteDetail != null
            ? StockTransferLocalDatasource.destinationServerIdFromRemote(
                remoteDetail,
              )
            : null;
        receiveScopeId ??= destServerId;

        if (remoteDetail == null && receiveScopeId != null) {
          try {
            remoteDetail = await ApiClient.runScopedToServerShop(
              receiveScopeId,
              () => _remote.fetchTransfer(serverId),
            );
          } catch (_) {}
        }

        receiveScopeId = remoteDetail != null
            ? StockTransferLocalDatasource.destinationServerIdFromRemote(
                  remoteDetail,
                ) ??
                receiveScopeId
            : receiveScopeId;
        if (receiveScopeId == null) return;

        if (remoteDetail != null) {
          await _local.reconcileTransferShopsFromRemote(transferId, remoteDetail);
          transfer = await _local.findTransfer(transferId);
          if (transfer == null) return;
        }

        final activeTransfer = transfer;
        await ApiClient.runScopedToServerShop(receiveScopeId, () async {
          Map<String, dynamic> remoteDetailFinal;
          try {
            remoteDetailFinal = remoteDetail ??
                await _remote.fetchTransfer(serverId);
          } catch (_) {
            return;
          }

          final remoteItems = (remoteDetailFinal['items'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];

          final mapping = await _local.buildRemoteItemMapping(
            transfer: activeTransfer,
            remoteItems: remoteItems,
          );
          if (mapping.isEmpty) return;

          final qtyMap = _local.resolveReceiveQuantitiesForSync(
            transfer: activeTransfer,
            payload: {
              if (quantitiesByItemId != null)
                'quantitiesByItemId':
                    quantitiesByItemId.map((k, v) => MapEntry('$k', v)),
            },
          );
          if (qtyMap.isEmpty &&
              (refusalsByItemId == null || refusalsByItemId.isEmpty)) {
            return;
          }

          final remoteShipments = (remoteDetailFinal['shipments'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          final remoteShipmentId = shipmentId != null
              ? _local.resolveRemoteShipmentId(
                  transfer: activeTransfer,
                  localShipmentId: shipmentId,
                  remoteShipments: remoteShipments,
                )
              : null;

          final body = StockTransferRemotePayloads.receiveBody(
            quantitiesByItemId: qtyMap,
            remoteItems: mapping,
            refusalsByItemId: refusalsByItemId ?? const {},
            productSetups: productSetups,
            shipmentId: remoteShipmentId,
          );

          final remote = await _remote.receiveTransfer(serverId, body);
          await _local.applyRemoteStockTransferSnapshot(transferId, remote);
        });
      } catch (_) {}
    });
  }

  void _pushTransferSubmitInBackground(int sourceShopId, int transferId) {
    Future(() async {
      try {
        final serverId = await _resolveTransferServerId(transferId);
        if (serverId == null) return;
        await _apiGuard.ensureReady();
        final remote = await _remote.submitTransfer(serverId);
        await _local.applyRemoteStockTransferSnapshot(transferId, remote);
      } catch (_) {}
    });
  }

  void _pushTransferApproveInBackground(int sourceShopId, int transferId) {
    Future(() async {
      try {
        final serverId = await _resolveTransferServerId(transferId);
        if (serverId == null) return;
        await _apiGuard.ensureReady();
        final remote = await _remote.approveTransfer(serverId);
        await _local.applyRemoteStockTransferSnapshot(transferId, remote);
      } catch (_) {}
    });
  }

  void _pushTransferCancelInBackground(int sourceShopId, int transferId) {
    Future(() async {
      try {
        final serverId = await _resolveTransferServerId(transferId);
        if (serverId == null) return;
        await _apiGuard.ensureReady();
        await _remote.cancelTransfer(serverId);
        await _local.applyRemoteStockTransferSnapshot(
          transferId,
          {'id': serverId, 'status': StockTransferStatus.cancelled},
        );
      } catch (_) {}
    });
  }

  void _pushTransferCloseInBackground({
    required int sourceShopId,
    required int transferId,
    String? notes,
  }) {
    Future(() async {
      try {
        final serverId = await _resolveTransferServerId(transferId);
        if (serverId == null) return;
        await _apiGuard.ensureReady();
        final remote = await _remote.closeTransfer(
          serverId,
          StockTransferRemotePayloads.closeBody(notes: notes),
        );
        await _local.applyRemoteStockTransferSnapshot(transferId, remote);
      } catch (_) {}
    });
  }

  void _pushTransferResolveDiscrepancyInBackground({
    required int sourceShopId,
    required int transferId,
    required int itemId,
    required int quantity,
    required String reason,
    required String resolution,
    String? notes,
  }) {
    Future(() async {
      try {
        final serverId = await _resolveTransferServerId(transferId);
        if (serverId == null) return;
        final transfer = await _local.findTransfer(transferId);
        if (transfer == null) return;
        await _apiGuard.ensureReady();
        final remoteDetail = await _remote.fetchTransfer(serverId);
        final remoteItems = (remoteDetail['items'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        final mapping = await _local.buildRemoteItemMapping(
          transfer: transfer,
          remoteItems: remoteItems,
        );
        final remoteItemId = mapping
            .where((row) => row['localItemId'] == itemId)
            .map((row) => row['remoteItemId'] as int?)
            .whereType<int>()
            .firstOrNull;
        if (remoteItemId == null) return;

        final remote = await _remote.resolveDiscrepancy(
          serverId,
          StockTransferRemotePayloads.resolveDiscrepancyBody(
            itemId: remoteItemId,
            quantity: quantity,
            reason: reason,
            resolution: resolution,
            notes: notes,
          ),
        );
        await _local.applyRemoteStockTransferSnapshot(transferId, remote);
      } catch (_) {}
    });
  }

  Future<int?> _resolveTransferServerId(int transferId) async {
    final serverId = await _local.findTransferServerId(transferId);
    return serverId != null ? int.tryParse(serverId) : null;
  }
}
