import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/expense_entities.dart';
import '../../domain/usecases/expense_usecases.dart';

part 'expenses_event.dart';
part 'expenses_state.dart';

class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  ExpensesBloc({
    required ListExpenses listExpenses,
    required GetExpenseSummary getSummary,
    required ListExpenseCategories listCategories,
    required CreateExpense createExpense,
    required DeleteExpense deleteExpense,
    required SyncExpensesFromRemote syncFromRemote,
    required GenerateRecurringExpenses generateRecurring,
    required AuthSession session,
  })  : _listExpenses = listExpenses,
        _getSummary = getSummary,
        _listCategories = listCategories,
        _createExpense = createExpense,
        _deleteExpense = deleteExpense,
        _syncFromRemote = syncFromRemote,
        _generateRecurring = generateRecurring,
        _session = session,
        super(const ExpensesState()) {
    on<ExpensesLoadRequested>(_onLoad);
    on<ExpensesFilterChanged>(_onFilterChanged);
    on<ExpenseCreateSubmitted>(_onCreate);
    on<ExpenseDeleteRequested>(_onDelete);
  }

  final ListExpenses _listExpenses;
  final GetExpenseSummary _getSummary;
  final ListExpenseCategories _listCategories;
  final CreateExpense _createExpense;
  final DeleteExpense _deleteExpense;
  final SyncExpensesFromRemote _syncFromRemote;
  final GenerateRecurringExpenses _generateRecurring;
  final AuthSession _session;

  AuthSession get session => _session;

  int get shopId => _session.shop.id;
  int get userId => _session.user.id;

  Future<void> _onLoad(
    ExpensesLoadRequested event,
    Emitter<ExpensesState> emit,
  ) async {
    final hasData = state.summary != null;
    emit(
      state.copyWith(
        status: hasData ? ExpensesStatus.refreshing : ExpensesStatus.loading,
        clearError: true,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onFilterChanged(
    ExpensesFilterChanged event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: event.filters,
        status: ExpensesStatus.refreshing,
        clearError: true,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onCreate(
    ExpenseCreateSubmitted event,
    Emitter<ExpensesState> emit,
  ) async {
    try {
      await _createExpense(
        shopId: shopId,
        userId: userId,
        input: event.input,
      );
      await _fetch(emit);
    } on Failure catch (error) {
      emit(state.copyWith(
        status: ExpensesStatus.failure,
        errorMessage: friendlyErrorMessage(error),
      ));
    }
  }

  Future<void> _onDelete(
    ExpenseDeleteRequested event,
    Emitter<ExpensesState> emit,
  ) async {
    try {
      await _deleteExpense(
        shopId: shopId,
        expenseId: event.expenseId,
        userId: userId,
      );
      await _fetch(emit);
    } on Failure catch (error) {
      emit(state.copyWith(
        status: ExpensesStatus.failure,
        errorMessage: friendlyErrorMessage(error),
      ));
    }
  }

  Future<void> _fetch(Emitter<ExpensesState> emit) async {
    try {
      unawaited(_backgroundSync());

      final results = await Future.wait([
        _getSummary(shopId: shopId),
        _listExpenses(shopId: shopId, filters: state.filters),
        _listCategories(shopId: shopId),
      ]);
      emit(
        state.copyWith(
          status: ExpensesStatus.loaded,
          summary: results[0] as ExpenseSummary,
          expenses: results[1] as List<Expense>,
          categories: results[2] as List<ExpenseCategory>,
          clearError: true,
        ),
      );
    } on Failure catch (error) {
      if (state.summary != null) {
        emit(
          state.copyWith(
            status: ExpensesStatus.loaded,
            errorMessage: friendlyErrorMessage(error),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: ExpensesStatus.failure,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _backgroundSync() async {
    try {
      await _generateRecurring(shopId: shopId, userId: userId);
      await _syncFromRemote(shopId: shopId);
    } catch (_) {
      // Offline ou cloud indisponible — données locales conservées.
    }
  }
}
