part of 'procurement_bloc.dart';

sealed class ProcurementEvent extends Equatable {
  const ProcurementEvent();
  @override
  List<Object?> get props => [];
}

// Suppliers
class ProcurementSuppliersLoadRequested extends ProcurementEvent {
  const ProcurementSuppliersLoadRequested();
}

class ProcurementSupplierCreateSubmitted extends ProcurementEvent {
  const ProcurementSupplierCreateSubmitted({
    required this.name,
    this.phone,
    this.email,
    this.address,
  });
  final String name;
  final String? phone;
  final String? email;
  final String? address;

  @override
  List<Object?> get props => [name, phone, email, address];
}

class ProcurementSupplierUpdateSubmitted extends ProcurementEvent {
  const ProcurementSupplierUpdateSubmitted({
    required this.id,
    this.name,
    this.phone,
    this.email,
    this.address,
    this.isActive,
  });
  final int id;
  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final bool? isActive;

  @override
  List<Object?> get props => [id, name, phone, email, address, isActive];
}

// Purchase Orders
class ProcurementOrdersLoadRequested extends ProcurementEvent {
  const ProcurementOrdersLoadRequested({this.supplierId, this.status});
  final int? supplierId;
  final PurchaseOrderStatus? status;

  @override
  List<Object?> get props => [supplierId, status];
}

class ProcurementOrderDetailLoadRequested extends ProcurementEvent {
  const ProcurementOrderDetailLoadRequested(this.poId);
  final int poId;

  @override
  List<Object?> get props => [poId];
}

class ProcurementOrderCreateSubmitted extends ProcurementEvent {
  const ProcurementOrderCreateSubmitted({
    required this.supplierId,
    required this.number,
    required this.orderedAt,
    this.expectedAt,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.notes,
    required this.items,
  });
  final int supplierId;
  final String number;
  final int orderedAt;
  final int? expectedAt;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  final String? notes;
  final List<Map<String, dynamic>> items;

  @override
  List<Object?> get props => [
        supplierId,
        number,
        orderedAt,
        expectedAt,
        subtotal,
        discount,
        tax,
        total,
        notes,
        items,
      ];
}

class ProcurementOrderUpdateSubmitted extends ProcurementEvent {
  const ProcurementOrderUpdateSubmitted({
    required this.poId,
    required this.supplierId,
    required this.number,
    required this.orderedAt,
    this.expectedAt,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.notes,
    required this.items,
  });
  final int poId;
  final int supplierId;
  final String number;
  final int orderedAt;
  final int? expectedAt;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  final String? notes;
  final List<Map<String, dynamic>> items;

  @override
  List<Object?> get props => [
        poId,
        supplierId,
        number,
        orderedAt,
        expectedAt,
        subtotal,
        discount,
        tax,
        total,
        notes,
        items,
      ];
}

class ProcurementReportLoadRequested extends ProcurementEvent {
  const ProcurementReportLoadRequested();
}

class ProcurementOrderValidateRequested extends ProcurementEvent {
  const ProcurementOrderValidateRequested(this.poId);
  final int poId;

  @override
  List<Object?> get props => [poId];
}

class ProcurementOrderSendRequested extends ProcurementEvent {
  const ProcurementOrderSendRequested(this.poId);
  final int poId;

  @override
  List<Object?> get props => [poId];
}

class ProcurementOrderCancelRequested extends ProcurementEvent {
  const ProcurementOrderCancelRequested({required this.poId, this.reason});
  final int poId;
  final String? reason;

  @override
  List<Object?> get props => [poId, reason];
}

class ProcurementOrderReceiveSubmitted extends ProcurementEvent {
  const ProcurementOrderReceiveSubmitted({
    required this.poId,
    required this.receiptNumber,
    required this.receivedAt,
    this.notes,
    required this.items,
  });
  final int poId;
  final String receiptNumber;
  final int receivedAt;
  final String? notes;
  final List<Map<String, dynamic>> items;

  @override
  List<Object?> get props => [poId, receiptNumber, receivedAt, notes, items];
}

class ProcurementDirectProcurementSubmitted extends ProcurementEvent {
  const ProcurementDirectProcurementSubmitted({
    required this.supplierId,
    required this.receiptNumber,
    required this.receivedAt,
    this.notes,
    required this.items,
    this.recordSupplierInvoice = true,
    this.invoiceNumber,
    this.paymentAmount,
    this.paymentMethod = PurchasePaymentMethod.cash,
    this.paymentReference,
  });

  final int supplierId;
  final String receiptNumber;
  final int receivedAt;
  final String? notes;
  final List<Map<String, dynamic>> items;
  final bool recordSupplierInvoice;
  final String? invoiceNumber;
  final int? paymentAmount;
  final PurchasePaymentMethod paymentMethod;
  final String? paymentReference;

  @override
  List<Object?> get props => [supplierId, receiptNumber, receivedAt, notes, items, recordSupplierInvoice, invoiceNumber, paymentAmount, paymentMethod, paymentReference];
}

class ProcurementDirectReceiptsLoadRequested extends ProcurementEvent {
  const ProcurementDirectReceiptsLoadRequested({this.supplierId});
  final int? supplierId;

  @override
  List<Object?> get props => [supplierId];
}

class ProcurementDirectReceiptDetailLoadRequested extends ProcurementEvent {
  const ProcurementDirectReceiptDetailLoadRequested(this.receiptId);
  final int receiptId;

  @override
  List<Object?> get props => [receiptId];
}

// Invoices & Payments
class ProcurementInvoicesLoadRequested extends ProcurementEvent {
  const ProcurementInvoicesLoadRequested({this.supplierId});
  final int? supplierId;

  @override
  List<Object?> get props => [supplierId];
}

class ProcurementInvoiceDetailLoadRequested extends ProcurementEvent {
  const ProcurementInvoiceDetailLoadRequested(this.invoiceId);
  final int invoiceId;

  @override
  List<Object?> get props => [invoiceId];
}

class ProcurementInvoiceCreateSubmitted extends ProcurementEvent {
  const ProcurementInvoiceCreateSubmitted({
    this.poId,
    required this.invoiceNumber,
    required this.supplierId,
    required this.invoiceDate,
    this.dueDate,
    required this.subtotal,
    required this.tax,
    required this.total,
  });
  final int? poId;
  final String invoiceNumber;
  final int supplierId;
  final int invoiceDate;
  final int? dueDate;
  final int subtotal;
  final int tax;
  final int total;

  @override
  List<Object?> get props => [
        poId,
        invoiceNumber,
        supplierId,
        invoiceDate,
        dueDate,
        subtotal,
        tax,
        total,
      ];
}

class ProcurementPaymentRecordSubmitted extends ProcurementEvent {
  const ProcurementPaymentRecordSubmitted({
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    this.reference,
  });
  final int invoiceId;
  final int amount;
  final PurchasePaymentMethod paymentMethod;
  final int paymentDate;
  final String? reference;

  @override
  List<Object?> get props => [invoiceId, amount, paymentMethod, paymentDate, reference];
}
