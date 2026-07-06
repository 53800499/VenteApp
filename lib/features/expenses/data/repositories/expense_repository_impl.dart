import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../domain/entities/expense_entities.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/services/recurring_expense_service.dart';
import '../datasources/local/expenses_local_datasource.dart';
import '../datasources/remote/expenses_remote_datasource.dart';
import '../models/expense_api_models.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl({
    required ExpensesLocalDatasource local,
    required ExpensesRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
    LocalWriteSyncRecorder? recorder,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _recorder = recorder;

  final ExpensesLocalDatasource _local;
  final ExpensesRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;
  final LocalWriteSyncRecorder? _recorder;
  @override
  Future<List<ExpenseCategory>> listCategories({required int shopId}) {
    return _local.listCategories(shopId);
  }

  @override
  Future<ExpenseCategory> createCategory({
    required int shopId,
    required String name,
    String? color,
    String? icon,
  }) {
    return _local.createCategory(
      shopId: shopId,
      name: name,
      color: color,
      icon: icon,
    );
  }

  @override
  Future<List<Expense>> listExpenses({
    required int shopId,
    ExpenseListFilters filters = const ExpenseListFilters(),
  }) {
    return _local.listExpenses(shopId: shopId, filters: filters);
  }

  @override
  Future<Expense?> findExpense({required int shopId, required int expenseId}) {
    return _local.findExpense(shopId, expenseId);
  }

  @override
  Future<Expense> createExpense({
    required int shopId,
    required int userId,
    required CreateExpenseInput input,
  }) async {
    final expense = await _local.createExpense(
      shopId: shopId,
      userId: userId,
      input: input,
    );
    await _recorder?.recordExpenseCreate(
      shopId: shopId,
      localId: expense.id,
    );
    _pushCreateInBackground(shopId, expense, input);
    return expense;
  }

  @override
  Future<Expense> updateExpense({
    required int shopId,
    required int expenseId,
    required int userId,
    required CreateExpenseInput input,
  }) async {
    final expense = await _local.updateExpense(
      shopId: shopId,
      expenseId: expenseId,
      userId: userId,
      input: input,
    );
    await _recorder?.recordExpenseUpdate(
      shopId: shopId,
      localId: expenseId,
    );
    return expense;
  }

  @override
  Future<void> deleteExpense({
    required int shopId,
    required int expenseId,
    required int userId,
  }) async {
    await _local.softDelete(
      shopId: shopId,
      expenseId: expenseId,
      userId: userId,
    );
    await _recorder?.recordExpenseUpdate(
      shopId: shopId,
      localId: expenseId,
    );
  }

  @override
  Future<List<ExpenseHistoryEntry>> listHistory({
    required int shopId,
    required int expenseId,
  }) {
    return _local.listHistory(shopId, expenseId);
  }

  @override
  Future<ExpenseSummary> getSummary({required int shopId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayStart = resolveReportPeriod(preset: ReportPeriodPreset.today).fromMs;
    final weekStart = resolveReportPeriod(preset: ReportPeriodPreset.week).fromMs;
    final monthStart = resolveReportPeriod(preset: ReportPeriodPreset.month).fromMs;

    final todayExpenses = await _local.listExpenses(
      shopId: shopId,
      filters: ExpenseListFilters(fromMs: dayStart, toMs: now),
    );
    final weekExpenses = await _local.listExpenses(
      shopId: shopId,
      filters: ExpenseListFilters(fromMs: weekStart, toMs: now),
    );
    final monthExpenses = await _local.listExpenses(
      shopId: shopId,
      filters: ExpenseListFilters(fromMs: monthStart, toMs: now),
    );

    int sumValidated(List<Expense> items) => items
        .where((e) => e.isValidated)
        .fold(0, (sum, e) => sum + e.amount);

    final cashCollected = await _local.sumCashCollected(
      shopId: shopId,
      fromMs: dayStart,
      toMs: now,
    );
    final cashExpenses = await _local.sumCashExpenses(
      shopId: shopId,
      fromMs: dayStart,
      toMs: now,
    );

    return ExpenseSummary(
      today: ExpenseSummaryPeriod(
        expenseCount: todayExpenses.where((e) => e.isValidated).length,
        totalAmount: sumValidated(todayExpenses),
      ),
      week: ExpenseSummaryPeriod(
        expenseCount: weekExpenses.where((e) => e.isValidated).length,
        totalAmount: sumValidated(weekExpenses),
      ),
      month: ExpenseSummaryPeriod(
        expenseCount: monthExpenses.where((e) => e.isValidated).length,
        totalAmount: sumValidated(monthExpenses),
      ),
      cashCollectedToday: cashCollected,
      cashExpensesToday: cashExpenses,
      estimatedCashBalance: cashCollected - cashExpenses,
    );
  }

  @override
  Future<List<ExpenseByCategory>> aggregateByCategory({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) {
    return _local.aggregateByCategory(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
  }

  @override
  Future<int> sumValidatedExpenses({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) {
    return _local.sumValidatedExpenses(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
  }

  @override
  Future<void> upsertCategoryBudget({
    required int shopId,
    required int categoryId,
    required int monthlyAmount,
  }) async {
    await _local.upsertCategoryBudget(
      shopId: shopId,
      categoryId: categoryId,
      monthlyAmount: monthlyAmount,
    );
    try {
      await _apiGuard.ensureReady();
      final serverCategoryId = await _local.findCategoryServerId(
        shopId,
        categoryId,
      );
      if (serverCategoryId != null) {
        await _remote.upsertCategoryBudget(
          int.parse(serverCategoryId),
          monthlyAmount,
        );
      }
    } on Failure {
      // Budget local conservé.
    }
  }

  @override
  Future<ExpenseDetail> getExpenseDetail({
    required int shopId,
    required int expenseId,
  }) async {
    final expense = await _local.findExpense(shopId, expenseId);
    if (expense == null) {
      throw const ValidationFailure('Dépense introuvable.');
    }

    await _tryRefreshExpenseFromRemote(shopId: shopId, expenseId: expenseId);

    final refreshed = await _local.findExpense(shopId, expenseId);
    final history = await _local.listHistory(shopId, expenseId);

    return ExpenseDetail(
      expense: refreshed ?? expense,
      history: history,
    );
  }

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    await _apiGuard.ensureReady();
    final userId = await _local.resolveDefaultUserId(shopId);
    if (userId == null) return;

    final remoteCategories = await _remote.fetchCategories();
    final categoryIdByServer = <int, int>{};
    for (final raw in remoteCategories) {
      final dto = ExpenseCategoryApiDto.fromJson(raw);
      final localId = await _local.upsertCategoryFromRemote(
        shopId: shopId,
        remote: dto,
      );
      categoryIdByServer[dto.id] = localId;
      if (dto.monthlyBudget != null) {
        await _local.upsertCategoryBudget(
          shopId: shopId,
          categoryId: localId,
          monthlyAmount: dto.monthlyBudget!,
        );
      }
    }

    final remoteExpenses = await _remote.fetchExpenses();
    for (final raw in remoteExpenses) {
      final dto = ExpenseApiDto.fromJson(raw);
      final localCategoryId = dto.categoryId != null
          ? categoryIdByServer[dto.categoryId!]
          : null;
      await _local.upsertExpenseFromRemote(
        shopId: shopId,
        userId: userId,
        localCategoryId: localCategoryId,
        remote: dto,
      );
    }
  }

  @override
  Future<List<Expense>> listRecurringTemplates({required int shopId}) =>
      _local.listRecurringTemplates(shopId);

  @override
  Future<bool> hasRecurringOccurrence({
    required int shopId,
    required String title,
    int? categoryId,
    required int amount,
    required int fromMs,
    required int toMs,
  }) =>
      _local.hasRecurringOccurrence(
        shopId: shopId,
        title: title,
        categoryId: categoryId,
        amount: amount,
        fromMs: fromMs,
        toMs: toMs,
      );

  @override
  Future<int> generateRecurringExpenses({
    required int shopId,
    required int userId,
  }) {
    final service = RecurringExpenseService(
      _local,
      (input) => createExpense(shopId: shopId, userId: userId, input: input),
    );
    return service.generateDueExpenses(shopId: shopId, userId: userId);
  }

  Future<void> _tryRefreshExpenseFromRemote({
    required int shopId,
    required int expenseId,
  }) async {
    try {
      final serverId = await _local.findExpenseServerId(shopId, expenseId);
      if (serverId == null) return;

      await _apiGuard.ensureReady();
      final remote = await _remote.fetchExpense(int.parse(serverId));
      final dto = ExpenseApiDto.fromJson(remote);
      final userId = await _local.resolveDefaultUserId(shopId);
      if (userId == null) return;

      int? localCategoryId;
      if (dto.categoryId != null) {
        localCategoryId = await _local.findCategoryLocalIdByServerId(
          shopId,
          '${dto.categoryId}',
        );
      }

      await _local.upsertExpenseFromRemote(
        shopId: shopId,
        userId: userId,
        localCategoryId: localCategoryId,
        remote: dto,
      );
    } on Failure {
      // Données locales conservées.
    }
  }

  void _pushCreateInBackground(
    int shopId,
    Expense expense,
    CreateExpenseInput input,
  ) {
    Future(() async {
      try {
        await _apiGuard.ensureReady();
        await _remote.createExpense({
          'title': input.title,
          'description': input.description,
          'amount': input.amount,
          'expenseDate': input.expenseDate,
          'paymentMethod': input.paymentMethod.code,
          'supplier': input.supplier,
          'invoiceNumber': input.invoiceNumber,
          'repeatSchedule': input.repeatSchedule.code,
          'status': input.status.code,
        });
      } catch (_) {
        // Sync queue reprendra plus tard.
      }
    });
  }
}
