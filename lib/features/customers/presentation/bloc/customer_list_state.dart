part of 'customer_list_bloc.dart';

enum CustomerListStatus { initial, loading, ready, failure }

class CustomerListState extends Equatable {
  const CustomerListState({
    this.status = CustomerListStatus.initial,
    this.customers = const [],
    this.filters = const CustomerListFilters(),
    this.debtorsOverview,
    this.showDebtorsOverview = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final CustomerListStatus status;
  final List<Customer> customers;
  final CustomerListFilters filters;
  final DebtorsOverview? debtorsOverview;
  final bool showDebtorsOverview;
  final bool isRefreshing;
  final String? errorMessage;

  CustomerListState copyWith({
    CustomerListStatus? status,
    List<Customer>? customers,
    CustomerListFilters? filters,
    DebtorsOverview? debtorsOverview,
    bool? showDebtorsOverview,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomerListState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      filters: filters ?? this.filters,
      debtorsOverview: debtorsOverview ?? this.debtorsOverview,
      showDebtorsOverview: showDebtorsOverview ?? this.showDebtorsOverview,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        customers,
        filters,
        debtorsOverview,
        showDebtorsOverview,
        isRefreshing,
        errorMessage,
      ];
}
