part of 'expenses_bloc.dart';

sealed class ExpensesEvent extends Equatable {
  const ExpensesEvent();
  @override
  List<Object?> get props => [];
}

class ExpensesLoadRequested extends ExpensesEvent {
  const ExpensesLoadRequested();
}

class ExpensesFilterChanged extends ExpensesEvent {
  const ExpensesFilterChanged(this.filters);
  final ExpenseListFilters filters;
  @override
  List<Object?> get props => [filters];
}

class ExpenseCreateSubmitted extends ExpensesEvent {
  const ExpenseCreateSubmitted(this.input);
  final CreateExpenseInput input;
  @override
  List<Object?> get props => [input];
}

class ExpenseDeleteRequested extends ExpensesEvent {
  const ExpenseDeleteRequested(this.expenseId);
  final int expenseId;
  @override
  List<Object?> get props => [expenseId];
}
