import '../../domain/entities/expense_entities.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseCategory>> listCategories({required int shopId});

  Future<ExpenseCategory> createCategory({
    required int shopId,
    required String name,
    String? color,
    String? icon,
  });

  Future<List<Expense>> listExpenses({
    required int shopId,
    ExpenseListFilters filters = const ExpenseListFilters(),
  });

  Future<Expense?> findExpense({required int shopId, required int expenseId});

  Future<Expense> createExpense({
    required int shopId,
    required int userId,
    required CreateExpenseInput input,
  });

  Future<Expense> updateExpense({
    required int shopId,
    required int expenseId,
    required int userId,
    required CreateExpenseInput input,
  });

  Future<void> deleteExpense({
    required int shopId,
    required int expenseId,
    required int userId,
  });

  Future<List<ExpenseHistoryEntry>> listHistory({
    required int shopId,
    required int expenseId,
  });

  Future<ExpenseSummary> getSummary({required int shopId});

  Future<List<ExpenseByCategory>> aggregateByCategory({
    required int shopId,
    required int fromMs,
    required int toMs,
  });

  Future<int> sumValidatedExpenses({
    required int shopId,
    required int fromMs,
    required int toMs,
  });

  Future<void> upsertCategoryBudget({
    required int shopId,
    required int categoryId,
    required int monthlyAmount,
  });

  Future<ExpenseDetail> getExpenseDetail({
    required int shopId,
    required int expenseId,
  });

  Future<void> syncFromRemote({required int shopId});

  Future<List<Expense>> listRecurringTemplates({required int shopId});

  Future<bool> hasRecurringOccurrence({
    required int shopId,
    required String title,
    int? categoryId,
    required int amount,
    required int fromMs,
    required int toMs,
  });

  Future<int> generateRecurringExpenses({
    required int shopId,
    required int userId,
  });
}
