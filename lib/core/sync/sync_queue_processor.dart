import 'dart:convert';

import '../../features/customers/data/datasources/local/customers_local_datasource.dart';
import '../../features/customers/data/datasources/remote/customers_remote_datasource.dart';
import '../../features/debts/data/datasources/local/debts_local_datasource.dart';
import '../../features/debts/data/datasources/remote/debts_remote_datasource.dart';
import '../../features/inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../features/inventory/data/datasources/remote/inventory_remote_datasource.dart';
import '../../features/sales/data/datasources/local/sales_local_datasource.dart';
import '../../features/sales/data/datasources/remote/sales_remote_datasource.dart';
import '../../features/sales/data/models/sale_api_models.dart';
import '../../features/sales/domain/entities/sale_entities.dart';
import '../database/app_database.dart' hide Sale;
import '../errors/failures.dart';
import '../network/remote_api_guard.dart';
import 'sync_constants.dart';
import 'sync_queue_datasource.dart';

/// Pousse les éléments `sync_queue` vers l'API (couche 2 → 3).
class SyncQueueProcessor {
  SyncQueueProcessor({
    required SyncQueueDatasource queue,
    required RemoteApiGuard apiGuard,
    required CustomersLocalDatasource customersLocal,
    required CustomersRemoteDatasource customersRemote,
    required InventoryLocalDatasource inventoryLocal,
    required InventoryRemoteDatasource inventoryRemote,
    required SalesLocalDatasource salesLocal,
    required SalesRemoteDatasource salesRemote,
    required DebtsLocalDatasource debtsLocal,
    required DebtsRemoteDatasource debtsRemote,
  })  : _queue = queue,
        _apiGuard = apiGuard,
        _customersLocal = customersLocal,
        _customersRemote = customersRemote,
        _inventoryLocal = inventoryLocal,
        _inventoryRemote = inventoryRemote,
        _salesLocal = salesLocal,
        _salesRemote = salesRemote,
        _debtsLocal = debtsLocal,
        _debtsRemote = debtsRemote;

  final SyncQueueDatasource _queue;
  final RemoteApiGuard _apiGuard;
  final CustomersLocalDatasource _customersLocal;
  final CustomersRemoteDatasource _customersRemote;
  final InventoryLocalDatasource _inventoryLocal;
  final InventoryRemoteDatasource _inventoryRemote;
  final SalesLocalDatasource _salesLocal;
  final SalesRemoteDatasource _salesRemote;
  final DebtsLocalDatasource _debtsLocal;
  final DebtsRemoteDatasource _debtsRemote;

  Future<SyncQueueProcessResult> process({required int shopId}) async {
    await _apiGuard.ensureReady();

    var processed = 0;
    var deferred = 0;
    var conflicts = 0;

    while (true) {
      final batch = await _queue.fetchPending(shopId: shopId);
      if (batch.isEmpty) break;

      final sorted = List<SyncQueueData>.from(batch)
        ..sort((a, b) {
          final priority = _entityPriority(a.entityTable)
              .compareTo(_entityPriority(b.entityTable));
          if (priority != 0) return priority;
          return a.createdAt.compareTo(b.createdAt);
        });

      for (final item in sorted) {
        try {
          final done = await _processItem(shopId: shopId, item: item);
          if (done) {
            await _queue.markProcessed(item.id);
            processed++;
          } else {
            deferred++;
          }
        } on ConflictFailure catch (error) {
          await _queue.markConflict(item.id, error.message);
          conflicts++;
        } on Failure catch (error) {
          await _queue.markFailed(item.id, error.message);
        } catch (error) {
          await _queue.markFailed(item.id, error.toString());
        }
      }

      if (batch.length < 25) break;
    }

    return SyncQueueProcessResult(
      processed: processed,
      deferred: deferred,
      conflicts: conflicts,
    );
  }

  static int _entityPriority(String table) => switch (table) {
        SyncEntityTable.customers => 0,
        SyncEntityTable.categories => 1,
        SyncEntityTable.products => 2,
        SyncEntityTable.sales => 3,
        SyncEntityTable.debts => 4,
        _ => 99,
      };

  Future<bool> _processItem({
    required int shopId,
    required SyncQueueData item,
  }) async {
    final payload = _decodePayload(item.payload);

    switch (item.entityTable) {
      case SyncEntityTable.customers:
        return _processCustomer(shopId, item, payload);
      case SyncEntityTable.categories:
        return _processCategory(shopId, item, payload);
      case SyncEntityTable.products:
        return _processProduct(shopId, item, payload);
      case SyncEntityTable.sales:
        return _processSale(shopId, item, payload);
      case SyncEntityTable.debts:
        return _processDebt(shopId, item, payload);
      default:
        await _queue.markFailed(item.id, 'Table inconnue : ${item.entityTable}');
        return true;
    }
  }

  Map<String, dynamic> _decodePayload(String raw) {
    if (raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  Future<bool> _processCustomer(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final customer = await _customersLocal.findCustomer(shopId, item.recordId);
    if (customer == null) return true;

    switch (item.operation) {
      case SyncOperation.create:
        if (customer.serverId != null) return true;
        final remote = await _customersRemote.createCustomer(
          name: payload['name'] as String? ?? customer.name,
          phone: payload['phone'] as String? ?? customer.phone,
          address: payload['address'] as String? ?? customer.address,
          note: payload['note'] as String? ?? customer.note,
          isShared: payload['isShared'] as bool? ?? customer.isShared,
        );
        await _customersLocal.updateServerSync(
          customerId: customer.id,
          serverId: '${remote.id}',
        );
        return true;

      case SyncOperation.update:
        if (customer.serverId == null) return false;
        await _customersRemote.updateCustomer(
          int.parse(customer.serverId!),
          name: payload['name'] as String?,
          phone: payload.containsKey('phone') ? payload['phone'] as String? : null,
          address:
              payload.containsKey('address') ? payload['address'] as String? : null,
          note: payload.containsKey('note') ? payload['note'] as String? : null,
          isShared: payload.containsKey('isShared')
              ? payload['isShared'] as bool?
              : null,
        );
        return true;

      case SyncOperation.archive:
        if (customer.serverId == null) return false;
        await _customersRemote.archiveCustomer(int.parse(customer.serverId!));
        return true;

      default:
        throw ValidationFailure('Opération client inconnue : ${item.operation}');
    }
  }

  Future<bool> _processCategory(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final category = await _inventoryLocal.findCategory(shopId, item.recordId);
    if (category == null) return true;

    switch (item.operation) {
      case SyncOperation.create:
        await _inventoryRemote.createCategory(
          name: payload['name'] as String? ?? category.name,
          sortOrder: payload['sortOrder'] as int? ?? category.sortOrder,
        );
        return true;

      case SyncOperation.update:
        final remoteCategories = await _inventoryRemote.listCategories();
        final match = remoteCategories
            .where((c) => c.name.toLowerCase() == category.name.toLowerCase())
            .firstOrNull;
        if (match == null) return false;
        await _inventoryRemote.updateCategory(
          match.id,
          name: payload['name'] as String?,
          isActive: payload['isActive'] as bool?,
          sortOrder: payload['sortOrder'] as int?,
        );
        return true;

      default:
        throw ValidationFailure(
          'Opération catégorie inconnue : ${item.operation}',
        );
    }
  }

  Future<bool> _processProduct(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final product = await _inventoryLocal.findProduct(shopId, item.recordId);
    if (product == null) return true;

    switch (item.operation) {
      case SyncOperation.create:
        if (product.serverId != null) return true;
        final categoryId = await _resolveCategoryServerId(
          shopId,
          payload['localCategoryId'] as int? ?? product.categoryId,
        );
        if (categoryId == null) return false;

        final remote = await _inventoryRemote.createProduct({
          'name': payload['name'] ?? product.name,
          'categoryId': categoryId,
          if (payload['sku'] != null || product.sku != null)
            'sku': payload['sku'] ?? product.sku,
          'priceSell': payload['priceSell'] ?? product.priceSell,
          if (payload['priceBuy'] != null || product.priceBuy != null)
            'priceBuy': payload['priceBuy'] ?? product.priceBuy,
          'initialQuantity': payload['initialQuantity'] ?? product.quantityInStock,
          if (payload['alertThreshold'] != null || product.alertThreshold != null)
            'alertThreshold': payload['alertThreshold'] ?? product.alertThreshold,
        });
        await _inventoryLocal.updateProductServerSync(
          productId: product.id,
          serverId: '${remote.id}',
        );
        return true;

      case SyncOperation.update:
        if (product.serverId == null) return false;
        final body = <String, dynamic>{};
        for (final key in ['name', 'sku', 'priceSell', 'priceBuy', 'alertThreshold']) {
          if (payload.containsKey(key)) body[key] = payload[key];
        }
        if (payload.containsKey('localCategoryId')) {
          final serverCategoryId = await _resolveCategoryServerId(
            shopId,
            payload['localCategoryId'] as int?,
          );
          if (serverCategoryId != null) body['categoryId'] = serverCategoryId;
        }
        if (body.isEmpty) return true;
        await _inventoryRemote.updateProduct(
          int.parse(product.serverId!),
          body,
        );
        return true;

      case SyncOperation.archive:
        if (product.serverId == null) return false;
        await _inventoryRemote.archiveProduct(int.parse(product.serverId!));
        return true;

      case SyncOperation.stockAdjust:
        if (product.serverId == null) return false;
        await _inventoryRemote.adjustStock(
          int.parse(product.serverId!),
          Map<String, dynamic>.from(payload),
        );
        return true;

      default:
        throw ValidationFailure(
          'Opération produit inconnue : ${item.operation}',
        );
    }
  }

  Future<bool> _processSale(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final sale = await _salesLocal.findSale(shopId, item.recordId);
    if (sale == null) return true;

    switch (item.operation) {
      case SyncOperation.create:
        final serverId = await _salesLocal.findSaleServerId(shopId, sale.id);
        if (serverId != null) return true;
        final request = await _buildStandardSaleRequest(shopId, sale);
        if (request == null) return false;
        final remote = await _salesRemote.createStandardSale(request);
        await _salesLocal.markSaleSynced(
          saleId: sale.id,
          serverId: '${remote.id}',
        );
        return true;

      case SyncOperation.saleQuick:
        final quickServerId = await _salesLocal.findSaleServerId(shopId, sale.id);
        if (quickServerId != null) return true;
        final remote = await _salesRemote.createQuickSale({
          'totalAmount': payload['totalAmount'] ?? sale.totalAmount,
          'payment': payload['payment'],
          if (payload['note'] != null) 'note': payload['note'],
        });
        await _salesLocal.markSaleSynced(
          saleId: sale.id,
          serverId: '${remote.id}',
        );
        return true;

      case SyncOperation.cancel:
        final cancelServerId = await _salesLocal.findSaleServerId(shopId, sale.id);
        if (cancelServerId == null) return false;
        await _salesRemote.cancelSale(
          int.parse(cancelServerId),
          reason: payload['reason'] as String? ?? sale.cancelReason ?? '',
        );
        return true;

      default:
        throw ValidationFailure('Opération vente inconnue : ${item.operation}');
    }
  }

  Future<bool> _processDebt(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final debt = await _debtsLocal.findDebt(shopId, item.recordId);
    if (debt == null) return true;

    if (item.operation == SyncOperation.payment) {
      if (debt.serverId == null) return false;

      await _debtsRemote.recordPayment(
        int.parse(debt.serverId!),
        amount: payload['amount'] as int,
        method: payload['method'] as String,
        reference: payload['reference'] as String?,
        amountTendered: payload['amountTendered'] as int?,
        note: payload['note'] as String?,
      );
      return true;
    }

    if (item.operation == SyncOperation.forgive) {
      if (debt.serverId == null) return false;

      await _debtsRemote.forgiveDebt(
        int.parse(debt.serverId!),
        reason: payload['reason'] as String? ?? '',
      );
      return true;
    }

    throw ValidationFailure('Opération dette inconnue : ${item.operation}');
  }

  Future<int?> _resolveCategoryServerId(int shopId, int? localCategoryId) async {
    if (localCategoryId == null) return null;
    final category = await _inventoryLocal.findCategory(shopId, localCategoryId);
    if (category == null) return null;

    final remoteCategories = await _inventoryRemote.listCategories();
    final match = remoteCategories
        .where((c) => c.name.toLowerCase() == category.name.toLowerCase())
        .firstOrNull;
    return match?.id;
  }

  Future<CreateStandardSaleApiRequest?> _buildStandardSaleRequest(
    int shopId,
    Sale sale,
  ) async {
    final lines = <SaleLineApiRequest>[];
    for (final item in sale.items) {
      final productId = item.productId;
      if (productId == null) continue;
      final product = await _salesLocal.findProduct(shopId, productId);
      final serverProductId = int.tryParse(product?.serverId ?? '');
      if (serverProductId == null) return null;

      lines.add(
        SaleLineApiRequest(
          productId: serverProductId,
          quantity: item.quantity.round(),
          unitPrice: item.unitPrice,
          lineDiscountAmount: item.discountAmount,
        ),
      );
    }

    if (lines.isEmpty) return null;

    int? remoteCustomerId;
    if (sale.customerId != null) {
      final customer = await _salesLocal.findCustomer(shopId, sale.customerId!);
      remoteCustomerId = int.tryParse(customer?.serverId ?? '');
      if (sale.amountCredit > 0 && remoteCustomerId == null) return null;
    }

    return CreateStandardSaleApiRequest(
      items: lines,
      discountAmount: sale.discountAmount,
      customerId: remoteCustomerId,
      payment: SalePaymentApiRequest(
        method: sale.paymentMethod,
        amountCash: sale.amountCash,
        amountMomo: sale.amountMomo,
        amountCredit: sale.amountCredit,
      ),
      note: sale.note,
    );
  }
}

class SyncQueueProcessResult {
  const SyncQueueProcessResult({
    required this.processed,
    required this.deferred,
    required this.conflicts,
  });

  final int processed;
  final int deferred;
  final int conflicts;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
