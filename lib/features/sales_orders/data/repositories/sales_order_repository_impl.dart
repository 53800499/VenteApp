import '../../../../app/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/notifications/notification_orchestrator.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/sync/sync_constants.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_pull_entity.dart';
import '../../../sales/domain/entities/sale_entities.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/repositories/sales_order_repository.dart';
import '../datasources/sales_order_local_datasource.dart';
import '../datasources/sales_order_remote_datasource.dart';

class SalesOrderRepositoryImpl implements SalesOrderRepository {
  SalesOrderRepositoryImpl({
    required SalesOrderLocalDatasource local,
    required SalesOrderRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
    required SyncPolicy syncPolicy,
    LocalWriteSyncRecorder? recorder,
    NotificationOrchestrator? notificationOrchestrator,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _syncPolicy = syncPolicy,
        _recorder = recorder,
        _notifications = notificationOrchestrator;

  final SalesOrderLocalDatasource _local;
  final SalesOrderRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;
  final SyncPolicy _syncPolicy;
  final LocalWriteSyncRecorder? _recorder;
  final NotificationOrchestrator? _notifications;

  Future<bool> _useQueue(int shopId) async =>
      (await _syncPolicy.resolve(shopId: shopId)).shouldUseSyncQueue;

  Map<String, dynamic> _versionPayload(SalesOrder order) => {
        'localId': order.id,
        'version': order.version,
        if (order.deviceId != null) 'deviceId': order.deviceId,
      };

  Future<void> _enqueue(
    int shopId, {
    required String operation,
    required int localId,
    Map<String, dynamic>? payload,
  }) async {
    final recorder = _recorder;
    if (recorder == null || !await _useQueue(shopId)) return;
    await recorder.record(
      shopId: shopId,
      entityTable: SyncEntityTable.salesOrders,
      recordId: localId,
      operation: operation,
      payload: payload ?? {'localId': localId},
    );
  }

  @override
  Future<List<SalesOrder>> listOrders({
    required int shopId,
    SalesOrderStatus? status,
    String? search,
  }) {
    return _local.listOrders(
      shopId: shopId,
      status: status,
      search: search,
    );
  }

  @override
  Future<SalesOrder?> findOrder({
    required int shopId,
    required int id,
  }) {
    return _local.findOrder(shopId: shopId, id: id);
  }

  @override
  Future<String> nextOrderNumber(int shopId) {
    return _local.nextOrderNumber(shopId);
  }

  @override
  Future<SalesOrder> createOrder({
    required int shopId,
    required int userId,
    required int customerId,
    required List<SalesOrderLineInput> items,
    String? notes,
  }) async {
    final number = await _local.nextOrderNumber(shopId);
    final order = await _local.createOrder(
      shopId: shopId,
      userId: userId,
      customerId: customerId,
      number: number,
      items: items,
      notes: notes,
    );
    await _enqueue(
      shopId,
      operation: 'create',
      localId: order.id,
      payload: {
        ..._versionPayload(order),
        'number': order.number,
        'customerId': customerId,
        'notes': notes,
        'orderedAt': order.orderedAt,
        'subtotal': order.subtotal,
        'total': order.total,
        'items': order.items
            .map(
              (i) => {
                'productId': i.productId,
                'quantityOrdered': i.quantityOrdered,
                'unitPrice': i.unitPrice,
                'lineTotal': i.lineTotal,
              },
            )
            .toList(),
      },
    );
    await _tryPushCreate(order);
    return order;
  }

  Future<void> _tryPushCreate(SalesOrder order) async {
    if (await _useQueue(order.shopId)) return;
    try {
      await _apiGuard.ensureReady();
      final remote = await _remote.createOrder({
        'localId': order.id,
        'number': order.number,
        'customerId': order.customerId,
        'notes': order.notes,
        'orderedAt': order.orderedAt,
        'subtotal': order.subtotal,
        'total': order.total,
        'version': order.version,
        if (order.deviceId != null) 'deviceId': order.deviceId,
        'items': order.items
            .map(
              (i) => {
                'productId': i.productId,
                'quantityOrdered': i.quantityOrdered,
                'unitPrice': i.unitPrice,
                'lineTotal': i.lineTotal,
              },
            )
            .toList(),
      });
      await _local.applyRemoteSalesOrderSnapshot(
        order.shopId,
        order.id,
        Map<String, dynamic>.from(remote),
      );
    } on Failure {
      // Offline / API : reste local pending.
    } catch (_) {}
  }

  @override
  Future<SalesOrder> updateDraft({
    required int shopId,
    required int userId,
    required int orderId,
    int? customerId,
    List<SalesOrderLineInput>? items,
    String? notes,
  }) async {
    final order = await _local.updateDraft(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
      customerId: customerId,
      items: items,
      notes: notes,
    );
    await _enqueue(
      shopId,
      operation: 'update',
      localId: orderId,
      payload: _versionPayload(order),
    );
    return order;
  }

  @override
  Future<SalesOrder> confirmOrder({
    required int shopId,
    required int userId,
    required int orderId,
  }) async {
    final order = await _local.confirmOrder(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
    );
    await _enqueue(
      shopId,
      operation: 'confirm',
      localId: orderId,
      payload: _versionPayload(order),
    );
    return order;
  }

  @override
  Future<SalesOrder> markPreparing({
    required int shopId,
    required int userId,
    required int orderId,
  }) async {
    final order = await _local.markPreparing(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
    );
    await _enqueue(
      shopId,
      operation: 'preparing',
      localId: orderId,
      payload: _versionPayload(order),
    );
    return order;
  }

  @override
  Future<SalesOrder> cancelOrder({
    required int shopId,
    required int userId,
    required int orderId,
    String? reason,
  }) async {
    final order = await _local.cancelOrder(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
      reason: reason,
    );
    await _enqueue(
      shopId,
      operation: 'cancel',
      localId: orderId,
      payload: {
        ..._versionPayload(order),
        'reason': reason,
      },
    );
    return order;
  }

  @override
  Future<SalesOrder> closeOrder({
    required int shopId,
    required int userId,
    required int orderId,
  }) async {
    final order = await _local.closeOrder(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
    );
    await _enqueue(
      shopId,
      operation: 'close',
      localId: orderId,
      payload: _versionPayload(order),
    );
    return order;
  }

  @override
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
    final result = await _local.deliver(
      shopId: shopId,
      userId: userId,
      orderId: orderId,
      lines: lines,
      paymentMethod: paymentMethod,
      notes: notes,
      driverName: driverName,
      vehiclePlate: vehiclePlate,
      remainingReason: remainingReason,
      amountCash: amountCash,
      amountMomo: amountMomo,
      amountCredit: amountCredit,
    );
    final delivery = result.delivery;
    final saleId = delivery.saleId;
    if (saleId != null) {
      await _recorder?.recordSaleStandard(shopId: shopId, saleId: saleId);
    }
    for (final loss in result.stockLosses) {
      await _recorder?.recordStockAdjust(
        shopId: shopId,
        productId: loss.productId,
        payload: {
          'type': 'loss',
          'quantityChange': -loss.quantity,
          'reason': loss.reason,
        },
      );
    }

    final order = await _local.findOrder(shopId: shopId, id: orderId);
    await _enqueue(
      shopId,
      operation: 'deliver',
      localId: orderId,
      payload: {
        if (order != null) ..._versionPayload(order),
        'deliveryId': delivery.id,
        'deliveryNumber': delivery.number,
        'saleId': delivery.saleId,
        'notes': delivery.notes,
        'driverName': delivery.driverName,
        'vehiclePlate': delivery.vehiclePlate,
        'remainingReason': delivery.remainingReason?.code,
        'items': delivery.items
            .map(
              (i) => {
                'salesOrderItemId': i.salesOrderItemId,
                'productId': i.productId,
                'quantitySent': i.quantitySent,
                'quantityAccepted': i.quantityAccepted,
                'quantityRefused': i.quantityRefused,
                'quantityReplaced': i.quantityReplaced,
                'refusalReason': i.refusalReason?.code,
                'refusalDestination': i.refusalDestination?.code,
                'replacementProductId': i.replacementProductId,
                'replacementUnitPrice': i.replacementUnitPrice,
                'unitPrice': i.unitPrice,
              },
            )
            .toList(),
      },
    );

    if (order != null) {
      NotificationOrchestrator? orch = _notifications;
      if (orch == null && sl.isRegistered<NotificationOrchestrator>()) {
        orch = sl<NotificationOrchestrator>();
      }
      await orch?.showSalesOrderDelivered(
        orderNumber: order.number,
        orderId: order.id,
        partial: order.totalRemaining > 0,
      );
    }

    return result;
  }

  @override
  Future<SalesOrderFulfillmentReport> fulfillmentReport({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) {
    return _local.fulfillmentReport(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
  }

  @override
  Future<void> syncFromRemote({
    required int shopId,
    bool force = false,
    int? importUserId,
  }) async {
    if (!await _syncPolicy.shouldPullEntity(
      shopId: shopId,
      entity: SyncPullEntity.salesOrders,
      force: force,
    )) {
      return;
    }

    await _apiGuard.ensureReady();

    final updatedAfter = force
        ? null
        : await _syncPolicy.entityUpdatedAfterCursor(
            shopId: shopId,
            entity: SyncPullEntity.salesOrders,
          );

    final remoteOrders = await _remote.listOrders(updatedAfter: updatedAfter);
    final userId =
        importUserId ?? await _local.resolveFallbackUserId(shopId);

    for (final raw in remoteOrders) {
      await _local.upsertOrderFromRemote(
        shopId: shopId,
        remote: raw,
        importUserId: userId,
        force: false,
      );
    }

    await _syncPolicy.markEntitySynced(
      shopId: shopId,
      entity: SyncPullEntity.salesOrders,
    );
  }

  @override
  Future<SalesOrder?> refreshOrderFromRemote({
    required int shopId,
    required int orderId,
    int? importUserId,
  }) async {
    final local = await _local.findOrder(shopId: shopId, id: orderId);
    if (local?.serverId == null || local!.serverId!.isEmpty) {
      return local;
    }

    try {
      await _apiGuard.ensureReady();
      final remote = await _remote.getOrder(local.serverId!);
      await _local.upsertOrderFromRemote(
        shopId: shopId,
        remote: remote,
        importUserId: importUserId ?? local.createdBy,
        force: true,
      );
      return _local.findOrder(shopId: shopId, id: orderId);
    } on Failure {
      return local;
    } catch (_) {
      return local;
    }
  }
}
