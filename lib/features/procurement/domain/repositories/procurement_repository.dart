import '../../domain/entities/procurement.dart';
import '../../domain/entities/procurement_report_entities.dart';

abstract class ProcurementRepository {
  // Suppliers
  Future<List<Supplier>> listSuppliers({required int shopId});
  Future<Supplier> createSupplier({
    required int shopId,
    required String name,
    String? phone,
    String? email,
    String? address,
  });
  Future<Supplier> updateSupplier({
    required int shopId,
    required int id,
    String? name,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
  });

  // Purchase Orders
  Future<List<PurchaseOrder>> listPurchaseOrders({
    required int shopId,
    int? supplierId,
    PurchaseOrderStatus? status,
  });
  Future<PurchaseOrder?> findPurchaseOrder({
    required int shopId,
    required int id,
  });
  Future<PurchaseOrder> createPurchaseOrder({
    required int shopId,
    required int userId,
    required int supplierId,
    required String number,
    required int orderedAt,
    int? expectedAt,
    required int subtotal,
    required int discount,
    required int tax,
    required int total,
    String? notes,
    required List<Map<String, dynamic>> items, // Contains product details
  });
  Future<PurchaseOrder> updatePurchaseOrder({
    required int shopId,
    required int userId,
    required int poId,
    String? number,
    int? supplierId,
    int? orderedAt,
    int? expectedAt,
    int? subtotal,
    int? discount,
    int? tax,
    int? total,
    String? notes,
    List<Map<String, dynamic>>? items,
  });
  Future<void> validatePurchaseOrder({
    required int shopId,
    required int userId,
    required int poId,
  });
  Future<void> sendPurchaseOrder({
    required int shopId,
    required int userId,
    required int poId,
  });
  Future<void> cancelPurchaseOrder({
    required int shopId,
    required int userId,
    required int poId,
    String? reason,
  });
  Future<PurchaseReceipt> receiveItems({
    required int shopId,
    required int poId,
    required int userId,
    required String receiptNumber,
    required int receivedAt,
    String? notes,
    required List<Map<String, dynamic>> items, // Contains receipt item details
  });
  Future<PurchaseReceipt> recordDirectProcurement({
    required int shopId,
    required int userId,
    required int supplierId,
    required String receiptNumber,
    required int receivedAt,
    String? notes,
    required List<Map<String, dynamic>> items,
    bool recordSupplierInvoice = true,
    String? invoiceNumber,
    int? paymentAmount,
    PurchasePaymentMethod paymentMethod = PurchasePaymentMethod.cash,
    String? paymentReference,
  });
  Future<String> nextDirectReceiptNumber({required int shopId});
  Future<String> nextOrderReceiptNumber({required int shopId});
  Future<String> nextPurchaseOrderNumber({required int shopId});
  Future<String> nextSupplierInvoiceNumber({required int shopId});
  Future<List<PurchaseReceipt>> listDirectReceipts({
    required int shopId,
    int? supplierId,
    int limit = 50,
  });
  Future<PurchaseReceipt?> findReceipt({
    required int shopId,
    required int id,
  });
  Future<SupplierInvoice?> findInvoiceForDirectReceipt({
    required int shopId,
    required PurchaseReceipt receipt,
  });
  Future<List<PurchaseReceipt>> listReceipts({
    required int shopId,
    required int poId,
  });
  Future<List<PurchaseOrderHistory>> listHistory({
    required int shopId,
    required int poId,
  });

  // Invoices & Payments
  Future<List<SupplierInvoice>> listInvoices({
    required int shopId,
    int? supplierId,
  });
  Future<SupplierInvoice?> findInvoice({
    required int shopId,
    required int id,
  });
  Future<SupplierInvoice> createInvoice({
    required int shopId,
    int? poId,
    required String invoiceNumber,
    required int supplierId,
    required int invoiceDate,
    int? dueDate,
    required int subtotal,
    required int tax,
    required int total,
  });
  Future<SupplierPayment> recordPayment({
    required int shopId,
    required int userId,
    required int invoiceId,
    required int amount,
    required PurchasePaymentMethod paymentMethod,
    required int paymentDate,
    String? reference,
  });

  Future<ProcurementReportSummary> getReportSummary({required int shopId});

  Future<void> syncFromRemote({required int shopId, bool force = false});
}
