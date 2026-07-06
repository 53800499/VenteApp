import 'dart:async';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/services/sale_validation_service.dart';
import '../datasources/local/sales_local_datasource.dart';
import '../datasources/remote/sales_remote_datasource.dart';
import '../models/sale_api_models.dart';

class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl({
    required SalesLocalDatasource local,
    required SalesRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
    SaleValidationService? validation,
    LocalWriteSyncRecorder? recorder,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _validation = validation ?? const SaleValidationService(),
        _recorder = recorder;

  final SalesLocalDatasource _local;
  final SalesRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;
  final SaleValidationService _validation;
  final LocalWriteSyncRecorder? _recorder;

  @override
  Future<List<SaleListRow>> listSales({
    required int shopId,
    SaleListFilters filters = const SaleListFilters(),
  }) {
    return _local.listSales(shopId: shopId, filters: filters);
  }

  @override
  Future<Sale> getSale({
    required int shopId,
    required int saleId,
  }) async {
    final sale = await _local.findSale(shopId, saleId);
    if (sale == null) {
      throw const NotFoundFailure('Vente introuvable.');
    }
    return sale;
  }

  @override
  Future<List<SaleCustomerOption>> listCustomers({
    required int shopId,
    String search = '',
  }) {
    return _local.listCustomers(shopId: shopId, search: search);
  }

  @override
  Future<Sale> createStandardSale({
    required int shopId,
    required int userId,
    required CreateStandardSaleInput input,
    int? serverShopId,
    int? serverUserId,
  }) async {
    _validation.assertStandardCart(input.items);

    final snapshots = <({
      db.Product product,
      SaleLineDraft line,
      int lineTotal,
    })>[];

    for (final line in input.items) {
      final product = await _local.findProduct(shopId, line.productId);
      if (product == null) {
        throw NotFoundFailure('Produit #${line.productId} introuvable.');
      }

      final unitPrice =
          line.unitPrice > 0 ? line.unitPrice : product.priceSell;
      final resolvedLine = SaleLineDraft(
        productId: line.productId,
        quantity: line.quantity,
        unitPrice: unitPrice,
        lineDiscountAmount: line.lineDiscountAmount,
      );

      _validation.assertStockAvailable(
        product.name,
        product.quantityInStock,
        resolvedLine.quantity,
      );

      snapshots.add((
        product: product,
        line: resolvedLine,
        lineTotal: _validation.computeLineTotal(resolvedLine),
      ));
    }

    final totals = _validation.computeTotals(
      snapshots.map((s) => s.line).toList(),
      input.discountAmount,
      input.payment,
    );
    _validation.assertCustomerForCredit(
      input.customerId,
      totals.amountCredit,
    );

    if (input.customerId != null) {
      final customer = await _local.findCustomer(shopId, input.customerId!);
      if (customer == null) {
        throw const NotFoundFailure('Client introuvable dans cette boutique.');
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final receiptNumber = await _local.nextReceiptNumber(shopId, timestamp);

    final sale = await _local.createStandardSale(
      shopId: shopId,
      userId: userId,
      receiptNumber: receiptNumber,
      customerId: input.customerId,
      totals: totals,
      paymentMethod: input.payment.method,
      snapshots: snapshots,
      note: input.note,
      timestamp: timestamp,
    );

    unawaited(
      _finalizeStandardSaleSync(
        shopId: shopId,
        sale: sale,
        input: input,
        snapshots: snapshots,
        totals: totals,
        customerId: input.customerId,
      ),
    );

    return sale;
  }

  Future<void> _finalizeStandardSaleSync({
    required int shopId,
    required Sale sale,
    required CreateStandardSaleInput input,
    required List<({
      db.Product product,
      SaleLineDraft line,
      int lineTotal,
    })> snapshots,
    required ComputedSaleTotals totals,
    required int? customerId,
  }) async {
    await _trySyncStandardSale(
      shopId: shopId,
      sale: sale,
      input: input,
      snapshots: snapshots,
      totals: totals,
      customerId: customerId,
    );
    await _recordSaleIfPending(shopId: shopId, saleId: sale.id);
  }

  Future<void> _recordSaleIfPending({
    required int shopId,
    required int saleId,
  }) async {
    final serverId = await _local.findSaleServerId(shopId, saleId);
    if (serverId == null) {
      await _recorder?.recordSaleStandard(shopId: shopId, saleId: saleId);
    }
  }

  Future<void> _trySyncStandardSale({
    required int shopId,
    required Sale sale,
    required CreateStandardSaleInput input,
    required List<({
      db.Product product,
      SaleLineDraft line,
      int lineTotal,
    })> snapshots,
    required ComputedSaleTotals totals,
    required int? customerId,
  }) async {
    final productIds = input.items.map((l) => l.productId).toList();
    if (!await _local.allProductsHaveServerId(shopId, productIds)) {
      await _local.markSaleSyncPending(sale.id);
      return;
    }

    try {
      await _apiGuard.ensureReady();

      int? remoteCustomerId;
      if (customerId != null) {
        final customer = await _local.findCustomer(shopId, customerId);
        remoteCustomerId = int.tryParse(customer?.serverId ?? '');
        if (totals.amountCredit > 0 && remoteCustomerId == null) {
          await _local.markSaleSyncPending(sale.id);
          return;
        }
      }

      final remote = await _remote.createStandardSale(
        CreateStandardSaleApiRequest(
          items: snapshots
              .map(
                (snap) => SaleLineApiRequest(
                  productId: int.parse(snap.product.serverId!),
                  quantity: snap.line.quantity,
                  unitPrice: snap.line.unitPrice,
                  lineDiscountAmount: snap.line.lineDiscountAmount,
                ),
              )
              .toList(),
          discountAmount: input.discountAmount,
          customerId: remoteCustomerId,
          payment: SalePaymentApiRequest(
            method: input.payment.method,
            amountCash: totals.amountCash,
            amountMomo: totals.amountMomo,
            amountCredit: totals.amountCredit,
          ),
          note: input.note,
        ),
      );

      await _local.markSaleSynced(
        saleId: sale.id,
        serverId: '${remote.id}',
      );
    } on Failure {
      await _local.markSaleSyncPending(sale.id);
    } catch (_) {
      await _local.markSaleSyncPending(sale.id);
    }
  }

  @override
  Future<Sale> createQuickSale({
    required int shopId,
    required int userId,
    required CreateQuickSaleInput input,
  }) async {
    final totals = _validation.computeQuickTotals(
      input.totalAmount,
      input.payment,
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final receiptNumber = await _local.nextReceiptNumber(shopId, timestamp);

    final sale = await _local.createQuickSale(
      shopId: shopId,
      userId: userId,
      receiptNumber: receiptNumber,
      totals: totals,
      paymentMethod: input.payment.method,
      note: input.note,
      timestamp: timestamp,
    );

    await _recorder?.recordSaleQuick(
      shopId: shopId,
      saleId: sale.id,
      payload: {
        'totalAmount': input.totalAmount,
        'payment': SalePaymentApiRequest(
          method: input.payment.method,
          amountCash: totals.amountCash,
          amountMomo: totals.amountMomo,
          amountCredit: totals.amountCredit,
        ).toJson(),
        if (input.note != null && input.note!.isNotEmpty) 'note': input.note,
      },
    );

    return sale;
  }

  @override
  Future<Sale> convertQuickSaleToStandard({
    required int shopId,
    required int userId,
    required int saleId,
    required ConvertQuickSaleInput input,
  }) async {
    final sale = await _local.findSale(shopId, saleId);
    if (sale == null) {
      throw const NotFoundFailure('Vente introuvable.');
    }
    _validation.assertConvertibleQuickSale(sale);
    _validation.assertStandardCart(input.items);

    final snapshots = <({
      db.Product product,
      SaleLineDraft line,
      int lineTotal,
    })>[];

    for (final line in input.items) {
      final product = await _local.findProduct(shopId, line.productId);
      if (product == null) {
        throw NotFoundFailure('Produit #${line.productId} introuvable.');
      }

      final unitPrice =
          line.unitPrice > 0 ? line.unitPrice : product.priceSell;
      final resolvedLine = SaleLineDraft(
        productId: line.productId,
        quantity: line.quantity,
        unitPrice: unitPrice,
        lineDiscountAmount: line.lineDiscountAmount,
      );

      _validation.assertStockAvailable(
        product.name,
        product.quantityInStock,
        resolvedLine.quantity,
      );

      snapshots.add((
        product: product,
        line: resolvedLine,
        lineTotal: _validation.computeLineTotal(resolvedLine),
      ));
    }

    final totals = _validation.computeTotals(
      snapshots.map((s) => s.line).toList(),
      input.discountAmount,
      PaymentDraft(
        method: sale.paymentMethod,
        amountCash: sale.amountCash,
        amountMomo: sale.amountMomo,
        amountCredit: sale.amountCredit,
      ),
    );
    _validation.assertConversionTotalsMatch(
      totals: totals,
      quickSaleTotal: sale.totalAmount,
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final converted = await _local.convertQuickSaleToStandard(
      shopId: shopId,
      userId: userId,
      saleId: saleId,
      totals: totals,
      snapshots: snapshots,
      timestamp: timestamp,
    );

    unawaited(
      _finalizeStandardSaleSync(
        shopId: shopId,
        sale: converted,
        input: CreateStandardSaleInput(
          items: input.items,
          discountAmount: input.discountAmount,
          payment: PaymentDraft(
            method: sale.paymentMethod,
            amountCash: sale.amountCash,
            amountMomo: sale.amountMomo,
            amountCredit: sale.amountCredit,
          ),
        ),
        snapshots: snapshots,
        totals: totals,
        customerId: sale.customerId,
      ),
    );

    return converted;
  }

  @override
  Future<void> cancelSale({
    required int shopId,
    required int userId,
    required int saleId,
    required String reason,
    required bool isOwner,
  }) async {
    if (!isOwner) {
      throw const UnauthorizedFailure(
        'Seul le patron peut annuler une vente.',
      );
    }

    _validation.assertCancelReason(reason);

    final sale = await _local.findSale(shopId, saleId);
    if (sale == null) {
      throw const NotFoundFailure('Vente introuvable.');
    }
    if (sale.isCancelled) {
      throw const ConflictFailure('Cette vente est déjà annulée.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _validation.assertCancelWindow(sale.createdAt, now);

    final debt = await _local.findDebtBySale(shopId, saleId);
    if (debt != null && debt.amountPaid > 0) {
      throw const ConflictFailure(
        'Impossible d\'annuler : un paiement partiel a été enregistré sur la dette.',
      );
    }

    await _local.cancelSale(
      shopId: shopId,
      userId: userId,
      saleId: saleId,
      reason: reason.trim(),
      timestamp: now,
    );

    await _recorder?.recordSaleCancel(
      shopId: shopId,
      saleId: saleId,
      reason: reason.trim(),
    );
  }

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    await _apiGuard.ensureReady();
    final userId = await _local.resolveDefaultUserId(shopId);
    if (userId == null) return;

    final remoteSales = await _remote.listSales();
    for (final sale in remoteSales) {
      await _local.upsertSaleListItemFromRemote(
        shopId: shopId,
        userId: userId,
        remote: sale,
      );
    }
  }
}
