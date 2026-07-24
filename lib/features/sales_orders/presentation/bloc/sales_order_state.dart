part of 'sales_order_bloc.dart';

enum SalesOrderViewStatus { initial, loading, ready, failure }

class SalesOrderState extends Equatable {
  const SalesOrderState({
    this.status = SalesOrderViewStatus.initial,
    this.orders = const [],
    this.selected,
    this.lastDelivery,
    this.filterStatus,
    this.search = '',
    this.saving = false,
    this.detailLoading = false,
    this.reportLoading = false,
    this.report,
    this.errorMessage,
    this.successMessage,
  });

  final SalesOrderViewStatus status;
  final List<SalesOrder> orders;
  final SalesOrder? selected;
  final SalesOrderDelivery? lastDelivery;
  final SalesOrderStatus? filterStatus;
  final String search;
  final bool saving;
  final bool detailLoading;
  final bool reportLoading;
  final SalesOrderFulfillmentReport? report;
  final String? errorMessage;
  final String? successMessage;

  SalesOrderState copyWith({
    SalesOrderViewStatus? status,
    List<SalesOrder>? orders,
    SalesOrder? selected,
    SalesOrderDelivery? lastDelivery,
    SalesOrderStatus? filterStatus,
    String? search,
    bool? saving,
    bool? detailLoading,
    bool? reportLoading,
    SalesOrderFulfillmentReport? report,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearSelected = false,
    bool clearReport = false,
  }) {
    return SalesOrderState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      selected: clearSelected ? null : (selected ?? this.selected),
      lastDelivery: lastDelivery ?? this.lastDelivery,
      filterStatus: filterStatus ?? this.filterStatus,
      search: search ?? this.search,
      saving: saving ?? this.saving,
      detailLoading: detailLoading ?? this.detailLoading,
      reportLoading: reportLoading ?? this.reportLoading,
      report: clearReport ? null : (report ?? this.report),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        orders,
        selected,
        lastDelivery,
        filterStatus,
        search,
        saving,
        detailLoading,
        reportLoading,
        report,
        errorMessage,
        successMessage,
      ];
}
