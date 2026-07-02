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
    int sortOrder = 0,
  }) {
    return record(
      shopId: shopId,
      entityTable: SyncEntityTable.categories,
      recordId: categoryId,
      operation: SyncOperation.create,
      payload: {'name': name, 'sortOrder': sortOrder},
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
}
