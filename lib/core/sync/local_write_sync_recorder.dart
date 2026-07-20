import 'dart:convert';

import 'sync_constants.dart';
import 'sync_policy.dart';
import 'sync_queue_datasource.dart';

typedef SyncScheduleCallback = void Function(int shopId);

/// Enregistre les écritures locales dans `sync_queue` (V2/V3).
class LocalWriteSyncRecorder {
  LocalWriteSyncRecorder({
    required SyncPolicy policy,
    required SyncQueueDatasource queue,
    SyncScheduleCallback? onEnqueued,
  })  : _policy = policy,
        _queue = queue,
        _onEnqueued = onEnqueued;

  final SyncPolicy _policy;
  final SyncQueueDatasource _queue;
  final SyncScheduleCallback? _onEnqueued;

  Future<void> record({
    required int shopId,
    required String entityTable,
    required int recordId,
    required String operation,
    required Map<String, dynamic> payload,
    int localVersion = 1,
  }) async {
    final context = await _policy.resolve(shopId: shopId);
    if (!context.shouldUseSyncQueue) return;

    await _queue.enqueue(
      shopId: shopId,
      tableName: entityTable,
      recordId: recordId,
      operation: operation,
      payload: jsonEncode(payload),
      localVersion: localVersion,
      context: context,
    );
    await _policy.invalidateEntitiesForWrite(
      shopId: shopId,
      entityTable: entityTable,
      recordId: recordId,
    );
    _onEnqueued?.call(shopId);
  }

  Future<void> recordCustomerCreate({
    required int shopId,
    required int customerId,
    required String name,
    String? phone,
    String? address,
    String? note,
    bool isShared = false,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.customers,
      recordId: customerId,
      operation: SyncOperation.create,
      payload: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
        if (note != null && note.isNotEmpty) 'note': note,
        'isShared': isShared,
      },
    );
  }

  Future<void> recordCustomerUpdate({
    required int shopId,
    required int customerId,
    required Map<String, dynamic> fields,
    int version = 1,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.customers,
      recordId: customerId,
      operation: SyncOperation.update,
      payload: fields,
      localVersion: version,
    );
  }

  Future<void> recordCustomerArchive({
    required int shopId,
    required int customerId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.customers,
      recordId: customerId,
      operation: SyncOperation.archive,
      payload: const {},
    );
  }

  Future<void> recordCategoryCreate({
    required int shopId,
    required int categoryId,
    required String name,
    String? description,
    int sortOrder = 0,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.categories,
      recordId: categoryId,
      operation: SyncOperation.create,
      payload: {
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'sortOrder': sortOrder,
      },
    );
  }

  Future<void> recordCategoryUpdate({
    required int shopId,
    required int categoryId,
    required Map<String, dynamic> fields,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.categories,
      recordId: categoryId,
      operation: SyncOperation.update,
      payload: fields,
    );
  }

  Future<void> recordProductCreate({
    required int shopId,
    required int productId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.products,
      recordId: productId,
      operation: SyncOperation.create,
      payload: payload,
    );
  }

  Future<void> recordProductUpdate({
    required int shopId,
    required int productId,
    required Map<String, dynamic> fields,
    int version = 1,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.products,
      recordId: productId,
      operation: SyncOperation.update,
      payload: fields,
      localVersion: version,
    );
  }

  Future<void> recordProductArchive({
    required int shopId,
    required int productId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.products,
      recordId: productId,
      operation: SyncOperation.archive,
      payload: const {},
    );
  }

  Future<void> recordStockAdjust({
    required int shopId,
    required int productId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.products,
      recordId: productId,
      operation: SyncOperation.stockAdjust,
      payload: payload,
    );
  }

  Future<void> recordSaleStandard({
    required int shopId,
    required int saleId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.sales,
      recordId: saleId,
      operation: SyncOperation.create,
      payload: {'saleType': 'standard'},
    );
  }

  Future<void> recordSaleQuick({
    required int shopId,
    required int saleId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.sales,
      recordId: saleId,
      operation: SyncOperation.saleQuick,
      payload: payload,
    );
  }

  Future<void> recordSaleCancel({
    required int shopId,
    required int saleId,
    required String reason,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.sales,
      recordId: saleId,
      operation: SyncOperation.cancel,
      payload: {'reason': reason},
    );
  }

  Future<void> recordDebtPayment({
    required int shopId,
    required int debtId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.debts,
      recordId: debtId,
      operation: SyncOperation.payment,
      payload: payload,
    );
  }

  Future<void> recordDebtForgive({
    required int shopId,
    required int debtId,
    required String reason,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.debts,
      recordId: debtId,
      operation: SyncOperation.forgive,
      payload: {'reason': reason},
    );
  }

  Future<void> recordExpenseCreate({
    required int shopId,
    required int localId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.expenses,
      recordId: localId,
      operation: SyncOperation.create,
      payload: const {},
    );
  }

  Future<void> recordExpenseUpdate({
    required int shopId,
    required int localId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.expenses,
      recordId: localId,
      operation: SyncOperation.update,
      payload: const {},
    );
  }

  Future<void> recordCashSessionOpen({
    required int shopId,
    required int sessionId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.cashSessions,
      recordId: sessionId,
      operation: SyncOperation.cashSessionOpen,
      payload: const {},
    );
  }

  Future<void> recordCashSessionClose({
    required int shopId,
    required int sessionId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.cashSessions,
      recordId: sessionId,
      operation: SyncOperation.cashSessionClose,
      payload: payload,
    );
  }

  Future<void> recordCashMovement({
    required int shopId,
    required int movementId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.cashMovements,
      recordId: movementId,
      operation: SyncOperation.cashMovementCreate,
      payload: payload,
    );
  }

  Future<void> recordSupplierCreate({
    required int shopId,
    required int supplierId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.suppliers,
      recordId: supplierId,
      operation: SyncOperation.create,
      payload: payload,
    );
  }

  Future<void> recordSupplierUpdate({
    required int shopId,
    required int supplierId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.suppliers,
      recordId: supplierId,
      operation: SyncOperation.update,
      payload: payload,
    );
  }

  Future<void> recordPurchaseOrderCreate({
    required int shopId,
    required int poId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.purchaseOrders,
      recordId: poId,
      operation: SyncOperation.create,
      payload: payload,
    );
  }

  Future<void> recordPurchaseOrderUpdate({
    required int shopId,
    required int poId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.purchaseOrders,
      recordId: poId,
      operation: SyncOperation.update,
      payload: payload,
    );
  }

  Future<void> recordPurchaseOrderValidate({
    required int shopId,
    required int poId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.purchaseOrders,
      recordId: poId,
      operation: SyncOperation.validate,
      payload: const {},
    );
  }

  Future<void> recordPurchaseOrderSend({
    required int shopId,
    required int poId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.purchaseOrders,
      recordId: poId,
      operation: SyncOperation.send,
      payload: const {},
    );
  }

  Future<void> recordPurchaseOrderCancel({
    required int shopId,
    required int poId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.purchaseOrders,
      recordId: poId,
      operation: SyncOperation.cancel,
      payload: payload,
    );
  }

  Future<void> recordPurchaseOrderReceive({
    required int shopId,
    required int poId,
    required int receiptId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.purchaseReceipts,
      recordId: receiptId,
      operation: SyncOperation.receive,
      payload: {
        'purchaseOrderId': poId,
        ...payload,
      },
    );
  }

  Future<void> recordDirectGoodsReceipt({
    required int shopId,
    required int receiptId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.purchaseReceipts,
      recordId: receiptId,
      operation: SyncOperation.receive,
      payload: payload,
    );
  }

  Future<void> recordSupplierInvoiceCreate({
    required int shopId,
    required int invoiceId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.supplierInvoices,
      recordId: invoiceId,
      operation: SyncOperation.create,
      payload: payload,
    );
  }

  Future<void> recordSupplierPaymentCreate({
    required int shopId,
    required int invoiceId,
    required int paymentId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.supplierPayments,
      recordId: paymentId,
      operation: SyncOperation.create,
      payload: {
        'invoiceId': invoiceId,
        ...payload,
      },
    );
  }

  Future<void> recordStockTransferCreate({
    required int shopId,
    required int transferId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.create,
      payload: payload,
    );
  }

  Future<void> recordStockTransferValidate({
    required int shopId,
    required int transferId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.validate,
      payload: const {},
    );
  }

  Future<void> recordStockTransferSubmit({
    required int shopId,
    required int transferId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.submit,
      payload: const {},
    );
  }

  Future<void> recordStockTransferApprove({
    required int shopId,
    required int transferId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.approve,
      payload: const {},
    );
  }

  Future<void> recordStockTransferShip({
    required int shopId,
    required int transferId,
    Map<String, dynamic> payload = const {},
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.send,
      payload: payload,
    );
  }

  Future<void> recordStockTransferReceive({
    required int shopId,
    required int transferId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.receive,
      payload: payload,
    );
  }

  Future<void> recordStockTransferCancel({
    required int shopId,
    required int transferId,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.cancel,
      payload: const {},
    );
  }

  Future<void> recordStockTransferClose({
    required int shopId,
    required int transferId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.close,
      payload: payload,
    );
  }

  Future<void> recordStockTransferResolveDiscrepancy({
    required int shopId,
    required int transferId,
    required Map<String, dynamic> payload,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.stockTransfers,
      recordId: transferId,
      operation: SyncOperation.resolveDiscrepancy,
      payload: payload,
    );
  }
}
