part of 'procurement_bloc.dart';

enum ProcurementStatus { initial, loading, loaded, refreshing, failure }

class ProcurementState extends Equatable {
  const ProcurementState({
    this.status = ProcurementStatus.initial,
    this.suppliers = const [],
    this.purchaseOrders = const [],
    this.selectedOrder,
    this.orderHistory = const [],
    this.orderReceipts = const [],
    this.invoices = const [],
    this.directReceipts = const [],
    this.selectedDirectReceipt,
    this.selectedDirectReceiptInvoice,
    this.selectedInvoice,
    this.reportSummary,
    this.errorMessage,
  });

  final ProcurementStatus status;
  final List<Supplier> suppliers;
  final List<PurchaseOrder> purchaseOrders;
  final PurchaseOrder? selectedOrder;
  final List<PurchaseOrderHistory> orderHistory;
  final List<PurchaseReceipt> orderReceipts;
  final List<SupplierInvoice> invoices;
  final List<PurchaseReceipt> directReceipts;
  final PurchaseReceipt? selectedDirectReceipt;
  final SupplierInvoice? selectedDirectReceiptInvoice;
  final SupplierInvoice? selectedInvoice;
  final ProcurementReportSummary? reportSummary;
  final String? errorMessage;

  ProcurementState copyWith({
    ProcurementStatus? status,
    List<Supplier>? suppliers,
    List<PurchaseOrder>? purchaseOrders,
    PurchaseOrder? selectedOrder,
    List<PurchaseOrderHistory>? orderHistory,
    List<PurchaseReceipt>? orderReceipts,
    List<SupplierInvoice>? invoices,
    List<PurchaseReceipt>? directReceipts,
    PurchaseReceipt? selectedDirectReceipt,
    SupplierInvoice? selectedDirectReceiptInvoice,
    SupplierInvoice? selectedInvoice,
    ProcurementReportSummary? reportSummary,
    String? errorMessage,
    bool clearError = false,
    bool clearSelectedOrder = false,
    bool clearSelectedDirectReceipt = false,
    bool clearSelectedInvoice = false,
    bool clearReport = false,
  }) {
    return ProcurementState(
      status: status ?? this.status,
      suppliers: suppliers ?? this.suppliers,
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      selectedOrder: clearSelectedOrder ? null : (selectedOrder ?? this.selectedOrder),
      orderHistory: orderHistory ?? this.orderHistory,
      orderReceipts: orderReceipts ?? this.orderReceipts,
      invoices: invoices ?? this.invoices,
      directReceipts: directReceipts ?? this.directReceipts,
      selectedDirectReceipt: clearSelectedDirectReceipt
          ? null
          : (selectedDirectReceipt ?? this.selectedDirectReceipt),
      selectedDirectReceiptInvoice: clearSelectedDirectReceipt
          ? null
          : (selectedDirectReceiptInvoice ?? this.selectedDirectReceiptInvoice),
      selectedInvoice: clearSelectedInvoice ? null : (selectedInvoice ?? this.selectedInvoice),
      reportSummary: clearReport ? null : (reportSummary ?? this.reportSummary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        suppliers,
        purchaseOrders,
        selectedOrder,
        orderHistory,
        orderReceipts,
        invoices,
        directReceipts,
        selectedDirectReceipt,
        selectedDirectReceiptInvoice,
        selectedInvoice,
        reportSummary,
        errorMessage,
      ];
}
