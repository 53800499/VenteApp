import 'package:equatable/equatable.dart';

class ProcurementReportSummary extends Equatable {
  const ProcurementReportSummary({
    required this.pendingOrderCount,
    required this.overdueOrderCount,
    required this.receivedOrderCount,
    required this.cancelledOrderCount,
    required this.pendingOrderAmount,
    required this.receivedOrderAmount,
    required this.unpaidInvoiceCount,
    required this.unpaidInvoiceAmount,
    required this.topSuppliers,
    required this.topProducts,
  });

  final int pendingOrderCount;
  final int overdueOrderCount;
  final int receivedOrderCount;
  final int cancelledOrderCount;
  final int pendingOrderAmount;
  final int receivedOrderAmount;
  final int unpaidInvoiceCount;
  final int unpaidInvoiceAmount;
  final List<ProcurementSupplierStat> topSuppliers;
  final List<ProcurementProductStat> topProducts;

  @override
  List<Object?> get props => [
        pendingOrderCount,
        overdueOrderCount,
        receivedOrderCount,
        cancelledOrderCount,
        pendingOrderAmount,
        receivedOrderAmount,
        unpaidInvoiceCount,
        unpaidInvoiceAmount,
        topSuppliers,
        topProducts,
      ];
}

class ProcurementSupplierStat extends Equatable {
  const ProcurementSupplierStat({
    required this.supplierName,
    required this.orderCount,
    required this.totalAmount,
  });

  final String supplierName;
  final int orderCount;
  final int totalAmount;

  @override
  List<Object?> get props => [supplierName, orderCount, totalAmount];
}

class ProcurementProductStat extends Equatable {
  const ProcurementProductStat({
    required this.productName,
    required this.quantityOrdered,
    required this.totalCost,
  });

  final String productName;
  final int quantityOrdered;
  final int totalCost;

  @override
  List<Object?> get props => [productName, quantityOrdered, totalCost];
}
