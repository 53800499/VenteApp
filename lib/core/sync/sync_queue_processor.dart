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
import '../database/app_database.dart' hide Sale, Expense;
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
    required ExpensesLocalDatasource expensesLocal,
    required ExpensesRemoteDatasource expensesRemote,
    required CashSessionsLocalDatasource cashSessionsLocal,
    required CashSessionsRemoteDatasource cashSessionsRemote,
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
        _cashSessionsRemote = cashSessionsRemote;

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
        SyncEntityTable.expenses => 5,
        SyncEntityTable.cashSessions => 6,
        SyncEntityTable.cashMovements => 7,
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
      case SyncEntityTable.expenses:
        return _processExpense(shopId, item, payload);
      case SyncEntityTable.cashSessions:
        return _processCashSession(shopId, item, payload);
      case SyncEntityTable.cashMovements:
        return _processCashMovement(shopId, item, payload);
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

    final serverId =
        await _cashSessionsLocal.findSessionServerId(shopId, item.recordId);

    switch (item.operation) {
      case SyncOperation.cashSessionOpen:
        if (serverId != null) return true;
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

      case SyncOperation.cashSessionClose:
        var remoteId = serverId;
        if (remoteId == null) {
          final opened = await _cashSessionsRemote.openSession(
            OpenCashSessionApiRequest(
              openingCash: session.openingCash,
              openingMomo: session.openingMomo,
            ),
          );
          remoteId = '${opened.id}';
          await _cashSessionsLocal.updateSessionServerSync(
            sessionId: session.id,
            serverId: remoteId,
          );
        }
        await _cashSessionsRemote.closeSession(
          int.parse(remoteId),
          CloseCashSessionApiRequest(
            countedCash: (payload['countedCash'] as num?)?.toInt() ??
                session.countedCash ??
                0,
            countedMomo: (payload['countedMomo'] as num?)?.toInt() ??
                session.countedMomo ??
                0,
            closingNote: payload['closingNote'] as String? ?? session.closingNote,
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
        await _cashSessionsLocal.updateSessionServerSync(
          sessionId: session.id,
          serverId: remoteId,
        );
        return true;

      default:
        throw ValidationFailure(
          'Opération caisse inconnue : ${item.operation}',
        );
    }
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
