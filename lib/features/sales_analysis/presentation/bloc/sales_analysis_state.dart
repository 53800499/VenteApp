part of 'sales_analysis_bloc.dart';

enum SalesAnalysisStatus { initial, loading, loaded, failure }

class SalesAnalysisState extends Equatable {
  const SalesAnalysisState({
    this.status = SalesAnalysisStatus.initial,
    this.query = const SalesAnalysisQuery(),
    this.periodLabel,
    this.products = const [],
    this.employees = const [],
    this.customers = const [],
    this.tabIndex = 0,
    this.errorMessage,
  });

  final SalesAnalysisStatus status;
  final SalesAnalysisQuery query;
  final String? periodLabel;
  final List<ProductSalesSummary> products;
  final List<EmployeePricePerformance> employees;
  final List<CustomerSalesInsight> customers;
  final int tabIndex;
  final String? errorMessage;

  SalesAnalysisState copyWith({
    SalesAnalysisStatus? status,
    SalesAnalysisQuery? query,
    String? periodLabel,
    List<ProductSalesSummary>? products,
    List<EmployeePricePerformance>? employees,
    List<CustomerSalesInsight>? customers,
    int? tabIndex,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SalesAnalysisState(
      status: status ?? this.status,
      query: query ?? this.query,
      periodLabel: periodLabel ?? this.periodLabel,
      products: products ?? this.products,
      employees: employees ?? this.employees,
      customers: customers ?? this.customers,
      tabIndex: tabIndex ?? this.tabIndex,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        query,
        periodLabel,
        products,
        employees,
        customers,
        tabIndex,
        errorMessage,
      ];
}
