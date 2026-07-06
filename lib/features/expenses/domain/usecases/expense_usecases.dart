import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../entities/expense_entities.dart';
import '../repositories/expense_repository.dart';

class ListExpenseCategories {
  const ListExpenseCategories(this._repository);
  final ExpenseRepository _repository;
  Future<List<ExpenseCategory>> call({required int shopId}) =>
      _repository.listCategories(shopId: shopId);
}

class CreateExpenseCategory {
  const CreateExpenseCategory(this._repository);
  final ExpenseRepository _repository;
  Future<ExpenseCategory> call({
    required int shopId,
    required String name,
  }) =>
      _repository.createCategory(shopId: shopId, name: name);
}

class ListExpenses {
  const ListExpenses(this._repository);
  final ExpenseRepository _repository;
  Future<List<Expense>> call({
    required int shopId,
    ExpenseListFilters filters = const ExpenseListFilters(),
  }) =>
      _repository.listExpenses(shopId: shopId, filters: filters);
}

class CreateExpense {
  const CreateExpense(this._repository);
  final ExpenseRepository _repository;
  Future<Expense> call({
    required int shopId,
    required int userId,
    required CreateExpenseInput input,
  }) =>
      _repository.createExpense(shopId: shopId, userId: userId, input: input);
}

class UpdateExpense {
  const UpdateExpense(this._repository);
  final ExpenseRepository _repository;
  Future<Expense> call({
    required int shopId,
    required int expenseId,
    required int userId,
    required CreateExpenseInput input,
  }) =>
      _repository.updateExpense(
        shopId: shopId,
        expenseId: expenseId,
        userId: userId,
        input: input,
      );
}

class DeleteExpense {
  const DeleteExpense(this._repository);
  final ExpenseRepository _repository;
  Future<void> call({
    required int shopId,
    required int expenseId,
    required int userId,
  }) =>
      _repository.deleteExpense(
        shopId: shopId,
        expenseId: expenseId,
        userId: userId,
      );
}

class GetExpenseSummary {
  const GetExpenseSummary(this._repository);
  final ExpenseRepository _repository;
  Future<ExpenseSummary> call({required int shopId}) =>
      _repository.getSummary(shopId: shopId);
}

class GetExpensesByCategory {
  const GetExpensesByCategory(this._repository);
  final ExpenseRepository _repository;
  Future<List<ExpenseByCategory>> call({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) =>
      _repository.aggregateByCategory(
        shopId: shopId,
        fromMs: fromMs,
        toMs: toMs,
      );
}

class SumValidatedExpenses {
  const SumValidatedExpenses(this._repository);
  final ExpenseRepository _repository;
  Future<int> call({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) =>
      _repository.sumValidatedExpenses(
        shopId: shopId,
        fromMs: fromMs,
        toMs: toMs,
      );
}

class GetExpenseDetail {
  const GetExpenseDetail(this._repository);
  final ExpenseRepository _repository;

  Future<ExpenseDetail> call({
    required AuthSession session,
    required int expenseId,
  }) {
    if (!PermissionGuard.can(
      session.user.permissions,
      Permission.expensesRead,
    )) {
      throw const UnauthorizedFailure(
        'Vous n\'avez pas la permission de consulter les dépenses.',
      );
    }
    return _repository.getExpenseDetail(
      shopId: session.shop.id,
      expenseId: expenseId,
    );
  }
}

class UpsertCategoryBudget {
  const UpsertCategoryBudget(this._repository);
  final ExpenseRepository _repository;

  Future<void> call({
    required int shopId,
    required int categoryId,
    required int monthlyAmount,
  }) =>
      _repository.upsertCategoryBudget(
        shopId: shopId,
        categoryId: categoryId,
        monthlyAmount: monthlyAmount,
      );
}

class GenerateRecurringExpenses {
  const GenerateRecurringExpenses(this._repository);
  final ExpenseRepository _repository;

  Future<int> call({
    required int shopId,
    required int userId,
  }) =>
      _repository.generateRecurringExpenses(shopId: shopId, userId: userId);
}

class SyncExpensesFromRemote {
  const SyncExpensesFromRemote(this._repository);
  final ExpenseRepository _repository;

  Future<void> call({required int shopId}) =>
      _repository.syncFromRemote(shopId: shopId);
}
