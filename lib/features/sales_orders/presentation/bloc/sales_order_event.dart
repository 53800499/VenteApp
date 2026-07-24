part of 'sales_order_bloc.dart';

sealed class SalesOrderEvent extends Equatable {
  const SalesOrderEvent();

  @override
  List<Object?> get props => [];
}

class SalesOrderListRequested extends SalesOrderEvent {
  const SalesOrderListRequested({this.status, this.search});

  final SalesOrderStatus? status;
  final String? search;

  @override
  List<Object?> get props => [status, search];
}

class SalesOrderDetailRequested extends SalesOrderEvent {
  const SalesOrderDetailRequested(this.orderId);

  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

class SalesOrderCreateRequested extends SalesOrderEvent {
  const SalesOrderCreateRequested({
    required this.customerId,
    required this.items,
    this.notes,
  });

  final int customerId;
  final List<SalesOrderLineInput> items;
  final String? notes;

  @override
  List<Object?> get props => [customerId, items, notes];
}

class SalesOrderConfirmRequested extends SalesOrderEvent {
  const SalesOrderConfirmRequested(this.orderId);

  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

class SalesOrderPrepareRequested extends SalesOrderEvent {
  const SalesOrderPrepareRequested(this.orderId);

  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

class SalesOrderCancelRequested extends SalesOrderEvent {
  const SalesOrderCancelRequested(this.orderId, {this.reason});

  final int orderId;
  final String? reason;

  @override
  List<Object?> get props => [orderId, reason];
}

class SalesOrderCloseRequested extends SalesOrderEvent {
  const SalesOrderCloseRequested(this.orderId);

  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

class SalesOrderDeliverRequested extends SalesOrderEvent {
  const SalesOrderDeliverRequested({
    required this.orderId,
    required this.lines,
    required this.paymentMethod,
    this.notes,
    this.driverName,
    this.vehiclePlate,
    this.remainingReason,
    this.amountCash,
    this.amountMomo,
    this.amountCredit,
  });

  final int orderId;
  final List<DeliveryLineInput> lines;
  final PaymentMethod paymentMethod;
  final String? notes;
  final String? driverName;
  final String? vehiclePlate;
  final SalesOrderRemainingReason? remainingReason;
  final int? amountCash;
  final int? amountMomo;
  final int? amountCredit;

  @override
  List<Object?> get props => [
        orderId,
        lines,
        paymentMethod,
        notes,
        driverName,
        vehiclePlate,
        remainingReason,
      ];
}

class SalesOrderReportRequested extends SalesOrderEvent {
  const SalesOrderReportRequested({
    required this.fromMs,
    required this.toMs,
  });

  final int fromMs;
  final int toMs;

  @override
  List<Object?> get props => [fromMs, toMs];
}

class SalesOrderFeedbackCleared extends SalesOrderEvent {
  const SalesOrderFeedbackCleared();
}
