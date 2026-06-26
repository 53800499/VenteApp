part of 'sale_list_bloc.dart';

enum SaleListStatus { initial, loading, loaded, failure }

class SaleListState extends Equatable {
  const SaleListState({
    this.status = SaleListStatus.initial,
    this.sales = const [],
    this.filters = const SaleListFilters(),
    this.errorMessage,
    this.isRefreshing = false,
  });

  final SaleListStatus status;
  final List<SaleListRow> sales;
  final SaleListFilters filters;
  final String? errorMessage;
  final bool isRefreshing;

  SaleListState copyWith({
    SaleListStatus? status,
    List<SaleListRow>? sales,
    SaleListFilters? filters,
    String? errorMessage,
    bool clearError = false,
    bool? isRefreshing,
  }) {
    return SaleListState(
      status: status ?? this.status,
      sales: sales ?? this.sales,
      filters: filters ?? this.filters,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props =>
      [status, sales, filters, errorMessage, isRefreshing];
}
