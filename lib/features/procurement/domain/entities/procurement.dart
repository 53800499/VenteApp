import 'package:equatable/equatable.dart';

enum PurchaseOrderStatus {
  draft,
  validated,
  sent,
  partiallyReceived,
  received,
  cancelled
}

enum SupplierInvoiceStatus {
  unpaid,
  partiallyPaid,
  paid
}

enum PurchasePaymentMethod {
  cash,
  mtnMomo,
  moovMoney,
  card,
  transfer,
  check
}

abstract final class PurchaseReceiptType {
  static const fromOrder = 'from_order';
  static const direct = 'direct';
}

class Supplier extends Equatable {
  const Supplier({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.serverId,
  });

  final int id;
  final int shopId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final int version;
  final String? serverId;

  @override
  List<Object?> get props => [
        id,
        shopId,
        name,
        phone,
        email,
        address,
        isActive,
        createdAt,
        updatedAt,
        version,
        serverId,
      ];
}

class PurchaseOrder extends Equatable {
  const PurchaseOrder({
    required this.id,
    required this.shopId,
    required this.supplierId,
    this.supplierName,
    required this.number,
    required this.status,
    required this.orderedAt,
    this.expectedAt,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.notes,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.serverId,
    this.items,
  });

  final int id;
  final int shopId;
  final int supplierId;
  final String? supplierName;
  final String number;
  final PurchaseOrderStatus status;
  final int orderedAt;
  final int? expectedAt;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  final String? notes;
  final int createdBy;
  final String? createdByName;
  final int createdAt;
  final int updatedAt;
  final int version;
  final String? serverId;
  final List<PurchaseOrderItem>? items;

  @override
  List<Object?> get props => [
        id,
        shopId,
        supplierId,
        supplierName,
        number,
        status,
        orderedAt,
        expectedAt,
        subtotal,
        discount,
        tax,
        total,
        notes,
        createdBy,
        createdByName,
        createdAt,
        updatedAt,
        version,
        serverId,
        items,
      ];
}

class PurchaseOrderItem extends Equatable {
  const PurchaseOrderItem({
    required this.id,
    required this.shopId,
    required this.purchaseOrderId,
    required this.productId,
    this.productName,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
    required this.discount,
    required this.tax,
    required this.subtotal,
    required this.version,
    this.serverId,
  });

  final int id;
  final int shopId;
  final int purchaseOrderId;
  final int productId;
  final String? productName;
  final int quantityOrdered;
  final int quantityReceived;
  final int unitCost;
  final int discount;
  final int tax;
  final int subtotal;
  final int version;
  final String? serverId;

  @override
  List<Object?> get props => [
        id,
        shopId,
        purchaseOrderId,
        productId,
        productName,
        quantityOrdered,
        quantityReceived,
        unitCost,
        discount,
        tax,
        subtotal,
        version,
        serverId,
      ];
}

class PurchaseReceipt extends Equatable {
  const PurchaseReceipt({
    required this.id,
    required this.shopId,
    this.purchaseOrderId,
    required this.supplierId,
    this.supplierName,
    this.receiptType = PurchaseReceiptType.fromOrder,
    required this.receiptNumber,
    required this.receivedAt,
    required this.receivedBy,
    this.receivedByName,
    this.notes,
    required this.version,
    this.serverId,
    this.items,
  });

  final int id;
  final int shopId;
  final int? purchaseOrderId;
  final int supplierId;
  final String? supplierName;
  final String receiptType;
  final String receiptNumber;
  final int receivedAt;
  final int receivedBy;
  final String? receivedByName;
  final String? notes;
  final int version;
  final String? serverId;
  final List<PurchaseReceiptItem>? items;

  @override
  List<Object?> get props => [
        id,
        shopId,
        purchaseOrderId,
        supplierId,
        supplierName,
        receiptType,
        receiptNumber,
        receivedAt,
        receivedBy,
        receivedByName,
        notes,
        version,
        serverId,
        items,
      ];
}

class PurchaseReceiptItem extends Equatable {
  const PurchaseReceiptItem({
    required this.id,
    required this.shopId,
    required this.purchaseReceiptId,
    this.purchaseOrderItemId,
    required this.productId,
    this.productName,
    required this.quantityReceived,
    required this.unitCost,
    this.batchNumber,
    this.expiryDate,
    required this.version,
    this.serverId,
  });

  final int id;
  final int shopId;
  final int purchaseReceiptId;
  final int? purchaseOrderItemId;
  final int productId;
  final String? productName;
  final int quantityReceived;
  final int unitCost;
  final String? batchNumber;
  final int? expiryDate;
  final int version;
  final String? serverId;

  @override
  List<Object?> get props => [
        id,
        shopId,
        purchaseReceiptId,
        purchaseOrderItemId,
        productId,
        productName,
        quantityReceived,
        unitCost,
        batchNumber,
        expiryDate,
        version,
        serverId,
      ];
}

class SupplierInvoice extends Equatable {
  const SupplierInvoice({
    required this.id,
    required this.shopId,
    this.purchaseOrderId,
    required this.invoiceNumber,
    required this.supplierId,
    this.supplierName,
    required this.invoiceDate,
    this.dueDate,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.serverId,
    this.payments,
  });

  final int id;
  final int shopId;
  final int? purchaseOrderId;
  final String invoiceNumber;
  final int supplierId;
  final String? supplierName;
  final int invoiceDate;
  final int? dueDate;
  final int subtotal;
  final int tax;
  final int total;
  final SupplierInvoiceStatus status;
  final int createdAt;
  final int updatedAt;
  final int version;
  final String? serverId;
  final List<SupplierPayment>? payments;

  @override
  List<Object?> get props => [
        id,
        shopId,
        purchaseOrderId,
        invoiceNumber,
        supplierId,
        supplierName,
        invoiceDate,
        dueDate,
        subtotal,
        tax,
        total,
        status,
        createdAt,
        updatedAt,
        version,
        serverId,
        payments,
      ];
}

class SupplierPayment extends Equatable {
  const SupplierPayment({
    required this.id,
    required this.shopId,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    this.reference,
    required this.createdAt,
    required this.version,
    this.serverId,
  });

  final int id;
  final int shopId;
  final int invoiceId;
  final int amount;
  final PurchasePaymentMethod paymentMethod;
  final int paymentDate;
  final String? reference;
  final int createdAt;
  final int version;
  final String? serverId;

  @override
  List<Object?> get props => [
        id,
        shopId,
        invoiceId,
        amount,
        paymentMethod,
        paymentDate,
        reference,
        createdAt,
        version,
        serverId,
      ];
}

class PurchaseOrderHistory extends Equatable {
  const PurchaseOrderHistory({
    required this.id,
    required this.shopId,
    required this.purchaseOrderId,
    required this.action,
    required this.performedBy,
    this.performedByName,
    required this.performedAt,
    this.details,
  });

  final int id;
  final int shopId;
  final int purchaseOrderId;
  final String action;
  final int performedBy;
  final String? performedByName;
  final int performedAt;
  final String? details;

  @override
  List<Object?> get props => [
        id,
        shopId,
        purchaseOrderId,
        action,
        performedBy,
        performedByName,
        performedAt,
        details,
      ];
}

extension PurchaseOrderStatusExtension on PurchaseOrderStatus {
  String get label => switch (this) {
        PurchaseOrderStatus.draft => 'Brouillon',
        PurchaseOrderStatus.validated => 'Validé',
        PurchaseOrderStatus.sent => 'Envoyé au fournisseur',
        PurchaseOrderStatus.partiallyReceived => 'Reçu partiellement',
        PurchaseOrderStatus.received => 'Reçu totalement',
        PurchaseOrderStatus.cancelled => 'Annulé',
      };
}

extension SupplierInvoiceStatusExtension on SupplierInvoiceStatus {
  String get label => switch (this) {
        SupplierInvoiceStatus.unpaid => 'Non payée',
        SupplierInvoiceStatus.partiallyPaid => 'Payée partiellement',
        SupplierInvoiceStatus.paid => 'Payée',
      };
}

extension PurchasePaymentMethodExtension on PurchasePaymentMethod {
  String get label => switch (this) {
        PurchasePaymentMethod.cash => 'Espèces',
        PurchasePaymentMethod.mtnMomo => 'MTN Mobile Money',
        PurchasePaymentMethod.moovMoney => 'Moov Money',
        PurchasePaymentMethod.card => 'Carte Bancaire',
        PurchasePaymentMethod.transfer => 'Virement',
        PurchasePaymentMethod.check => 'Chèque',
      };

  /// Valeur attendue par l'API backend (snake_case).
  String get apiValue => switch (this) {
        PurchasePaymentMethod.mtnMomo => 'mtn_momo',
        PurchasePaymentMethod.moovMoney => 'moov_money',
        _ => name,
      };
}

