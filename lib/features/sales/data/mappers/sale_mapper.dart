import '../../../../../core/database/app_database.dart' as db;
import '../../domain/entities/sale_entities.dart';

class SaleMapper {
  const SaleMapper._();

  static SaleType saleTypeFromCode(String? code) {
    return code == 'quick' ? SaleType.quick : SaleType.standard;
  }

  static SaleStatus statusFromCode(String? code) {
    return code == 'cancelled' ? SaleStatus.cancelled : SaleStatus.completed;
  }

  static SaleListRow listRowFromRow(db.Sale sale, {String? customerName}) {
    return SaleListRow(
      id: sale.id,
      receiptNumber: sale.receiptNumber,
      saleType: saleTypeFromCode(sale.saleType),
      totalAmount: sale.totalAmount,
      status: statusFromCode(sale.status),
      createdAt: sale.createdAt,
      customerName: customerName,
    );
  }

  static SaleItem itemFromRow(db.SaleItem row) {
    return SaleItem(
      id: row.id,
      productId: row.productId,
      productName: row.productName,
      quantity: row.quantity.round(),
      unitPrice: row.unitPrice,
      lineTotal: row.lineTotal,
      unitCost: row.unitCost,
      discountAmount: row.discountAmount,
    );
  }

  static Sale saleFromRow({
    required db.Sale sale,
    String? customerName,
    List<SaleItem> items = const [],
  }) {
    return Sale(
      id: sale.id,
      shopId: sale.shopId,
      userId: sale.userId,
      receiptNumber: sale.receiptNumber,
      saleType: saleTypeFromCode(sale.saleType),
      customerId: sale.customerId,
      customerName: customerName,
      subtotal: sale.subtotal,
      discountAmount: sale.discountAmount,
      totalAmount: sale.totalAmount,
      amountPaid: sale.amountPaid,
      amountCash: sale.amountCash,
      amountMomo: sale.amountMomo,
      amountCredit: sale.amountCredit,
      paymentMethod: PaymentMethodX.fromCode(sale.paymentMethod),
      status: statusFromCode(sale.status),
      note: sale.note,
      createdAt: sale.createdAt,
      updatedAt: sale.updatedAt,
      cancelledAt: sale.cancelledAt,
      cancelledByUserId: sale.cancelledByUserId,
      cancelReason: sale.cancelReason,
      items: items,
    );
  }

  static SaleCustomerOption customerFromRow(db.Customer row) {
    return SaleCustomerOption(
      id: row.id,
      name: row.name,
      phone: row.phone,
    );
  }
}
