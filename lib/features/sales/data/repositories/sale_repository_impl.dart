import '../../../../core/database/app_database.dart' as db;
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/time.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/services/sale_validation_service.dart';
import '../datasources/local/sales_local_datasource.dart';

class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl({
    required SalesLocalDatasource local,
    SaleValidationService? validation,
  }) : _local = local,
       _validation = validation ?? const SaleValidationService();

  final SalesLocalDatasource _local;
  final SaleValidationService _validation;

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

    final timestamp = nowMs();
    final receiptNumber = await _local.nextReceiptNumber(shopId, timestamp);

    return _local.createStandardSale(
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

    final timestamp = nowMs();
    final receiptNumber = await _local.nextReceiptNumber(shopId, timestamp);

    return _local.createQuickSale(
      shopId: shopId,
      userId: userId,
      receiptNumber: receiptNumber,
      totals: totals,
      paymentMethod: input.payment.method,
      note: input.note,
      timestamp: timestamp,
    );
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

    final now = nowMs();
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
  }
}
