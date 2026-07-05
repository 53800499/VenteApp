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
    this.categories = const [],
    this.margins = const MarginSummary.empty(),
    this.priceDeviations = const [],
    this.trends = const SalesTrendSummary.empty(),
    this.tabIndex = 0,
    this.errorMessage,
  });

  final SalesAnalysisStatus status;
  final SalesAnalysisQuery query;
  final String? periodLabel;
  final List<ProductSalesSummary> products;
  final List<EmployeePricePerformance> employees;
  final List<CustomerSalesInsight> customers;
  final List<CategorySalesSummary> categories;
  final MarginSummary margins;
  final List<PriceDeviationLine> priceDeviations;
  final SalesTrendSummary trends;
  final int tabIndex;
  final String? errorMessage;

  SalesAnalysisState copyWith({
    SalesAnalysisStatus? status,
    SalesAnalysisQuery? query,
    String? periodLabel,
    List<ProductSalesSummary>? products,
    List<EmployeePricePerformance>? employees,
    List<CustomerSalesInsight>? customers,
    List<CategorySalesSummary>? categories,
    MarginSummary? margins,
    List<PriceDeviationLine>? priceDeviations,
    SalesTrendSummary? trends,
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
      categories: categories ?? this.categories,
      margins: margins ?? this.margins,
      priceDeviations: priceDeviations ?? this.priceDeviations,
      trends: trends ?? this.trends,
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
        categories,
        margins,
        priceDeviations,
        trends,
        tabIndex,
        errorMessage,
      ];
}
