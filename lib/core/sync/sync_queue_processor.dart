import 'dart:convert';

import '../../features/customers/data/datasources/local/customers_local_datasource.dart';
import '../../features/customers/data/datasources/remote/customers_remote_datasource.dart';
import '../../features/debts/data/datasources/local/debts_local_datasource.dart';
import '../../features/debts/data/datasources/remote/debts_remote_datasource.dart';
import '../../features/expenses/data/datasources/local/expenses_local_datasource.dart';
import '../../features/expenses/data/datasources/remote/expenses_remote_datasource.dart';
import '../../features/expenses/domain/entities/expense_entities.dart';
import '../../features/cash_sessions/data/datasources/local/cash_sessions_local_datasource.dart';
import '../../features/cash_sessions/data/datasources/remote/cash_sessions_remote_datasource.dart';
import '../../features/cash_sessions/data/models/cash_session_api_models.dart';
import '../../features/inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../features/inventory/data/datasources/remote/inventory_remote_datasource.dart';
import '../../features/sales/data/datasources/local/sales_local_datasource.dart';
import '../../features/sales/data/datasources/remote/sales_remote_datasource.dart';
import '../../features/sales/data/models/sale_api_models.dart';
import '../../features/sales/domain/entities/sale_entities.dart';
import '../database/app_database.dart'
    hide
        Sale,
        Expense,
        Supplier,
        PurchaseOrder,
        PurchaseOrderItem,
        PurchaseReceipt,
        PurchaseReceiptItem,
        SupplierInvoice,
        SupplierPayment,
        StockTransfer;
import '../errors/failures.dart';
import '../network/api_client.dart';
import '../network/remote_api_guard.dart';
import 'sync_constants.dart';
import 'sync_queue_datasource.dart';
import '../../features/calculators/data/datasources/local/calculators_local_datasource.dart';
import '../../features/calculators/data/datasources/remote/calculators_remote_datasource.dart';
import '../../features/procurement/data/datasources/procurement_local_datasource.dart';
import '../../features/procurement/data/datasources/procurement_remote_datasource.dart';
import '../../features/procurement/data/utils/procurement_remote_payloads.dart';
import '../../features/procurement/domain/entities/procurement.dart';
import '../../features/stock_transfer/data/datasources/stock_transfer_local_datasource.dart';
import '../../features/stock_transfer/data/datasources/stock_transfer_remote_datasource.dart';
import '../../features/stock_transfer/data/utils/stock_transfer_cloud_sync_helper.dart';
import '../../features/stock_transfer/data/utils/stock_transfer_remote_payloads.dart';
import '../../features/stock_transfer/domain/entities/stock_transfer.dart';
import '../../features/fx_exchange/data/datasources/local/fx_exchange_local_datasource.dart';
import '../../features/fx_exchange/data/datasources/remote/fx_exchange_remote_datasource.dart';
import '../../features/fx_exchange/data/models/fx_exchange_api_models.dart';
import '../../features/fx_exchange/domain/entities/fx_exchange_entities.dart';

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
    required ExpensesLocalDatasource expensesLocal,
    required ExpensesRemoteDatasource expensesRemote,
    required CashSessionsLocalDatasource cashSessionsLocal,
    required CashSessionsRemoteDatasource cashSessionsRemote,
    required CalculatorsLocalDatasource calculatorsLocal,
    required CalculatorsRemoteDatasource calculatorsRemote,
    required ProcurementLocalDatasource procurementLocal,
    required ProcurementRemoteDatasource procurementRemote,
    required StockTransferLocalDatasource stockTransferLocal,
    required StockTransferRemoteDatasource stockTransferRemote,
    required FxExchangeLocalDatasource fxExchangeLocal,
    required FxExchangeRemoteDatasource fxExchangeRemote,
  })  : _queue = queue,
        _apiGuard = apiGuard,
        _customersLocal = customersLocal,
        _customersRemote = customersRemote,
        _inventoryLocal = inventoryLocal,
        _inventoryRemote = inventoryRemote,
        _salesLocal = salesLocal,
        _salesRemote = salesRemote,
        _debtsLocal = debtsLocal,
        _debtsRemote = debtsRemote,
        _expensesLocal = expensesLocal,
        _expensesRemote = expensesRemote,
        _cashSessionsLocal = cashSessionsLocal,
        _cashSessionsRemote = cashSessionsRemote,
        _calculatorsLocal = calculatorsLocal,
        _calculatorsRemote = calculatorsRemote,
        _procurementLocal = procurementLocal,
        _procurementRemote = procurementRemote,
        _stockTransferLocal = stockTransferLocal,
        _stockTransferRemote = stockTransferRemote,
        _fxExchangeLocal = fxExchangeLocal,
        _fxExchangeRemote = fxExchangeRemote;

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
  final ExpensesLocalDatasource _expensesLocal;
  final ExpensesRemoteDatasource _expensesRemote;
  final CashSessionsLocalDatasource _cashSessionsLocal;
  final CashSessionsRemoteDatasource _cashSessionsRemote;
  final CalculatorsLocalDatasource _calculatorsLocal;
  final CalculatorsRemoteDatasource _calculatorsRemote;
  final ProcurementLocalDatasource _procurementLocal;
  final ProcurementRemoteDatasource _procurementRemote;
  final StockTransferLocalDatasource _stockTransferLocal;
  final StockTransferRemoteDatasource _stockTransferRemote;
  final FxExchangeLocalDatasource _fxExchangeLocal;
  final FxExchangeRemoteDatasource _fxExchangeRemote;

  StockTransferCloudSyncHelper get _stockTransferCloudSync =>
      StockTransferCloudSyncHelper(
        local: _stockTransferLocal,
        remote: _stockTransferRemote,
      );

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
          final opPriority = _operationPriority(a.operation)
              .compareTo(_operationPriority(b.operation));
          if (opPriority != 0) return opPriority;
          return a.createdAt.compareTo(b.createdAt);
        });

      // Groupes par priorité d'entité : parallèle limité à l'intérieur,
      // séquentiel entre groupes (clients → produits → ventes…).
      final groups = <int, List<SyncQueueData>>{};
      for (final item in sorted) {
        final key = _entityPriority(item.entityTable);
        groups.putIfAbsent(key, () => []).add(item);
      }
      final orderedKeys = groups.keys.toList()..sort();

      for (final key in orderedKeys) {
        final group = groups[key]!;
        // Concurrence entre enregistrements distincts uniquement :
        // create → validate → send d'un même record restent séquentiels.
        final byRecord = <String, List<SyncQueueData>>{};
        for (final item in group) {
          final recordKey = '${item.entityTable}:${item.recordId}';
          byRecord.putIfAbsent(recordKey, () => []).add(item);
        }
        final chains = byRecord.values.toList();

        final chainResults = await _mapWithConcurrency<
            List<SyncQueueData>, List<_QueueItemOutcome>>(
          chains,
          maxConcurrent: 3,
          mapper: (chain) async {
            final outcomes = <_QueueItemOutcome>[];
            for (final item in chain) {
              try {
                final done = await _processItem(shopId: shopId, item: item);
                if (done) {
                  await _queue.markProcessed(item.id);
                  outcomes.add(_QueueItemOutcome.processed);
                } else {
                  outcomes.add(_QueueItemOutcome.deferred);
                }
              } on ConflictFailure catch (error) {
                await _queue.markConflict(item.id, error.message);
                outcomes.add(_QueueItemOutcome.conflict);
              } on Failure catch (error) {
                await _queue.markFailed(item.id, error.message);
                outcomes.add(_QueueItemOutcome.failed);
              } catch (error) {
                await _queue.markFailed(item.id, error.toString());
                outcomes.add(_QueueItemOutcome.failed);
              }
            }
            return outcomes;
          },
        );

        for (final outcomes in chainResults) {
          for (final outcome in outcomes) {
            switch (outcome) {
              case _QueueItemOutcome.processed:
                processed++;
              case _QueueItemOutcome.deferred:
                deferred++;
              case _QueueItemOutcome.conflict:
                conflicts++;
              case _QueueItemOutcome.failed:
                break;
            }
          }
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
        SyncEntityTable.expenses => 5,
        SyncEntityTable.cashSessions => 6,
        SyncEntityTable.cashMovements => 7,
        SyncEntityTable.tenantModules => 8,
        SyncEntityTable.calculatorProductData => 9,
        SyncEntityTable.calculatorHistory => 10,
        SyncEntityTable.suppliers => 11,
        SyncEntityTable.purchaseOrders => 12,
        SyncEntityTable.purchaseReceipts => 13,
        SyncEntityTable.supplierInvoices => 14,
        SyncEntityTable.supplierPayments => 15,
        SyncEntityTable.stockTransfers => 16,
        SyncEntityTable.fxRateSnapshots => 17,
        SyncEntityTable.fxShopCurrencies => 18,
        SyncEntityTable.fxSessions => 19,
        SyncEntityTable.fxOperations => 20,
        SyncEntityTable.fxMovements => 21,
        _ => 99,
      };

  static int _operationPriority(String operation) => switch (operation) {
        SyncOperation.create => 0,
        SyncOperation.update => 1,
        SyncOperation.validate => 2,
        SyncOperation.submit => 3,
        SyncOperation.approve => 4,
        SyncOperation.send => 5,
        SyncOperation.receive => 6,
        SyncOperation.resolveDiscrepancy => 7,
        SyncOperation.cancel => 8,
        SyncOperation.close => 9,
        SyncOperation.archive => 10,
        SyncOperation.stockAdjust => 11,
        SyncOperation.payment => 12,
        SyncOperation.forgive => 13,
        SyncOperation.saleQuick => 14,
        SyncOperation.cashSessionOpen => 15,
        SyncOperation.cashSessionClose => 16,
        SyncOperation.cashMovementCreate => 17,
        SyncOperation.fxSessionOpen => 18,
        SyncOperation.fxSessionClose => 19,
        SyncOperation.fxSessionConfirmClose => 20,
        SyncOperation.fxSessionCancelClose => 21,
        SyncOperation.fxOperationCreate => 22,
        SyncOperation.fxMovementCreate => 23,
        _ => 50,
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
      case SyncEntityTable.expenses:
        return _processExpense(shopId, item, payload);
      case SyncEntityTable.cashSessions:
        return _processCashSession(shopId, item, payload);
      case SyncEntityTable.cashMovements:
        return _processCashMovement(shopId, item, payload);
      case SyncEntityTable.tenantModules:
        return _processTenantModule(shopId, item, payload);
      case SyncEntityTable.calculatorProductData:
        return _processCalculatorProductData(shopId, item, payload);
      case SyncEntityTable.calculatorHistory:
        return _processCalculatorHistory(shopId, item, payload);
      case SyncEntityTable.suppliers:
        return _processSupplier(shopId, item, payload);
      case SyncEntityTable.purchaseOrders:
        return _processPurchaseOrder(shopId, item, payload);
      case SyncEntityTable.purchaseReceipts:
        return _processPurchaseReceipt(shopId, item, payload);
      case SyncEntityTable.supplierInvoices:
        return _processSupplierInvoice(shopId, item, payload);
      case SyncEntityTable.supplierPayments:
        return _processSupplierPayment(shopId, item, payload);
      case SyncEntityTable.stockTransfers:
        return _processStockTransfer(shopId, item, payload);
      case SyncEntityTable.fxRateSnapshots:
        return _processFxRate(shopId, item, payload);
      case SyncEntityTable.fxShopCurrencies:
        return _processFxShopCurrencies(shopId, item, payload);
      case SyncEntityTable.fxSessions:
        return _processFxSession(shopId, item, payload);
      case SyncEntityTable.fxOperations:
        return _processFxOperation(shopId, item, payload);
      case SyncEntityTable.fxMovements:
        return _processFxMovement(shopId, item, payload);
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
        final remoteCustomers = await _customersRemote.listCustomers(includeArchived: true);
        final existing = remoteCustomers
            .where((c) => c.name.toLowerCase() == customer.name.toLowerCase())
            .firstOrNull;
        if (existing != null) {
          await _customersLocal.updateServerSync(
            customerId: customer.id,
            serverId: '${existing.id}',
          );
          return true;
        }
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
          address: payload.containsKey('address') ? payload['address'] as String? : null,
          note: payload.containsKey('note') ? payload['note'] as String? : null,
          isShared: payload.containsKey('isShared') ? payload['isShared'] as bool? : null,
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
        final remoteCategories = await _inventoryRemote.listCategories();
        final existing = remoteCategories
            .where(
              (c) =>
                  c.name.toLowerCase() ==
                  (payload['name'] as String? ?? category.name).toLowerCase(),
            )
            .firstOrNull;
        if (existing != null) return true;

        await _inventoryRemote.createCategory(
          name: payload['name'] as String? ?? category.name,
          description: payload['description'] as String? ?? category.description,
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
          description: payload.containsKey('description')
              ? payload['description'] as String?
              : null,
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
        final localCategoryId =
            payload['localCategoryId'] as int? ?? product.categoryId;
        if (localCategoryId == null) {
          await _queue.markDeferred(
            item.id,
            'Le produit « ${product.name} » doit avoir une catégorie pour être synchronisé.',
          );
          return false;
        }
        final categoryId = await _resolveCategoryServerId(
          shopId,
          localCategoryId,
        );
        if (categoryId == null) {
          final localCat = await _inventoryLocal.findCategory(
            shopId,
            payload['localCategoryId'] as int? ?? product.categoryId ?? -1,
          );
          await _queue.markDeferred(
            item.id,
            localCat == null
                ? 'Catégorie du produit « ${product.name} » introuvable.'
                : 'Catégorie « ${localCat.name} » non synchronisée sur le serveur.',
          );
          return false;
        }

        // Deduplication: check if product exists on the server
        final remoteProducts = await _inventoryRemote.listProducts(includeArchived: true);
        final existing = remoteProducts
            .where((p) => p.name.toLowerCase() == product.name.toLowerCase())
            .firstOrNull;

        if (existing != null) {
          await _inventoryLocal.updateProductServerSync(
            productId: product.id,
            serverId: '${existing.id}',
          );
          return true;
        }

        final priceSell = _coercePositivePrice(
          payload['priceSell'] ?? product.priceSell,
        );
        final remote = await _inventoryRemote.createProduct({
          'name': payload['name'] ?? product.name,
          'categoryId': categoryId,
          if (payload['sku'] != null || product.sku != null)
            'sku': payload['sku'] ?? product.sku,
          'priceSell': priceSell,
          if (payload['priceBuy'] != null || product.priceBuy != null)
            'priceBuy': payload['priceBuy'] ?? product.priceBuy,
          if (payload['priceSemiWholesale'] != null || product.priceSemiWholesale != null)
            'priceSemiWholesale':
                payload['priceSemiWholesale'] ?? product.priceSemiWholesale,
          if (payload['priceWholesale'] != null || product.priceWholesale != null)
            'priceWholesale': payload['priceWholesale'] ?? product.priceWholesale,
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
        if (request == null) {
          await _queue.markDeferred(
            item.id,
            'Vente en attente : synchronisez d\'abord les produits (et le client si crédit).',
          );
          return false;
        }
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

  Future<bool> _processExpense(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final expense = await _expensesLocal.findExpenseForSync(shopId, item.recordId);
    if (expense == null) return true;

    final isDeleted = await _expensesLocal.expenseIsDeleted(item.recordId);
    final serverId = await _expensesLocal.findExpenseServerId(shopId, item.recordId);

    if (isDeleted) {
      if (serverId == null) return true;
      await _expensesRemote.deleteExpense(int.parse(serverId));
      return true;
    }

    switch (item.operation) {
      case SyncOperation.create:
        if (serverId != null) return true;
        final body = await _buildExpenseBody(shopId, expense);
        final remote = await _expensesRemote.createExpense(body);
        final remoteId = remote['id'];
        if (remoteId == null) return false;
        await _expensesLocal.updateExpenseServerSync(
          expenseId: expense.id,
          serverId: '$remoteId',
        );
        return true;

      case SyncOperation.update:
        if (serverId == null) {
          final body = await _buildExpenseBody(shopId, expense);
          final remote = await _expensesRemote.createExpense(body);
          final remoteId = remote['id'];
          if (remoteId == null) return false;
          await _expensesLocal.updateExpenseServerSync(
            expenseId: expense.id,
            serverId: '$remoteId',
          );
          return true;
        }
        await _expensesRemote.updateExpense(
          int.parse(serverId),
          await _buildExpenseBody(shopId, expense),
        );
        return true;

      default:
        throw ValidationFailure(
          'Opération dépense inconnue : ${item.operation}',
        );
    }
  }

  Future<bool> _processCashSession(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final session =
        await _cashSessionsLocal.findSessionForSync(shopId, item.recordId);
    if (session == null) return true;

    var serverId =
        await _cashSessionsLocal.findSessionServerId(shopId, item.recordId);

    switch (item.operation) {
      case SyncOperation.cashSessionOpen:
        if (serverId != null) return true;
        try {
          final opened = await _cashSessionsRemote.openSession(
            OpenCashSessionApiRequest(
              openingCash: session.openingCash,
              openingMomo: session.openingMomo,
            ),
          );
          await _cashSessionsLocal.updateSessionServerSync(
            sessionId: session.id,
            serverId: '${opened.id}',
          );
          return true;
        } on ConflictFailure catch (error) {
          if (!_isCashSessionAlreadyOpen(error)) rethrow;
          serverId = await _linkOpenServerSession(
            shopId: shopId,
            localSessionId: session.id,
          );
          return serverId != null;
        }

      case SyncOperation.cashSessionClose:
        serverId ??= await _linkOpenServerSession(
          shopId: shopId,
          localSessionId: session.id,
        );
        if (serverId == null) {
          try {
            final opened = await _cashSessionsRemote.openSession(
              OpenCashSessionApiRequest(
                openingCash: session.openingCash,
                openingMomo: session.openingMomo,
              ),
            );
            serverId = '${opened.id}';
          } on ConflictFailure catch (error) {
            if (!_isCashSessionAlreadyOpen(error)) rethrow;
            serverId = await _linkOpenServerSession(
              shopId: shopId,
              localSessionId: session.id,
            );
            if (serverId == null) return false;
          }
          await _cashSessionsLocal.updateSessionServerSync(
            sessionId: session.id,
            serverId: serverId,
          );
        }
        try {
          await _cashSessionsRemote.closeSession(
            int.parse(serverId),
            CloseCashSessionApiRequest(
              countedCash: (payload['countedCash'] as num?)?.toInt() ??
                  session.countedCash ??
                  0,
              countedMomo: (payload['countedMomo'] as num?)?.toInt() ??
                  session.countedMomo ??
                  0,
              closingNote:
                  payload['closingNote'] as String? ?? session.closingNote,
              ownerPin: payload['ownerPin'] as String?,
              salesCash: (payload['salesCash'] as num?)?.toInt() ??
                  session.salesCash,
              salesMomo: (payload['salesMomo'] as num?)?.toInt() ??
                  session.salesMomo,
              expensesCash: (payload['expensesCash'] as num?)?.toInt() ??
                  session.expensesCash,
              expensesMomo: (payload['expensesMomo'] as num?)?.toInt() ??
                  session.expensesMomo,
              depositsCash: (payload['depositsCash'] as num?)?.toInt() ??
                  session.depositsCash,
              depositsMomo: (payload['depositsMomo'] as num?)?.toInt() ??
                  session.depositsMomo,
              withdrawalsCash: (payload['withdrawalsCash'] as num?)?.toInt() ??
                  session.withdrawalsCash,
              withdrawalsMomo: (payload['withdrawalsMomo'] as num?)?.toInt() ??
                  session.withdrawalsMomo,
              saleCount: (payload['saleCount'] as num?)?.toInt() ??
                  session.saleCount,
            ),
          );
        } on ConflictFailure catch (error) {
          if (!_isCashSessionAlreadyClosed(error)) rethrow;
        }
        await _cashSessionsLocal.updateSessionServerSync(
          sessionId: session.id,
          serverId: serverId,
        );
        return true;

      default:
        throw ValidationFailure(
          'Opération caisse inconnue : ${item.operation}',
        );
    }
  }

  bool _isCashSessionAlreadyOpen(ConflictFailure error) {
    final message = error.message.toLowerCase();
    return message.contains('déjà ouverte') ||
        message.contains('deja ouverte') ||
        message.contains('already open');
  }

  bool _isCashSessionAlreadyClosed(ConflictFailure error) {
    final message = error.message.toLowerCase();
    return message.contains('déjà clôturée') ||
        message.contains('deja cloturee') ||
        message.contains('déjà cloturée') ||
        message.contains('already closed');
  }

  Future<String?> _linkOpenServerSession({
    required int shopId,
    required int localSessionId,
  }) async {
    final remoteSessions = await _cashSessionsRemote.fetchSessions(limit: 20);
    CashSessionApiDto? open;
    for (final remote in remoteSessions) {
      if (remote.status == 'open') {
        open = remote;
        break;
      }
    }
    if (open == null) return null;

    final serverId = '${open.id}';
    await _cashSessionsLocal.updateSessionServerSync(
      sessionId: localSessionId,
      serverId: serverId,
    );
    return serverId;
  }

  Future<bool> _processCashMovement(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final movement =
        await _cashSessionsLocal.findMovementForSync(shopId, item.recordId);
    if (movement == null) return true;

    final serverId =
        await _cashSessionsLocal.findMovementServerId(shopId, item.recordId);
    if (serverId != null) return true;

    switch (item.operation) {
      case SyncOperation.cashMovementCreate:
        var sessionServerId = await _cashSessionsLocal.findSessionServerId(
          shopId,
          movement.sessionId,
        );
        if (sessionServerId == null) return false;
        final created = await _cashSessionsRemote.createMovement(
          int.parse(sessionServerId),
          CreateCashMovementApiRequest(
            movementType: payload['movementType'] as String? ??
                movement.movementType.code,
            registerType: payload['registerType'] as String? ??
                movement.registerType.code,
            amount: (payload['amount'] as num?)?.toInt() ?? movement.amount,
            note: payload['note'] as String? ?? movement.note,
          ),
        );
        await _cashSessionsLocal.updateMovementServerSync(
          movementId: movement.id,
          serverId: '${created.id}',
        );
        return true;

      default:
        throw ValidationFailure(
          'Opération mouvement caisse inconnue : ${item.operation}',
        );
    }
  }

  Future<bool> _processFxRate(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final existingServerId =
        await _fxExchangeLocal.findRateServerId(shopId, item.recordId);
    if (existingServerId != null) return true;

    if (item.operation != SyncOperation.create) {
      throw ValidationFailure('Opération taux FX inconnue : ${item.operation}');
    }

    final created = await _fxExchangeRemote.createRate(
      CreateFxRateRequest(
        quoteCurrency: payload['quoteCurrency'] as String,
        buyRateNumerator: (payload['buyRateNumerator'] as num).toInt(),
        buyRateDenominator: (payload['buyRateDenominator'] as num).toInt(),
        sellRateNumerator: (payload['sellRateNumerator'] as num).toInt(),
        sellRateDenominator: (payload['sellRateDenominator'] as num).toInt(),
        applyMode: payload['applyMode'] as String? ?? 'next_session',
      ),
    );
    await _fxExchangeLocal.updateRateServerSync(
      rateId: item.recordId,
      serverId: '${created.id}',
    );
    return true;
  }

  Future<bool> _processFxShopCurrencies(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final currencies = payload['currencies'];
    if (currencies is! List) return true;

    await _fxExchangeRemote.upsertShopCurrencies(
      currencies
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
    return true;
  }

  Future<bool> _processFxSession(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final session =
        await _fxExchangeLocal.findSessionForSync(shopId, item.recordId);
    if (session == null) return true;

    var serverId =
        await _fxExchangeLocal.findSessionServerId(shopId, item.recordId);

    switch (item.operation) {
      case SyncOperation.fxSessionOpen:
        if (serverId != null) return true;
        try {
          final openingBalances =
              (payload['openingBalances'] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
          final opened = await _fxExchangeRemote.openSession(
            OpenFxSessionRequest(openingBalances: openingBalances),
          );
          await _fxExchangeLocal.updateSessionServerSync(
            sessionId: session.id,
            serverId: '${opened.id}',
          );
          return true;
        } on ConflictFailure catch (error) {
          if (!_isFxSessionAlreadyOpen(error)) rethrow;
          serverId = await _linkOpenFxServerSession(
            shopId: shopId,
            localSessionId: session.id,
          );
          return serverId != null;
        }

      case SyncOperation.fxSessionClose:
        serverId ??= await _linkOpenFxServerSession(
          shopId: shopId,
          localSessionId: session.id,
        );
        if (serverId == null) {
          await _queue.markDeferred(
            item.id,
            'Session FX non synchronisée (ouverture en attente).',
          );
          return false;
        }
        try {
          final countedBalances =
              (payload['countedBalances'] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
          await _fxExchangeRemote.closeSession(
            int.parse(serverId),
            CloseFxSessionRequest(
              countedBalances: countedBalances,
              closingNote: payload['closingNote'] as String?,
            ),
          );
        } on ConflictFailure catch (error) {
          if (!_isFxSessionAlreadyPendingOrClosed(error)) rethrow;
        }
        await _fxExchangeLocal.updateSessionServerSync(
          sessionId: session.id,
          serverId: serverId,
        );
        return true;

      case SyncOperation.fxSessionConfirmClose:
        serverId ??= await _linkOpenFxServerSession(
          shopId: shopId,
          localSessionId: session.id,
        );
        if (serverId == null) {
          await _queue.markDeferred(
            item.id,
            'Session FX non synchronisée.',
          );
          return false;
        }
        try {
          await _fxExchangeRemote.confirmCloseSession(int.parse(serverId));
        } on ConflictFailure catch (error) {
          if (!_isFxSessionAlreadyClosed(error)) rethrow;
        }
        await _fxExchangeLocal.updateSessionServerSync(
          sessionId: session.id,
          serverId: serverId,
        );
        return true;

      case SyncOperation.fxSessionCancelClose:
        serverId ??= await _linkOpenFxServerSession(
          shopId: shopId,
          localSessionId: session.id,
        );
        if (serverId == null) {
          await _queue.markDeferred(
            item.id,
            'Session FX non synchronisée.',
          );
          return false;
        }
        try {
          await _fxExchangeRemote.cancelPendingClose(int.parse(serverId));
        } on ConflictFailure catch (_) {
          // Déjà rouverte ou absente : on considère OK.
        }
        await _fxExchangeLocal.updateSessionServerSync(
          sessionId: session.id,
          serverId: serverId,
        );
        return true;

      default:
        throw ValidationFailure(
          'Opération session FX inconnue : ${item.operation}',
        );
    }
  }

  Future<String?> _linkOpenFxServerSession({
    required int shopId,
    required int localSessionId,
  }) async {
    try {
      final open = await _fxExchangeRemote.fetchOpenSession();
      final remote = open.session;
      if (remote == null) return null;
      final serverId = '${remote.id}';
      await _fxExchangeLocal.updateSessionServerSync(
        sessionId: localSessionId,
        serverId: serverId,
      );
      return serverId;
    } catch (_) {
      return null;
    }
  }

  bool _isFxSessionAlreadyOpen(ConflictFailure error) {
    final message = error.message.toLowerCase();
    return message.contains('déjà ouverte') ||
        message.contains('deja ouverte') ||
        message.contains('already open');
  }

  bool _isFxSessionAlreadyClosed(ConflictFailure error) {
    final message = error.message.toLowerCase();
    return message.contains('déjà clôturée') ||
        message.contains('deja cloturee') ||
        message.contains('déjà cloturée') ||
        message.contains('already closed');
  }

  bool _isFxSessionAlreadyPendingOrClosed(ConflictFailure error) {
    final message = error.message.toLowerCase();
    return _isFxSessionAlreadyClosed(error) ||
        message.contains('déjà été soumis') ||
        message.contains('deja ete soumis') ||
        message.contains('attente de validation');
  }

  Future<bool> _processFxOperation(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final existingServerId =
        await _fxExchangeLocal.findOperationServerId(shopId, item.recordId);
    if (existingServerId != null) return true;

    if (item.operation != SyncOperation.fxOperationCreate) {
      throw ValidationFailure(
        'Opération FX inconnue : ${item.operation}',
      );
    }

    final localSessionId = (payload['sessionId'] as num?)?.toInt();
    if (localSessionId == null) return true;

    final sessionServerId = await _fxExchangeLocal.findSessionServerId(
      shopId,
      localSessionId,
    );
    if (sessionServerId == null) {
      await _queue.markDeferred(
        item.id,
        'Session FX non synchronisée.',
      );
      return false;
    }

    int? remoteCustomerId;
    final localCustomerId = (payload['customerId'] as num?)?.toInt();
    if (localCustomerId != null) {
      final customer =
          await _customersLocal.findCustomer(shopId, localCustomerId);
      if (customer == null || customer.serverId == null) {
        await _queue.markDeferred(
          item.id,
          'Client FX non synchronisé.',
        );
        return false;
      }
      remoteCustomerId = int.tryParse(customer.serverId!);
      if (remoteCustomerId == null) {
        await _queue.markDeferred(
          item.id,
          'Client FX serverId invalide.',
        );
        return false;
      }
    }

    final created = await _fxExchangeRemote.createOperation(
      int.parse(sessionServerId),
      CreateFxOperationRequest(
        operationType: payload['operationType'] as String? ?? 'buy',
        fromCurrency: payload['fromCurrency'] as String,
        fromAmount: (payload['fromAmount'] as num).toInt(),
        toCurrency: payload['toCurrency'] as String,
        toAmount: (payload['toAmount'] as num).toInt(),
        customerId: remoteCustomerId,
        note: payload['note'] as String?,
      ),
    );
    await _fxExchangeLocal.updateOperationServerSync(
      operationId: item.recordId,
      serverId: '${created.id}',
    );
    return true;
  }

  Future<bool> _processFxMovement(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final existingServerId =
        await _fxExchangeLocal.findMovementServerId(shopId, item.recordId);
    if (existingServerId != null) return true;

    if (item.operation != SyncOperation.fxMovementCreate) {
      throw ValidationFailure(
        'Mouvement FX inconnu : ${item.operation}',
      );
    }

    final localSessionId = (payload['sessionId'] as num?)?.toInt();
    if (localSessionId == null) return true;

    final sessionServerId = await _fxExchangeLocal.findSessionServerId(
      shopId,
      localSessionId,
    );
    if (sessionServerId == null) {
      await _queue.markDeferred(
        item.id,
        'Session FX non synchronisée.',
      );
      return false;
    }

    final created = await _fxExchangeRemote.createMovement(
      int.parse(sessionServerId),
      CreateFxMovementRequest(
        currencyCode: payload['currencyCode'] as String,
        movementType: payload['movementType'] as String? ?? 'deposit',
        amount: (payload['amount'] as num).toInt(),
        note: payload['note'] as String?,
      ),
    );
    await _fxExchangeLocal.updateMovementServerSync(
      movementId: item.recordId,
      serverId: '${created.id}',
    );
    return true;
  }

  Future<Map<String, dynamic>> _buildExpenseBody(
    int shopId,
    Expense expense,
  ) async {
    int? categoryId;
    if (expense.categoryId != null) {
      categoryId = await _resolveExpenseCategoryServerId(
        shopId,
        expense.categoryId!,
      );
    }

    return {
      if (categoryId != null) 'categoryId': categoryId,
      'title': expense.title,
      if (expense.description != null) 'description': expense.description,
      'amount': expense.amount,
      'expenseDate': expense.expenseDate,
      'paymentMethod': expense.paymentMethod.code,
      if (expense.supplier != null) 'supplier': expense.supplier,
      if (expense.invoiceNumber != null) 'invoiceNumber': expense.invoiceNumber,
      'repeatSchedule': expense.repeatSchedule.code,
      'status': expense.status.code,
    };
  }

  Future<int?> _resolveExpenseCategoryServerId(
    int shopId,
    int localCategoryId,
  ) async {
    final category = await _expensesLocal.findCategory(shopId, localCategoryId);
    if (category == null) return null;

    final remoteCategories = await _expensesRemote.fetchCategories();
    final matches = remoteCategories.where(
      (c) =>
          (c['name'] as String?)?.toLowerCase() ==
          category.name.toLowerCase(),
    );
    if (matches.isEmpty) return null;
    final id = matches.first['id'];
    return id is num ? id.toInt() : null;
  }

  Future<int?> _resolveCategoryServerId(int shopId, int? localCategoryId) async {
    if (localCategoryId == null) return null;
    final category = await _inventoryLocal.findCategory(shopId, localCategoryId);
    if (category == null) return null;

    final remoteCategories = await _inventoryRemote.listCategories();
    final match = remoteCategories
        .where((c) => c.name.toLowerCase() == category.name.toLowerCase())
        .firstOrNull;
    if (match != null) return match.id;

    try {
      final created = await _inventoryRemote.createCategory(
        name: category.name,
        description: category.description,
        sortOrder: category.sortOrder,
      );
      return created.id;
    } on Object {
      return null;
    }
  }

  int _coercePositivePrice(dynamic value) {
    final parsed = value is int ? value : int.tryParse('$value') ?? 0;
    return parsed < 1 ? 1 : parsed;
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

  Future<bool> _processTenantModule(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final enabled = payload['enabled'] as bool? ?? false;
    final moduleCode = payload['moduleCode'] as String?;
    if (moduleCode == fxModuleCode) {
      await _fxExchangeRemote.toggleModule(enabled);
    } else {
      // CALCULATORS ou payloads legacy sans moduleCode.
      await _calculatorsRemote.toggleModule(enabled);
    }
    return true;
  }

  Future<bool> _processCalculatorProductData(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final local = await _calculatorsLocal.getProductConfig(shopId, payload['productId'] as int);
    if (local == null) return true;

    final product = await _inventoryLocal.findProduct(shopId, payload['productId'] as int);
    if (product == null || product.serverId == null) {
      await _queue.markDeferred(item.id, 'Produit calculateur non synchronisé.');
      return false;
    }

    final remote = await _calculatorsRemote.saveProductConfig(
      productId: int.parse(product.serverId!),
      calculatorType: payload['calculatorType'] as String,
      metadata: payload['metadata'] as Map<String, dynamic>,
    );

    if (remote.containsKey('serverId')) {
      await _calculatorsLocal.updateServerSyncProductConfig(local.id, '${remote['serverId']}');
    } else if (remote.containsKey('id')) {
      await _calculatorsLocal.updateServerSyncProductConfig(local.id, '${remote['id']}');
    }
    return true;
  }

  Future<bool> _processCalculatorHistory(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    // If it's already synced, ignore
    final historyRows = await _calculatorsLocal.getHistory(shopId);
    final local = historyRows.where((r) => r.id == item.recordId).firstOrNull;
    if (local == null || local.serverId != null) return true;

    final remote = await _calculatorsRemote.createHistoryEntry(
      calculatorType: payload['calculatorType'] as String,
      input: payload['input'] as Map<String, dynamic>,
      result: payload['result'] as Map<String, dynamic>,
      isFavorite: payload['isFavorite'] as bool?,
      label: payload['label'] as String?,
    );

    if (remote.containsKey('serverId')) {
      await _calculatorsLocal.updateServerSyncHistory(local.id, '${remote['serverId']}');
    } else if (remote.containsKey('id')) {
      await _calculatorsLocal.updateServerSyncHistory(local.id, '${remote['id']}');
    }
    return true;
  }

  Future<bool> _processSupplier(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final local = await _procurementLocal.findSupplier(shopId, item.recordId);
    if (local == null) return true;

    switch (item.operation) {
      case SyncOperation.create:
        if (local.serverId != null) return true;
        if (await _adoptRemoteSupplierIfPossible(shopId, local)) return true;
        try {
          final remote = await _procurementRemote.createSupplier({
            'name': payload['name'] ?? local.name,
            'phone': payload['phone'] ?? local.phone,
            'email': payload['email'] ?? local.email,
            'address': payload['address'] ?? local.address,
          });
          final serverId = remote['id']?.toString();
          final version = remote['version'] as int? ?? 1;
          if (serverId != null) {
            await _procurementLocal.updateSupplier(
              shopId,
              local.id,
              serverId: serverId,
              syncStatus: 'synced',
              version: version,
            );
          }
          return true;
        } catch (error) {
          if (_isDuplicateProcurementKeyError(error.toString()) &&
              await _adoptRemoteSupplierIfPossible(shopId, local)) {
            return true;
          }
          rethrow;
        }

      case SyncOperation.update:
        if (local.serverId == null) return false; // defer
        final remote = await _procurementRemote.updateSupplier(
          int.parse(local.serverId!),
          payload,
        );
        final version = remote['version'] as int? ?? (local.version + 1);
        await _procurementLocal.updateSupplier(
          shopId,
          local.id,
          syncStatus: 'synced',
          version: version,
        );
        return true;
    }
    return true;
  }

  Future<bool> _processPurchaseOrder(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final local = await _procurementLocal.findPurchaseOrder(shopId, item.recordId);
    if (local == null) return true;

    switch (item.operation) {
      case SyncOperation.create:
        if (local.serverId != null) return true;
        if (await _adoptRemotePurchaseOrderIfPossible(shopId, local)) return true;

        // Resolve supplier serverId
        final supplier = await _procurementLocal.findSupplier(shopId, local.supplierId);
        if (supplier == null || supplier.serverId == null) {
          await _queue.markDeferred(item.id, 'Fournisseur associé non synchronisé.');
          return false;
        }

        // Resolve product serverIds
        final remoteItems = <Map<String, dynamic>>[];
        final localItems = local.items ?? [];
        for (final it in localItems) {
          final prod = await _inventoryLocal.findProduct(shopId, it.productId);
          if (prod == null || prod.serverId == null) {
            await _queue.markDeferred(item.id, 'Produit #${it.productId} non synchronisé.');
            return false;
          }
          remoteItems.add({
            'productId': int.parse(prod.serverId!),
            'quantityOrdered': it.quantityOrdered,
            'unitCost': it.unitCost,
            'discount': it.discount,
            'tax': it.tax,
            'subtotal': it.subtotal,
          });
        }

        try {
          final remote = await _procurementRemote.createPurchaseOrder({
            'supplierId': int.parse(supplier.serverId!),
            'number': local.number,
            'orderedAt': local.orderedAt,
            if (local.expectedAt != null) 'expectedAt': local.expectedAt,
            'subtotal': local.subtotal,
            'discount': local.discount,
            'tax': local.tax,
            'total': local.total,
            'notes': local.notes,
            'items': remoteItems,
          });

          var snapshot = remote;
          if (snapshot['items'] is! List || (snapshot['items'] as List).isEmpty) {
            final serverPoId = (remote['id'] as num?)?.toInt();
            if (serverPoId != null) {
              snapshot = await _procurementRemote.fetchPurchaseOrder(serverPoId);
            }
          }
          await _procurementLocal.applyRemotePurchaseOrderSnapshot(
            shopId,
            local.id,
            snapshot,
          );
          return true;
        } catch (error) {
          if (_isDuplicateProcurementKeyError(error.toString()) &&
              await _adoptRemotePurchaseOrderIfPossible(shopId, local)) {
            return true;
          }
          rethrow;
        }

      case SyncOperation.update:
        if (local.serverId == null) return false;

        final body = <String, dynamic>{};
        for (final key in [
          'number',
          'orderedAt',
          'expectedAt',
          'subtotal',
          'discount',
          'tax',
          'total',
          'notes',
        ]) {
          if (payload.containsKey(key)) body[key] = payload[key];
        }

        if (payload.containsKey('supplierId')) {
          final supplier = await _procurementLocal.findSupplier(
            shopId,
            payload['supplierId'] as int,
          );
          if (supplier == null || supplier.serverId == null) {
            await _queue.markDeferred(item.id, 'Fournisseur associé non synchronisé.');
            return false;
          }
          body['supplierId'] = int.parse(supplier.serverId!);
        }

        if (payload.containsKey('items')) {
          final remoteItems = <Map<String, dynamic>>[];
          final itemsList = payload['items'] as List;
          for (final it in itemsList) {
            final prod = await _inventoryLocal.findProduct(shopId, it['productId'] as int);
            if (prod == null || prod.serverId == null) {
              await _queue.markDeferred(item.id, 'Produit #${it['productId']} non synchronisé.');
              return false;
            }
            remoteItems.add({
              'productId': int.parse(prod.serverId!),
              'quantityOrdered': it['quantityOrdered'],
              'unitCost': it['unitCost'],
              'discount': it['discount'] ?? 0,
              'tax': it['tax'] ?? 0,
              'subtotal': it['subtotal'],
            });
          }
          body['items'] = remoteItems;
        }

        if (body.isEmpty) return true;

        final remoteUpdate = await _procurementRemote.updatePurchaseOrder(
          int.parse(local.serverId!),
          body,
        );
        await _procurementLocal.applyRemotePurchaseOrderSnapshot(
          shopId,
          local.id,
          remoteUpdate,
        );
        return true;

      case SyncOperation.validate:
        if (local.serverId == null) return false;
        await _procurementRemote.validatePurchaseOrder(int.parse(local.serverId!));
        return true;

      case SyncOperation.send:
        if (local.serverId == null) return false;
        await _procurementRemote.sendPurchaseOrder(int.parse(local.serverId!));
        return true;

      case SyncOperation.cancel:
        if (local.serverId == null) return false;
        await _procurementRemote.cancelPurchaseOrder(
          int.parse(local.serverId!),
          payload['reason'] as String?,
        );
        return true;
    }
    return true;
  }

  Future<bool> _processPurchaseReceipt(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final localReceipt = await _procurementLocal.findReceipt(shopId, item.recordId);
    if (localReceipt == null) return true;
    if (localReceipt.serverId != null) return true;
    if (await _adoptRemoteReceiptIfPossible(shopId, localReceipt)) return true;

    final isDirect = localReceipt.receiptType == PurchaseReceiptType.direct;

    if (isDirect) {
      return _processDirectGoodsReceipt(shopId, item, localReceipt, payload);
    }

    final localPo = await _procurementLocal.findPurchaseOrder(
      shopId,
      localReceipt.purchaseOrderId!,
    );
    if (localPo == null || localPo.serverId == null) {
      await _queue.markDeferred(item.id, 'Commande associée non synchronisée.');
      return false;
    }

    final localPoItems = localPo.items ?? [];
    final remoteItems = <Map<String, dynamic>>[];

    final itemsList = payload['items'] as List;
    for (final it in itemsList) {
      final poItem = localPoItems.where((pi) => pi.id == (it['purchaseOrderItemId'] as int)).firstOrNull;
      if (poItem == null || poItem.serverId == null) {
        await _queue.markDeferred(item.id, 'Ligne de commande associée non synchronisée.');
        return false;
      }

      final prod = await _inventoryLocal.findProduct(shopId, it['productId'] as int);
      if (prod == null || prod.serverId == null) {
        await _queue.markDeferred(item.id, 'Produit associé non synchronisé.');
        return false;
      }

      remoteItems.add(
        ProcurementRemotePayloads.purchaseOrderReceiptItem(
          serverPurchaseOrderItemId: int.parse(poItem.serverId!),
          quantityReceived: it['quantityReceived'] as int,
          unitCost: it['unitCost'] as int,
          batchNumber: it['batchNumber'] as String?,
          expiryDate: it['expiryDate'] as int?,
        ),
      );
    }

    try {
      final remote = await _procurementRemote.receiveItems(
        int.parse(localPo.serverId!),
        ProcurementRemotePayloads.purchaseOrderReceiveBody(
          receiptNumber: localReceipt.receiptNumber,
          receivedAt: localReceipt.receivedAt,
          notes: localReceipt.notes,
          items: remoteItems,
        ),
      );

      final serverId = remote['id']?.toString();
      if (serverId != null) {
        await _procurementLocal.linkReceiptServerSync(
          shopId: shopId,
          localId: localReceipt.id,
          serverId: serverId,
          version: remote['version'] as int? ?? 1,
        );
      }
      return true;
    } catch (error) {
      if (_isDuplicateProcurementKeyError(error.toString()) &&
          await _adoptRemoteReceiptIfPossible(shopId, localReceipt)) {
        return true;
      }
      rethrow;
    }
  }

  Future<bool> _processDirectGoodsReceipt(
    int shopId,
    SyncQueueData item,
    PurchaseReceipt localReceipt,
    Map<String, dynamic> payload,
  ) async {
    final supplier =
        await _procurementLocal.findSupplier(shopId, localReceipt.supplierId);
    if (supplier == null || supplier.serverId == null) {
      await _queue.markDeferred(item.id, 'Fournisseur associé non synchronisé.');
      return false;
    }

    final remoteItems = <Map<String, dynamic>>[];
    final itemsList = payload['items'] as List;
    for (final it in itemsList) {
      final prod =
          await _inventoryLocal.findProduct(shopId, it['productId'] as int);
      if (prod == null || prod.serverId == null) {
        await _queue.markDeferred(item.id, 'Produit associé non synchronisé.');
        return false;
      }

      remoteItems.add(
        ProcurementRemotePayloads.directReceiptItem(
          serverProductId: int.parse(prod.serverId!),
          quantityReceived: it['quantityReceived'] as int,
          unitCost: it['unitCost'] as int,
          batchNumber: it['batchNumber'] as String?,
          expiryDate: it['expiryDate'] as int?,
        ),
      );
    }

    try {
      final remote = await _procurementRemote.createDirectGoodsReceipt(
        ProcurementRemotePayloads.directGoodsReceiptBody(
          serverSupplierId: int.parse(supplier.serverId!),
          receiptNumber: localReceipt.receiptNumber,
          receivedAt: localReceipt.receivedAt,
          notes: localReceipt.notes,
          items: remoteItems,
        ),
      );

      final serverId = remote['id']?.toString();
      if (serverId != null) {
        await _procurementLocal.linkReceiptServerSync(
          shopId: shopId,
          localId: localReceipt.id,
          serverId: serverId,
          version: remote['version'] as int? ?? 1,
        );
      }
      return true;
    } catch (error) {
      if (_isDuplicateProcurementKeyError(error.toString()) &&
          await _adoptRemoteReceiptIfPossible(shopId, localReceipt)) {
        return true;
      }
      rethrow;
    }
  }

  Future<bool> _processSupplierInvoice(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final local = await _procurementLocal.findInvoice(shopId, item.recordId);
    if (local == null) return true;
    if (local.serverId != null) return true;

    final supplier = await _procurementLocal.findSupplier(shopId, local.supplierId);
    if (supplier == null || supplier.serverId == null) {
      await _queue.markDeferred(item.id, 'Fournisseur associé non synchronisé.');
      return false;
    }

    if (await _adoptRemoteInvoiceIfPossible(shopId, local, supplier)) return true;

    int? remotePoId;
    if (local.purchaseOrderId != null) {
      final po = await _procurementLocal.findPurchaseOrder(shopId, local.purchaseOrderId!);
      if (po == null || po.serverId == null) {
        await _queue.markDeferred(item.id, 'Commande associée non synchronisée.');
        return false;
      }
      remotePoId = int.parse(po.serverId!);
    }

    try {
      final remote = await _procurementRemote.createInvoice({
        if (remotePoId != null) 'purchaseOrderId': remotePoId,
        'invoiceNumber': local.invoiceNumber,
        'supplierId': int.parse(supplier.serverId!),
        'invoiceDate': local.invoiceDate,
        if (local.dueDate != null) 'dueDate': local.dueDate,
        'subtotal': local.subtotal,
        'tax': local.tax,
        'total': local.total,
      });

      final serverId = remote['id']?.toString();
      if (serverId != null) {
        await _procurementLocal.linkInvoiceServerSync(
          shopId: shopId,
          localId: local.id,
          serverId: serverId,
          version: remote['version'] as int? ?? 1,
        );
      }
      return true;
    } catch (error) {
      if (_isDuplicateProcurementKeyError(error.toString()) &&
          await _adoptRemoteInvoiceIfPossible(shopId, local, supplier)) {
        return true;
      }
      rethrow;
    }
  }

  Future<bool> _processSupplierPayment(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    // Look up parent invoice server ID
    final invoiceLocalId = payload['invoiceId'] as int;
    var invoice = await _procurementLocal.findInvoice(shopId, invoiceLocalId);
    if (invoice == null) return true;

    if (invoice.serverId == null) {
      final supplier = await _procurementLocal.findSupplier(shopId, invoice.supplierId);
      if (supplier?.serverId != null) {
        await _adoptRemoteInvoiceIfPossible(shopId, invoice, supplier!);
        invoice = await _procurementLocal.findInvoice(shopId, invoiceLocalId);
      }
    }

    if (invoice == null || invoice.serverId == null) {
      await _queue.markDeferred(item.id, 'Facture associée non synchronisée.');
      return false;
    }

    // Since payments are simple creation entries in Drift payments table:
    final payRows = await (_procurementLocal.database.select(_procurementLocal.database.supplierPayments)
          ..where((p) => p.id.equals(item.recordId)))
        .get();
    final localPay = payRows.firstOrNull;
    if (localPay == null || localPay.serverId != null) return true;

    if (await _adoptRemotePaymentIfPossible(
      shopId,
      localPayId: localPay.id,
      amount: localPay.amount,
      paymentDate: localPay.paymentDate,
      invoice: invoice,
    )) {
      return true;
    }

    try {
      final remote = await _procurementRemote.recordPayment(int.parse(invoice.serverId!), {
        'amount': localPay.amount,
        'paymentMethod': ProcurementLocalDatasource.paymentMethodToApi(localPay.paymentMethod),
        'paymentDate': localPay.paymentDate,
        if (localPay.reference != null) 'reference': localPay.reference,
      });

      final serverId = remote['id']?.toString();
      if (serverId != null) {
        await _procurementLocal.linkPaymentServerSync(
          shopId: shopId,
          localId: localPay.id,
          serverId: serverId,
          version: remote['version'] as int? ?? 1,
        );
      }
      return true;
    } catch (error) {
      if (_isDuplicateProcurementKeyError(error.toString()) &&
          await _adoptRemotePaymentIfPossible(
            shopId,
            localPayId: localPay.id,
            amount: localPay.amount,
            paymentDate: localPay.paymentDate,
            invoice: invoice,
          )) {
        return true;
      }
      rethrow;
    }
  }

  Future<bool> _adoptRemoteSupplierIfPossible(int shopId, Supplier local) async {
    try {
      final remoteSuppliers = await _procurementRemote.fetchSuppliers();
      final match = remoteSuppliers
          .where(
            (s) =>
                (s['name'] as String?)?.trim().toLowerCase() ==
                local.name.trim().toLowerCase(),
          )
          .firstOrNull;
      if (match == null) return false;
      final serverId = match['id']?.toString();
      if (serverId == null) return false;
      await _procurementLocal.updateSupplier(
        shopId,
        local.id,
        serverId: serverId,
        syncStatus: 'synced',
        version: match['version'] as int? ?? 1,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _adoptRemotePurchaseOrderIfPossible(
    int shopId,
    PurchaseOrder local,
  ) async {
    try {
      final remoteOrders = await _procurementRemote.fetchPurchaseOrders();
      final match = remoteOrders
          .where((o) => o['number'] == local.number)
          .firstOrNull;
      if (match == null) return false;
      final serverPoId = (match['id'] as num?)?.toInt();
      if (serverPoId == null) return false;
      final snapshot = await _procurementRemote.fetchPurchaseOrder(serverPoId);
      await _procurementLocal.applyRemotePurchaseOrderSnapshot(
        shopId,
        local.id,
        snapshot,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _adoptRemoteInvoiceIfPossible(
    int shopId,
    SupplierInvoice local,
    Supplier supplier,
  ) async {
    if (supplier.serverId == null) return false;
    try {
      final remoteInvoices = await _procurementRemote.fetchInvoices(
        supplierId: int.parse(supplier.serverId!),
      );
      final match = remoteInvoices
          .where((i) => i['invoiceNumber'] == local.invoiceNumber)
          .firstOrNull;
      if (match == null) return false;
      final serverId = match['id']?.toString();
      if (serverId == null) return false;
      await _procurementLocal.linkInvoiceServerSync(
        shopId: shopId,
        localId: local.id,
        serverId: serverId,
        version: match['version'] as int? ?? 1,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _adoptRemoteReceiptIfPossible(
    int shopId,
    PurchaseReceipt local,
  ) async {
    if (local.receiptType == PurchaseReceiptType.direct) return false;
    if (local.purchaseOrderId == null) return false;
    try {
      final po = await _procurementLocal.findPurchaseOrder(
        shopId,
        local.purchaseOrderId!,
      );
      if (po?.serverId == null) return false;
      final detail = await _procurementRemote.fetchPurchaseOrder(
        int.parse(po!.serverId!),
      );
      final receipts = detail['receipts'] as List?;
      if (receipts == null) return false;
      final match = receipts
          .whereType<Map<String, dynamic>>()
          .where((r) => r['receiptNumber'] == local.receiptNumber)
          .firstOrNull;
      if (match == null) return false;
      final serverId = match['id']?.toString();
      if (serverId == null) return false;
      await _procurementLocal.linkReceiptServerSync(
        shopId: shopId,
        localId: local.id,
        serverId: serverId,
        version: match['version'] as int? ?? 1,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _adoptRemotePaymentIfPossible(
    int shopId, {
    required int localPayId,
    required int amount,
    required int paymentDate,
    required SupplierInvoice invoice,
  }) async {
    if (invoice.serverId == null) return false;
    try {
      final detail = await _procurementRemote.fetchInvoice(
        int.parse(invoice.serverId!),
      );
      final payments = detail['payments'] as List?;
      if (payments == null) return false;
      final match = payments
          .whereType<Map<String, dynamic>>()
          .where(
            (p) =>
                (p['amount'] as num?)?.toInt() == amount &&
                (p['paymentDate'] as num?)?.toInt() == paymentDate,
          )
          .firstOrNull;
      if (match == null) return false;
      final serverId = match['id']?.toString();
      if (serverId == null) return false;
      await _procurementLocal.linkPaymentServerSync(
        shopId: shopId,
        localId: localPayId,
        serverId: serverId,
        version: match['version'] as int? ?? 1,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isDuplicateProcurementKeyError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('supplier_invoices') ||
        lower.contains('invoice_number') ||
        lower.contains('purchase_receipts') ||
        lower.contains('receipt_number') ||
        lower.contains('supplier_payments') ||
        lower.contains('purchase_orders') ||
        (_isDuplicateKeyError(lower) &&
            (lower.contains('invoice') ||
                lower.contains('receipt') ||
                lower.contains('supplier') ||
                lower.contains('purchase')));
  }

  bool _isDuplicateKeyError(String lower) {
    return lower.contains('duplicate key') ||
        lower.contains('unique constraint') ||
        lower.contains('23505') ||
        lower.contains('unique constraint failed');
  }

  Future<bool> _processStockTransfer(
    int shopId,
    SyncQueueData item,
    Map<String, dynamic> payload,
  ) async {
    final local = await _stockTransferLocal.findTransfer(item.recordId);
    if (local == null) return true;

    switch (item.operation) {
      case SyncOperation.create:
        if (await _stockTransferLocal.findTransferServerId(local.id) != null) {
          return true;
        }

        if (local.sourceShopId != shopId) {
          if (await _adoptRemoteTransferIfPossible(local)) return true;
          // Ne pas bloquer la boutique courante : la création relève de la source.
          return true;
        }

        final destinationShopId =
            (payload['destinationShopId'] as num?)?.toInt() ??
                local.destinationShopId;
        final destServerId =
            await _stockTransferLocal.resolveShopServerId(destinationShopId);
        if (destServerId == null) {
          await _queue.markDeferred(
            item.id,
            'Boutique destination non synchronisée.',
          );
          return false;
        }

        final items = (payload['items'] as List?) ?? [];
        final remoteItems = <Map<String, dynamic>>[];
        for (final raw in items) {
          if (raw is! Map<String, dynamic>) continue;
          final productId = raw['productId'] as int;
          final serverProductId = await _stockTransferLocal.resolveProductServerId(
            shopId,
            productId,
          );
          if (serverProductId == null) {
            await _queue.markDeferred(
              item.id,
              'Produit #$productId non synchronisé.',
            );
            return false;
          }
          remoteItems.add({
            'productId': serverProductId,
            'quantityRequested': raw['quantityRequested'],
          });
        }

        if (remoteItems.isEmpty) {
          await _queue.markDeferred(
            item.id,
            'Aucun produit synchronisé pour ce transfert.',
          );
          return false;
        }

        try {
          return await _createStockTransferOnRemote(
            local: local,
            destServerId: destServerId,
            remoteItems: remoteItems,
          );
        } on Failure catch (error) {
          if (_isDuplicateReferenceError(error.message)) {
            final resolved = await _resolveStockTransferDuplicateCreate(
              local: local,
              destServerId: destServerId,
              remoteItems: remoteItems,
            );
            if (resolved) return true;

            await _queue.markDeferred(
              item.id,
              'Référence « ${local.reference} » déjà utilisée côté serveur. '
              'Synchronisez depuis l\'onglet Transferts ou recréez le transfert.',
            );
            return false;
          }
          if (await _adoptRemoteTransferIfPossible(local)) return true;
          rethrow;
        }

      case SyncOperation.validate:
        final validateServerId =
            await _stockTransferLocal.findTransferServerId(local.id);
        if (validateServerId == null) {
          await _queue.markDeferred(item.id, 'Transfert non synchronisé.');
          return false;
        }
        final validateServerInt = int.parse(validateServerId);
        final ensured = await _stockTransferCloudSync.ensureValidatedOnServer(
          localTransferId: local.id,
          serverTransferId: validateServerInt,
        );
        if (!ensured.ok) {
          await _queue.markDeferred(
            item.id,
            ensured.deferReason ?? 'Validation du transfert impossible côté serveur.',
          );
          return false;
        }
        return true;

      case SyncOperation.submit:
        final submitServerId =
            await _stockTransferLocal.findTransferServerId(local.id);
        if (submitServerId == null) {
          await _queue.markDeferred(item.id, 'Transfert non synchronisé.');
          return false;
        }
        final submitServerInt = int.parse(submitServerId);
        final submitRemote = await _stockTransferCloudSync.runOnSourceShop(
          transfer: local,
          action: () => _stockTransferRemote.submitTransfer(submitServerInt),
        );
        if (submitRemote == null) {
          await _queue.markDeferred(
            item.id,
            'Soumission impossible côté serveur.',
          );
          return false;
        }
        await _stockTransferLocal.applyRemoteStockTransferSnapshot(
          local.id,
          submitRemote,
        );
        return true;

      case SyncOperation.approve:
        final approveServerId =
            await _stockTransferLocal.findTransferServerId(local.id);
        if (approveServerId == null) {
          await _queue.markDeferred(item.id, 'Transfert non synchronisé.');
          return false;
        }
        final approveServerInt = int.parse(approveServerId);
        final ensuredApprove =
            await _stockTransferCloudSync.ensureValidatedOnServer(
          localTransferId: local.id,
          serverTransferId: approveServerInt,
        );
        if (!ensuredApprove.ok) {
          await _queue.markDeferred(
            item.id,
            ensuredApprove.deferReason ??
                'Approbation du transfert impossible côté serveur.',
          );
          return false;
        }
        return true;

      case SyncOperation.send:
        final serverId = await _stockTransferLocal.findTransferServerId(local.id);
        if (serverId == null) {
          final pendingCreate = await _queue.findPendingOperation(
            shopId: shopId,
            entityTable: SyncEntityTable.stockTransfers,
            recordId: local.id,
            operation: SyncOperation.create,
          );
          await _queue.markDeferred(
            item.id,
            pendingCreate?.lastError ??
                'Création du transfert en attente côté serveur.',
          );
          return false;
        }

        final pendingCreate = await _queue.findPendingOperation(
          shopId: shopId,
          entityTable: SyncEntityTable.stockTransfers,
          recordId: local.id,
          operation: SyncOperation.create,
        );
        if (pendingCreate != null) {
          await _queue.markDeferred(
            item.id,
            pendingCreate.lastError ??
                'Création du transfert requise avant l\'expédition côté serveur.',
          );
          return false;
        }

        final pendingValidate = await _queue.findPendingOperation(
          shopId: shopId,
          entityTable: SyncEntityTable.stockTransfers,
          recordId: local.id,
          operation: SyncOperation.validate,
        );
        if (pendingValidate != null) {
          await _queue.markDeferred(
            item.id,
            pendingValidate.lastError ??
                'Validation du transfert requise avant l\'expédition côté serveur.',
          );
          return false;
        }

        final sendServerInt = int.parse(serverId);
        final ensured = await _stockTransferCloudSync.ensureValidatedOnServer(
          localTransferId: local.id,
          serverTransferId: sendServerInt,
          requireShippable: true,
        );
        if (!ensured.ok) {
          await _queue.markDeferred(
            item.id,
            ensured.deferReason ??
                'Validation du transfert requise avant l\'expédition côté serveur.',
          );
          return false;
        }

        if (ensured.alreadyComplete) {
          if (ensured.remote != null) {
            await _stockTransferLocal.applyRemoteStockTransferSnapshot(
              local.id,
              ensured.remote!,
            );
          }
          return true;
        }

        final remoteDetail = ensured.remote ??
            await _stockTransferCloudSync.runOnSourceShop(
              transfer: local,
              action: () => _stockTransferRemote.fetchTransfer(sendServerInt),
            );
        if (remoteDetail == null) {
          await _queue.markDeferred(
            item.id,
            'Boutique source non synchronisée.',
          );
          return false;
        }
        final remoteItems = (remoteDetail['items'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];

        final shipQuantities = _stockTransferLocal.resolveShipQuantitiesForSync(
          transfer: local,
          payload: payload,
        );

        var shipMapping = await _stockTransferLocal.buildRemoteItemMapping(
          transfer: local,
          remoteItems: remoteItems,
        );

        if (shipMapping.isEmpty) {
          await _stockTransferLocal.linkRemoteTransferItemsFromSnapshot(
            local.id,
            remoteItems,
          );
          shipMapping = await _stockTransferLocal.buildRemoteItemMapping(
            transfer: local,
            remoteItems: remoteItems,
          );
          if (shipMapping.isEmpty) {
            await _queue.markDeferred(
              item.id,
              await _stockTransferLocal.describeUnmappedTransferItems(
                transfer: local,
                remoteItems: remoteItems,
              ),
            );
            return false;
          }
        }

        final shipBody = StockTransferRemotePayloads.shipBody(
          label: payload['label'] as String? ?? 'Expédition',
          notes: payload['notes'] as String?,
          driverName: payload['driverName'] as String?,
          vehiclePlate: payload['vehiclePlate'] as String?,
          quantitiesByItemId: shipQuantities,
          remoteItems: shipMapping,
        );
        if ((shipBody['items'] as List?)?.isEmpty ?? true) {
          await _queue.markDeferred(
            item.id,
            'Quantités d\'expédition introuvables pour la synchronisation.',
          );
          return false;
        }

        try {
          final remote = await _stockTransferCloudSync.runOnSourceShop(
                transfer: local,
                action: () => _stockTransferRemote.shipTransfer(
                  sendServerInt,
                  shipBody,
                ),
              ) ??
              (throw const NetworkFailure('Boutique source non synchronisée.'));
          await _stockTransferLocal.applyRemoteStockTransferSnapshot(local.id, remote);
          return true;
        } on Failure catch (error) {
          if (StockTransferCloudSyncHelper.isNotReadyToShipError(error.message)) {
            final refreshed = await _stockTransferCloudSync.runOnSourceShop(
              transfer: local,
              action: () => _stockTransferRemote.fetchTransfer(sendServerInt),
            );
            final status = refreshed?['status'] as String? ?? '';
            if (status == StockTransferStatus.draft) {
              final revalidate =
                  await _stockTransferCloudSync.ensureValidatedOnServer(
                localTransferId: local.id,
                serverTransferId: sendServerInt,
                requireShippable: true,
              );
              if (!revalidate.ok) {
                await _queue.markDeferred(
                  item.id,
                  revalidate.deferReason ??
                      'Validation du transfert requise avant l\'expédition côté serveur.',
                );
                return false;
              }
              if (revalidate.alreadyComplete) {
                if (revalidate.remote != null) {
                  await _stockTransferLocal.applyRemoteStockTransferSnapshot(
                    local.id,
                    revalidate.remote!,
                  );
                }
                return true;
              }
              final remote = await _stockTransferCloudSync.runOnSourceShop(
                    transfer: local,
                    action: () => _stockTransferRemote.shipTransfer(
                      sendServerInt,
                      shipBody,
                    ),
                  ) ??
                  (throw const NetworkFailure('Boutique source non synchronisée.'));
              await _stockTransferLocal.applyRemoteStockTransferSnapshot(
                local.id,
                remote,
              );
              return true;
            }
            if (StockTransferCloudSyncHelper.isPostShipStatus(status)) {
              await _stockTransferLocal.applyRemoteStockTransferSnapshot(
                local.id,
                refreshed!,
              );
              return true;
            }
          }
          if (_isInsufficientReservationError(error.message)) {
            await _queue.markDeferred(
              item.id,
              '${error.message} Relancez une synchronisation complète du stock '
              '(produits et lots) depuis la boutique source, puis réessayez.',
            );
            return false;
          }
          if (_isWrongShopShipError(error.message)) {
            await _queue.markDeferred(
              item.id,
              '${error.message} Ouvrez la boutique source du transfert pour synchroniser.',
            );
            return false;
          }
          if (StockTransferCloudSyncHelper.isNotReadyToShipError(error.message)) {
            await _queue.markDeferred(
              item.id,
              'Le transfert doit être validé côté cloud avant expédition. '
              'Depuis la boutique source, synchronisez d\'abord produits/lots puis relancez.',
            );
            return false;
          }
          await _queue.markDeferred(item.id, error.message);
          return false;
        }

      case SyncOperation.receive:
        var transfer = local;
        final serverId = await _stockTransferLocal.findTransferServerId(transfer.id);
        if (serverId == null) {
          await _queue.markDeferred(item.id, 'Transfert non synchronisé.');
          return false;
        }

        final receiveServerInt = int.parse(serverId);
        final sourceServerId =
            await _stockTransferLocal.resolveShopServerId(transfer.sourceShopId);

        Map<String, dynamic>? remoteDetail;
        if (sourceServerId != null) {
          try {
            remoteDetail = await ApiClient.runScopedToServerShop(
              sourceServerId,
              () => _stockTransferRemote.fetchTransfer(receiveServerInt),
            );
          } on Failure {
            remoteDetail = null;
          }
        }

        var destServerId = remoteDetail != null
            ? StockTransferLocalDatasource.destinationServerIdFromRemote(
                remoteDetail,
              )
            : null;
        destServerId ??=
            await _stockTransferLocal.resolveShopServerId(transfer.destinationShopId);

        if (remoteDetail == null && destServerId != null) {
          try {
            remoteDetail = await ApiClient.runScopedToServerShop(
              destServerId,
              () => _stockTransferRemote.fetchTransfer(receiveServerInt),
            );
          } on Failure {
            remoteDetail = null;
          }
        }

        destServerId = remoteDetail != null
            ? StockTransferLocalDatasource.destinationServerIdFromRemote(
                  remoteDetail,
                ) ??
                destServerId
            : destServerId;

        if (destServerId == null) {
          await _queue.markDeferred(
            item.id,
            'Boutique destination non synchronisée.',
          );
          return false;
        }

        if (remoteDetail != null) {
          await _stockTransferLocal.reconcileTransferShopsFromRemote(
            transfer.id,
            remoteDetail,
          );
          final refreshed = await _stockTransferLocal.findTransfer(transfer.id);
          if (refreshed != null) {
            transfer = refreshed;
          }
        }

        try {
          return await ApiClient.runScopedToServerShop(destServerId, () async {
            final remoteDetailFinal = remoteDetail ??
                await _stockTransferRemote.fetchTransfer(receiveServerInt);
            final remoteItems = (remoteDetailFinal['items'] as List?)
                    ?.whereType<Map<String, dynamic>>()
                    .toList() ??
                [];

            final quantitiesByItemId =
                _stockTransferLocal.resolveReceiveQuantitiesForSync(
              transfer: transfer,
              payload: payload,
            );

            var mapping = await _stockTransferLocal.buildRemoteItemMapping(
              transfer: transfer,
              remoteItems: remoteItems,
            );

            if (mapping.isEmpty) {
              await _stockTransferLocal.linkRemoteTransferItemsFromSnapshot(
                transfer.id,
                remoteItems,
              );
              mapping = await _stockTransferLocal.buildRemoteItemMapping(
                transfer: transfer,
                remoteItems: remoteItems,
              );
              if (mapping.isEmpty) {
                await _queue.markDeferred(
                  item.id,
                  await _stockTransferLocal.describeUnmappedTransferItems(
                    transfer: transfer,
                    remoteItems: remoteItems,
                  ),
                );
                return false;
              }
            }

            final productSetups = (payload['productSetups'] as List?)
                    ?.whereType<Map<String, dynamic>>()
                    .toList() ??
                [];
            final refusalsByItemId = <int, StockTransferReceiveRefusal>{};
            final rawRefusals = payload['refusalsByItemId'];
            if (rawRefusals is Map) {
              for (final entry in rawRefusals.entries) {
                final itemId = int.tryParse(entry.key.toString());
                final value = entry.value;
                if (itemId == null || value is! Map) continue;
                final quantity = (value['quantity'] as num?)?.toInt() ?? 0;
                final reason = value['reason'] as String?;
                final resolution = value['resolution'] as String?;
                if (quantity <= 0 ||
                    reason == null ||
                    reason.isEmpty ||
                    resolution == null ||
                    resolution.isEmpty) {
                  continue;
                }
                refusalsByItemId[itemId] = StockTransferReceiveRefusal(
                  quantity: quantity,
                  reason: reason,
                  resolution: resolution,
                );
              }
            }
            final localShipmentId = (payload['shipmentId'] as num?)?.toInt();
            final remoteShipments = (remoteDetailFinal['shipments'] as List?)
                    ?.whereType<Map<String, dynamic>>()
                    .toList() ??
                [];
            final remoteShipmentId = localShipmentId != null
                ? _stockTransferLocal.resolveRemoteShipmentId(
                    transfer: transfer,
                    localShipmentId: localShipmentId,
                    remoteShipments: remoteShipments,
                  )
                : null;

            final receiveBody = StockTransferRemotePayloads.receiveBody(
              quantitiesByItemId: quantitiesByItemId,
              remoteItems: mapping,
              refusalsByItemId: refusalsByItemId,
              productSetups: productSetups,
              shipmentId: remoteShipmentId,
            );
            if ((receiveBody['items'] as List?)?.isEmpty ?? true) {
              await _queue.markDeferred(
                item.id,
                'Quantités de réception introuvables pour la synchronisation.',
              );
              return false;
            }

            final remote = await _stockTransferRemote.receiveTransfer(
              receiveServerInt,
              receiveBody,
            );
            await _stockTransferLocal.applyRemoteStockTransferSnapshot(
              transfer.id,
              remote,
            );
            return true;
          });
        } on Failure catch (error) {
          if (_isWrongShopReceiveError(error.message)) {
            await _queue.markDeferred(
              item.id,
              '${error.message} Relancez une synchronisation complète depuis '
              'l\'onglet Transferts.',
            );
            return false;
          }
          await _queue.markDeferred(item.id, error.message);
          return false;
        }

      case SyncOperation.cancel:
        final cancelServerId =
            await _stockTransferLocal.findTransferServerId(local.id);
        if (cancelServerId == null) {
          await _stockTransferLocal.purgePendingTransferSyncOps(local.id);
          return true;
        }
        try {
          await _stockTransferRemote.cancelTransfer(int.parse(cancelServerId));
        } on Failure catch (error) {
          if (_isTransferAlreadyCancelledError(error.message)) {
            return true;
          }
          await _queue.markDeferred(item.id, error.message);
          return false;
        }
        return true;

      case SyncOperation.close:
        if (local.sourceShopId != shopId) {
          return true;
        }
        final closeServerId =
            await _stockTransferLocal.findTransferServerId(local.id);
        if (closeServerId == null) {
          await _queue.markDeferred(item.id, 'Transfert non synchronisé.');
          return false;
        }
        try {
          final remote = await _stockTransferCloudSync.runOnSourceShop(
                transfer: local,
                action: () => _stockTransferRemote.closeTransfer(
                  int.parse(closeServerId),
                  StockTransferRemotePayloads.closeBody(
                    notes: payload['notes'] as String?,
                  ),
                ),
              ) ??
              (throw const NetworkFailure('Boutique source non synchronisée.'));
          await _stockTransferLocal.applyRemoteStockTransferSnapshot(
            local.id,
            remote,
          );
          return true;
        } on Failure catch (error) {
          await _queue.markDeferred(item.id, error.message);
          return false;
        }

      case SyncOperation.resolveDiscrepancy:
        if (local.sourceShopId != shopId) {
          return true;
        }
        final resolveServerId =
            await _stockTransferLocal.findTransferServerId(local.id);
        if (resolveServerId == null) {
          await _queue.markDeferred(item.id, 'Transfert non synchronisé.');
          return false;
        }
        final localItemId = (payload['itemId'] as num?)?.toInt();
        if (localItemId == null) {
          await _queue.markDeferred(item.id, 'Article d\'écart introuvable.');
          return false;
        }
        try {
          return await _stockTransferCloudSync.runOnSourceShop(
                transfer: local,
                action: () async {
                  final remoteDetail = await _stockTransferRemote.fetchTransfer(
                    int.parse(resolveServerId),
                  );
                  final remoteItems = (remoteDetail['items'] as List?)
                          ?.whereType<Map<String, dynamic>>()
                          .toList() ??
                      [];
                  final mapping = await _stockTransferLocal.buildRemoteItemMapping(
                    transfer: local,
                    remoteItems: remoteItems,
                  );
                  final remoteItemId = mapping
                      .where((row) => row['localItemId'] == localItemId)
                      .map((row) => row['remoteItemId'] as int?)
                      .whereType<int>()
                      .firstOrNull;
                  if (remoteItemId == null) {
                    await _queue.markDeferred(
                      item.id,
                      'Article local non mappé côté serveur.',
                    );
                    return false;
                  }

                  final remote = await _stockTransferRemote.resolveDiscrepancy(
                    int.parse(resolveServerId),
                    StockTransferRemotePayloads.resolveDiscrepancyBody(
                      itemId: remoteItemId,
                      quantity: (payload['quantity'] as num?)?.toInt() ?? 0,
                      reason: payload['reason'] as String? ?? 'loss',
                      resolution:
                          payload['resolution'] as String? ?? 'write_off',
                      notes: payload['notes'] as String?,
                    ),
                  );
                  await _stockTransferLocal.applyRemoteStockTransferSnapshot(
                    local.id,
                    remote,
                  );
                  return true;
                },
              ) ??
              false;
        } on Failure catch (error) {
          await _queue.markDeferred(item.id, error.message);
          return false;
        }
    }
    return true;
  }

  Future<bool> _createStockTransferOnRemote({
    required StockTransfer local,
    required int destServerId,
    required List<Map<String, dynamic>> remoteItems,
  }) async {
    final remote = await _stockTransferRemote.createTransfer(
      StockTransferRemotePayloads.createBody(
        destinationShopId: destServerId,
        reference: local.reference,
        notes: local.notes,
        items: remoteItems,
      ),
    );
    await _applyCreatedRemoteTransfer(local.id, remote);
    return true;
  }

  Future<void> _applyCreatedRemoteTransfer(
    int localTransferId,
    Map<String, dynamic> remote,
  ) async {
    await _stockTransferLocal.applyRemoteStockTransferSnapshot(
      localTransferId,
      remote,
    );
    final createdItems = (remote['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (createdItems.isNotEmpty) {
      await _stockTransferLocal.linkRemoteTransferItemsFromSnapshot(
        localTransferId,
        createdItems,
      );
    }
  }

  Future<bool> _resolveStockTransferDuplicateCreate({
    required StockTransfer local,
    required int destServerId,
    required List<Map<String, dynamic>> remoteItems,
  }) async {
    final existing = await _findRemoteTransferByReference(local.reference);
    if (existing != null) {
      final existingDest = StockTransferLocalDatasource.coerceRemoteInt(
        existing['destinationShopId'],
      );
      if (existingDest == destServerId) {
        final linked = await _linkLocalTransferToRemoteDetail(
          localTransferId: local.id,
          existing: existing,
        );
        if (linked) return true;
      }
    }

    try {
      final newRef = await _stockTransferLocal.allocateUniqueReference(
        local.sourceShopId,
      );
      if (newRef.isEmpty) return false;

      await _stockTransferLocal.updateTransferReference(local.id, newRef);
      final refreshed = await _stockTransferLocal.findTransfer(local.id);
      if (refreshed == null) return false;

      return await _createStockTransferOnRemote(
        local: refreshed,
        destServerId: destServerId,
        remoteItems: remoteItems,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _adoptRemoteTransferIfPossible(StockTransfer local) async {
    final existing = await _findRemoteTransferByReference(local.reference);
    if (existing == null) return false;
    return _linkLocalTransferToRemoteDetail(
      localTransferId: local.id,
      existing: existing,
    );
  }

  Future<bool> _linkLocalTransferToRemoteDetail({
    required int localTransferId,
    required Map<String, dynamic> existing,
  }) async {
    final existingId = StockTransferLocalDatasource.coerceRemoteInt(existing['id']);
    Map<String, dynamic> detail = existing;
    if (existingId != null) {
      try {
        detail = await _stockTransferRemote.fetchTransfer(existingId);
      } catch (_) {}
    }

    await _stockTransferLocal.applyRemoteStockTransferSnapshot(
      localTransferId,
      detail,
    );
    final remoteItems = (detail['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (remoteItems.isNotEmpty) {
      await _stockTransferLocal.linkRemoteTransferItemsFromSnapshot(
        localTransferId,
        remoteItems,
      );
    }
    return true;
  }

  Future<Map<String, dynamic>?> _findRemoteTransferByReference(
    String reference,
  ) async {
    final outgoing = await _stockTransferRemote.fetchOutgoing();
    for (final raw in outgoing) {
      if (raw['reference'] == reference) return raw;
    }
    final incoming = await _stockTransferRemote.fetchIncoming();
    for (final raw in incoming) {
      if (raw['reference'] == reference) return raw;
    }
    return null;
  }

  bool _isDuplicateReferenceError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('stock_transfers_reference') ||
        (lower.contains('reference') &&
            (lower.contains('existe') ||
                lower.contains('duplicate') ||
                lower.contains('unique')));
  }

  bool _isTransferAlreadyCancelledError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('introuvable') ||
        lower.contains('not found') ||
        lower.contains('ne peut pas être annulé') ||
        lower.contains('deja annul') ||
        lower.contains('déjà annul') ||
        lower.contains('cancelled');
  }

  bool _isInsufficientReservationError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('réservations insuffisantes') ||
        lower.contains('reservations insuffisantes');
  }

  bool _isWrongShopShipError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('boutique source');
  }

  bool _isWrongShopReceiveError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('boutique destination');
  }
}

enum _QueueItemOutcome { processed, deferred, conflict, failed }

Future<List<R>> _mapWithConcurrency<T, R>(
  List<T> items, {
  required int maxConcurrent,
  required Future<R> Function(T item) mapper,
}) async {
  if (items.isEmpty) return const [];
  final limit = maxConcurrent < 1 ? 1 : maxConcurrent.clamp(1, items.length);
  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final i = nextIndex++;
      if (i >= items.length) return;
      results[i] = await mapper(items[i]);
    }
  }

  await Future.wait(List.generate(limit, (_) => worker()));
  return results.cast<R>();
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
