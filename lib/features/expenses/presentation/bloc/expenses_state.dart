part of 'expenses_bloc.dart';

enum ExpensesStatus { initial, loading, loaded, refreshing, failure }

class ExpensesState extends Equatable {
  const ExpensesState({
    this.status = ExpensesStatus.initial,
    this.summary,
    this.expenses = const [],
    this.categories = const [],
    this.filters = const ExpenseListFilters(),
    this.errorMessage,
  });

  final ExpensesStatus status;
  final ExpenseSummary? summary;
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final ExpenseListFilters filters;
  final String? errorMessage;

  ExpensesState copyWith({
    ExpensesStatus? status,
    ExpenseSummary? summary,
    List<Expense>? expenses,
    List<ExpenseCategory>? categories,
    ExpenseListFilters? filters,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      expenses: expenses ?? this.expenses,
      categories: categories ?? this.categories,
      filters: filters ?? this.filters,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, summary, expenses, categories, filters, errorMessage];
}
