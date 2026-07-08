import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/expense_entities.dart';
import '../../models/expense_api_models.dart';

const _systemCategories = [
  ('Loyer', '#6366F1', 'home'),
  ('Salaire', '#0EA5E9', 'people'),
  ('Transport', '#F59E0B', 'directions_car'),
  ('Electricité', '#EAB308', 'bolt'),
  ('Eau', '#06B6D4', 'water_drop'),
  ('Internet', '#8B5CF6', 'wifi'),
  ('Fournitures', '#64748B', 'inventory_2'),
  ('Fiscalité', '#EF4444', 'receipt_long'),
  ('Retrait propriétaire', '#14B8A6', 'account_balance_wallet'),
];

class ExpensesLocalDatasource {
  ExpensesLocalDatasource(this._db);

  final db.AppDatabase _db;

  Future<void> ensureSystemCategories(int shopId) async {
    final existing = await (_db.select(_db.expenseCategories)
          ..where((c) => c.shopId.equals(shopId))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return;

    final timestamp = nowMs();
    await _db.batch((batch) {
      for (final (name, color, icon) in _systemCategories) {
        batch.insert(
          _db.expenseCategories,
          db.ExpenseCategoriesCompanion.insert(
            shopId: shopId,
            name: name,
            color: Value(color),
            icon: Value(icon),
            isSystem: const Value(true),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
      }
    });
  }

  Future<List<ExpenseCategory>> listCategories(int shopId) async {
    await ensureSystemCategories(shopId);
    final rows = await (_db.select(_db.expenseCategories)
          ..where((c) => c.shopId.equals(shopId))
          ..orderBy([
            (c) => OrderingTerm.desc(c.isSystem),
            (c) => OrderingTerm.asc(c.name),
          ]))
        .get();

    final budgets = await (_db.select(_db.categoryBudgets)
          ..where((b) => b.shopId.equals(shopId)))
        .get();
    final budgetByCategory = {for (final b in budgets) b.categoryId: b.monthlyAmount};

    return rows
        .map(
          (row) => ExpenseCategory(
            id: row.id,
            shopId: row.shopId,
            name: row.name,
            color: row.color,
            icon: row.icon,
            isSystem: row.isSystem,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            monthlyBudget: budgetByCategory[row.id],
          ),
        )
        .toList();
  }

  Future<ExpenseCategory> createCategory({
    required int shopId,
    required String name,
    String? color,
    String? icon,
  }) async {
    final timestamp = nowMs();
    final id = await _db.into(_db.expenseCategories).insert(
          db.ExpenseCategoriesCompanion.insert(
            shopId: shopId,
            name: name,
            color: Value(color),
            icon: Value(icon),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return ExpenseCategory(
      id: id,
      shopId: shopId,
      name: name,
      color: color,
      icon: icon,
      isSystem: false,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Future<List<Expense>> listExpenses({
    required int shopId,
    ExpenseListFilters filters = const ExpenseListFilters(),
  }) async {
    final query = _db.select(_db.expenses).join([
      leftOuterJoin(
        _db.expenseCategories,
        _db.expenseCategories.id.equalsExp(_db.expenses.categoryId),
      ),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.expenses.createdBy)),
    ])
      ..where(
        _db.expenses.shopId.equals(shopId) &
            _db.expenses.deletedAt.isNull() &
            (filters.fromMs != null
                ? _db.expenses.expenseDate.isBiggerOrEqualValue(filters.fromMs!)
                : const Constant(true)) &
            (filters.toMs != null
                ? _db.expenses.expenseDate.isSmallerOrEqualValue(filters.toMs!)
                : const Constant(true)) &
            (filters.categoryId != null
                ? _db.expenses.categoryId.equals(filters.categoryId!)
                : const Constant(true)) &
            (filters.paymentMethod != null
                ? _db.expenses.paymentMethod.equals(filters.paymentMethod!.code)
                : const Constant(true)) &
            (filters.search?.trim().isNotEmpty == true
                ? _db.expenses.title.like('%${filters.search!.trim()}%')
                : const Constant(true)),
      )
      ..orderBy([OrderingTerm.desc(_db.expenses.expenseDate)]);

    final rows = await query.get();
    final expenses = <Expense>[];
    for (final row in rows) {
      expenses.add(await _mapExpenseRow(row));
    }
    return expenses;
  }

  Future<Expense?> findExpense(int shopId, int expenseId) async {
    return _findExpenseRow(shopId, expenseId, includeDeleted: false);
  }

  Future<Expense?> findExpenseForSync(int shopId, int expenseId) async {
    return _findExpenseRow(shopId, expenseId, includeDeleted: true);
  }

  Future<Expense?> _findExpenseRow(
    int shopId,
    int expenseId, {
    required bool includeDeleted,
  }) async {
    var predicate = _db.expenses.shopId.equals(shopId) &
        _db.expenses.id.equals(expenseId);
    if (!includeDeleted) {
      predicate = predicate & _db.expenses.deletedAt.isNull();
    }

    final query = _db.select(_db.expenses).join([
      leftOuterJoin(
        _db.expenseCategories,
        _db.expenseCategories.id.equalsExp(_db.expenses.categoryId),
      ),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.expenses.createdBy)),
    ])
      ..where(predicate)
      ..limit(1);

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return _mapExpenseRow(rows.first);
  }

  Future<Expense> createExpense({
    required int shopId,
    required int userId,
    required CreateExpenseInput input,
  }) async {
    final timestamp = nowMs();
    final id = await _db.into(_db.expenses).insert(
          db.ExpensesCompanion.insert(
            shopId: shopId,
            categoryId: Value(input.categoryId),
            title: input.title,
            description: Value(input.description),
            amount: input.amount,
            expenseDate: input.expenseDate,
            paymentMethod: Value(input.paymentMethod.code),
            createdBy: userId,
            supplier: Value(input.supplier),
            invoiceNumber: Value(input.invoiceNumber),
            repeatSchedule: Value(input.repeatSchedule.code),
            status: Value(input.status.code),
            createdAt: timestamp,
            updatedAt: timestamp,
            syncStatus: const Value('pending'),
          ),
        );

    for (final path in input.attachmentPaths) {
      final fileName = path.split(RegExp(r'[/\\]')).last;
      await _db.into(_db.expenseAttachments).insert(
            db.ExpenseAttachmentsCompanion.insert(
              shopId: shopId,
              expenseId: id,
              fileName: fileName,
              localPath: path,
              createdAt: timestamp,
            ),
          );
    }

    return (await findExpense(shopId, id))!;
  }

  Future<Expense> updateExpense({
    required int shopId,
    required int expenseId,
    required int userId,
    required CreateExpenseInput input,
  }) async {
    final existing = await findExpense(shopId, expenseId);
    if (existing == null) throw StateError('Dépense introuvable');

    await _recordChanges(shopId, expenseId, userId, existing, input);

    await (_db.update(_db.expenses)..where((e) => e.id.equals(expenseId))).write(
          db.ExpensesCompanion(
            categoryId: Value(input.categoryId),
            title: Value(input.title),
            description: Value(input.description),
            amount: Value(input.amount),
            expenseDate: Value(input.expenseDate),
            paymentMethod: Value(input.paymentMethod.code),
            supplier: Value(input.supplier),
            invoiceNumber: Value(input.invoiceNumber),
            repeatSchedule: Value(input.repeatSchedule.code),
            status: Value(input.status.code),
            updatedAt: Value(nowMs()),
            syncStatus: const Value('pending'),
          ),
        );

    return (await findExpense(shopId, expenseId))!;
  }

  Future<void> softDelete({
    required int shopId,
    required int expenseId,
    required int userId,
  }) async {
    final timestamp = nowMs();
    await _db.into(_db.expenseHistoryEntries).insert(
          db.ExpenseHistoryEntriesCompanion.insert(
            shopId: shopId,
            expenseId: expenseId,
            userId: userId,
            fieldName: 'deleted_at',
            newValue: Value('$timestamp'),
            createdAt: timestamp,
          ),
        );
    await (_db.update(_db.expenses)..where((e) => e.id.equals(expenseId))).write(
          db.ExpensesCompanion(
            deletedAt: Value(timestamp),
            updatedAt: Value(timestamp),
            syncStatus: const Value('pending'),
          ),
        );
  }

  Future<List<ExpenseHistoryEntry>> listHistory(int shopId, int expenseId) async {
    final rows = await (_db.select(_db.expenseHistoryEntries).join([
      leftOuterJoin(
        _db.users,
        _db.users.id.equalsExp(_db.expenseHistoryEntries.userId),
      ),
    ])
          ..where(
            _db.expenseHistoryEntries.shopId.equals(shopId) &
                _db.expenseHistoryEntries.expenseId.equals(expenseId),
          )
          ..orderBy([OrderingTerm.desc(_db.expenseHistoryEntries.createdAt)]))
        .get();

    return rows
        .map(
          (row) => ExpenseHistoryEntry(
            id: row.readTable(_db.expenseHistoryEntries).id,
            userId: row.readTable(_db.expenseHistoryEntries).userId,
            userName: row.readTableOrNull(_db.users)?.name,
            fieldName: row.readTable(_db.expenseHistoryEntries).fieldName,
            oldValue: row.readTable(_db.expenseHistoryEntries).oldValue,
            newValue: row.readTable(_db.expenseHistoryEntries).newValue,
            createdAt: row.readTable(_db.expenseHistoryEntries).createdAt,
          ),
        )
        .toList();
  }

  Future<int> sumValidatedExpenses({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await (_db.select(_db.expenses)
          ..where(
            (e) =>
                e.shopId.equals(shopId) &
                e.deletedAt.isNull() &
                e.status.equals('validated') &
                e.expenseDate.isBiggerOrEqualValue(fromMs) &
                e.expenseDate.isSmallerOrEqualValue(toMs),
          ))
        .get();
    return rows.fold<int>(0, (sum, row) => sum + row.amount);
  }

  Future<int> sumCashExpenses({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    const cashMethods = ['cash', 'mtn_momo', 'moov_money'];
    final rows = await (_db.select(_db.expenses)
          ..where(
            (e) =>
                e.shopId.equals(shopId) &
                e.deletedAt.isNull() &
                e.status.equals('validated') &
                e.paymentMethod.isIn(cashMethods) &
                e.expenseDate.isBiggerOrEqualValue(fromMs) &
                e.expenseDate.isSmallerOrEqualValue(toMs),
          ))
        .get();
    return rows.fold<int>(0, (sum, row) => sum + row.amount);
  }

  Future<int> sumCashCollected({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final sales = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.status.equals('completed') &
                s.createdAt.isBiggerOrEqualValue(fromMs) &
                s.createdAt.isSmallerOrEqualValue(toMs),
          ))
        .get();
    return sales.fold<int>(0, (sum, s) => sum + s.amountCash + s.amountMomo);
  }

  Future<List<ExpenseByCategory>> aggregateByCategory({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final expenses = await listExpenses(
      shopId: shopId,
      filters: ExpenseListFilters(fromMs: fromMs, toMs: toMs),
    );
    final categories = await listCategories(shopId);
    final budgetByCategory = {
      for (final c in categories) c.id: c.monthlyBudget,
    };

    final byCategory = <String, ExpenseByCategory>{};
    for (final expense in expenses.where((e) => e.isValidated)) {
      final key = expense.categoryId?.toString() ?? 'none';
      final existing = byCategory[key];
      if (existing == null) {
        byCategory[key] = ExpenseByCategory(
          categoryId: expense.categoryId,
          categoryName: expense.categoryName ?? 'Sans catégorie',
          expenseCount: 1,
          totalAmount: expense.amount,
          budgetAmount: expense.categoryId != null
              ? budgetByCategory[expense.categoryId!]
              : null,
        );
      } else {
        byCategory[key] = ExpenseByCategory(
          categoryId: existing.categoryId,
          categoryName: existing.categoryName,
          expenseCount: existing.expenseCount + 1,
          totalAmount: existing.totalAmount + expense.amount,
          budgetAmount: existing.budgetAmount,
        );
      }
    }

    return byCategory.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  Future<bool> expenseIsDeleted(int expenseId) async {
    final row = await (_db.select(_db.expenses)
          ..where((e) => e.id.equals(expenseId))
          ..limit(1))
        .getSingleOrNull();
    return row?.deletedAt != null;
  }

  Future<String?> findExpenseServerId(int shopId, int expenseId) async {
    final row = await (_db.select(_db.expenses)
          ..where(
            (e) => e.shopId.equals(shopId) & e.id.equals(expenseId),
          )
          ..limit(1))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<void> updateExpenseServerSync({
    required int expenseId,
    required String serverId,
  }) async {
    await (_db.update(_db.expenses)..where((e) => e.id.equals(expenseId))).write(
      db.ExpensesCompanion(
        serverId: Value(serverId),
        syncedAt: Value(nowMs()),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<ExpenseCategory?> findCategory(int shopId, int categoryId) async {
    final row = await (_db.select(_db.expenseCategories)
          ..where(
            (c) => c.shopId.equals(shopId) & c.id.equals(categoryId),
          )
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return ExpenseCategory(
      id: row.id,
      shopId: row.shopId,
      name: row.name,
      color: row.color,
      icon: row.icon,
      isSystem: row.isSystem,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<int?> resolveDefaultUserId(int shopId) async {
    final user = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(shopId) & u.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return user?.id;
  }

  Future<String?> findCategoryServerId(int shopId, int categoryId) async {
    final row = await (_db.select(_db.expenseCategories)
          ..where(
            (c) => c.shopId.equals(shopId) & c.id.equals(categoryId),
          )
          ..limit(1))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<int?> findCategoryLocalIdByServerId(int shopId, String serverId) async {
    final row = await (_db.select(_db.expenseCategories)
          ..where(
            (c) => c.shopId.equals(shopId) & c.serverId.equals(serverId),
          )
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int> upsertCategoryFromRemote({
    required int shopId,
    required ExpenseCategoryApiDto remote,
  }) async {
    final timestamp = nowMs();

    final byServerRows = await (_db.select(_db.expenseCategories)
          ..where(
            (c) =>
                c.shopId.equals(shopId) &
                c.serverId.equals('${remote.id}'),
          ))
        .get();
    final byServer = byServerRows.isEmpty ? null : byServerRows.first;
    if (byServer != null) {
      await (_db.update(_db.expenseCategories)
            ..where((c) => c.id.equals(byServer.id)))
          .write(
        db.ExpenseCategoriesCompanion(
          name: Value(remote.name),
          color: Value(remote.color),
          icon: Value(remote.icon),
          isSystem: Value(remote.isSystem),
          updatedAt: Value(remote.updatedAt),
          syncedAt: Value(timestamp),
        ),
      );
      if (byServerRows.length > 1) {
        final duplicateIds = byServerRows.skip(1).map((c) => c.id).toList();
        await (_db.delete(_db.expenseCategories)..where((c) => c.id.isIn(duplicateIds))).go();
      }
      return byServer.id;
    }

    final byNameRows = await (_db.select(_db.expenseCategories)
          ..where(
            (c) => c.shopId.equals(shopId) & c.name.equals(remote.name),
          ))
        .get();
    final byName = byNameRows.isEmpty ? null : byNameRows.first;
    if (byName != null) {
      await (_db.update(_db.expenseCategories)
            ..where((c) => c.id.equals(byName.id)))
          .write(
        db.ExpenseCategoriesCompanion(
          serverId: Value('${remote.id}'),
          color: Value(remote.color),
          icon: Value(remote.icon),
          syncedAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
      if (byNameRows.length > 1) {
        final duplicateIds = byNameRows.skip(1).map((c) => c.id).toList();
        await (_db.delete(_db.expenseCategories)..where((c) => c.id.isIn(duplicateIds))).go();
      }
      return byName.id;
    }

    return _db.into(_db.expenseCategories).insert(
          db.ExpenseCategoriesCompanion.insert(
            shopId: shopId,
            name: remote.name,
            color: Value(remote.color),
            icon: Value(remote.icon),
            isSystem: Value(remote.isSystem),
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            serverId: Value('${remote.id}'),
            syncedAt: Value(timestamp),
          ),
        );
  }

  Future<void> upsertExpenseFromRemote({
    required int shopId,
    required int userId,
    int? localCategoryId,
    required ExpenseApiDto remote,
  }) async {
    final timestamp = nowMs();
    final serverId = '${remote.id}';

    final existingRows = await (_db.select(_db.expenses)
          ..where(
            (e) => e.shopId.equals(shopId) & e.serverId.equals(serverId),
          ))
        .get();
    final existing = existingRows.isEmpty ? null : existingRows.first;

    if (existing != null) {
      await (_db.update(_db.expenses)..where((e) => e.id.equals(existing.id)))
          .write(
        db.ExpensesCompanion(
          categoryId: Value(localCategoryId),
          title: Value(remote.title),
          description: Value(remote.description),
          amount: Value(remote.amount),
          expenseDate: Value(remote.expenseDate),
          paymentMethod: Value(remote.paymentMethod),
          supplier: Value(remote.supplier),
          invoiceNumber: Value(remote.invoiceNumber),
          repeatSchedule: Value(remote.repeatSchedule),
          status: Value(remote.status),
          deletedAt: Value(remote.deletedAt),
          syncedAt: Value(timestamp),
          updatedAt: Value(remote.updatedAt),
          syncStatus: const Value('synced'),
        ),
      );
      if (existingRows.length > 1) {
        final duplicateIds = existingRows.skip(1).map((e) => e.id).toList();
        await (_db.delete(_db.expenses)..where((e) => e.id.isIn(duplicateIds))).go();
      }
      return;
    }

    await _db.into(_db.expenses).insert(
          db.ExpensesCompanion.insert(
            shopId: shopId,
            categoryId: Value(localCategoryId),
            title: remote.title,
            description: Value(remote.description),
            amount: remote.amount,
            expenseDate: remote.expenseDate,
            paymentMethod: Value(remote.paymentMethod),
            createdBy: userId,
            supplier: Value(remote.supplier),
            invoiceNumber: Value(remote.invoiceNumber),
            repeatSchedule: Value(remote.repeatSchedule),
            status: Value(remote.status),
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            deletedAt: Value(remote.deletedAt),
            serverId: Value(serverId),
            syncedAt: Value(timestamp),
            syncStatus: const Value('synced'),
          ),
        );
  }

  Future<List<Expense>> listRecurringTemplates(int shopId) async {
    final rows = await (_db.select(_db.expenses)
          ..where(
            (e) =>
                e.shopId.equals(shopId) &
                e.deletedAt.isNull() &
                e.status.equals('validated') &
                e.repeatSchedule.isNotValue('none'),
          ))
        .get();

    final result = <Expense>[];
    for (final row in rows) {
      final expense = await findExpense(shopId, row.id);
      if (expense != null) result.add(expense);
    }
    return result;
  }

  Future<bool> hasRecurringOccurrence({
    required int shopId,
    required String title,
    int? categoryId,
    required int amount,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await (_db.select(_db.expenses)
          ..where(
            (e) {
              var expr = e.shopId.equals(shopId) &
                  e.deletedAt.isNull() &
                  e.title.equals(title) &
                  e.amount.equals(amount) &
                  e.expenseDate.isBiggerOrEqualValue(fromMs) &
                  e.expenseDate.isSmallerOrEqualValue(toMs);
              if (categoryId != null) {
                expr = expr & e.categoryId.equals(categoryId);
              }
              return expr;
            },
          )
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<void> upsertCategoryBudget({
    required int shopId,
    required int categoryId,
    required int monthlyAmount,
  }) async {
    final timestamp = nowMs();
    final existing = await (_db.select(_db.categoryBudgets)
          ..where(
            (b) => b.shopId.equals(shopId) & b.categoryId.equals(categoryId),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.categoryBudgets).insert(
            db.CategoryBudgetsCompanion.insert(
              shopId: shopId,
              categoryId: categoryId,
              monthlyAmount: monthlyAmount,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
    } else {
      await (_db.update(_db.categoryBudgets)
            ..where((b) => b.id.equals(existing.id)))
          .write(
            db.CategoryBudgetsCompanion(
              monthlyAmount: Value(monthlyAmount),
              updatedAt: Value(timestamp),
            ),
          );
    }
  }

  Future<Expense> _mapExpenseRow(TypedResult row) async {
    final expense = row.readTable(_db.expenses);
    final category = row.readTableOrNull(_db.expenseCategories);
    final user = row.readTableOrNull(_db.users);
    final attachments = await (_db.select(_db.expenseAttachments)
          ..where((a) => a.expenseId.equals(expense.id)))
        .get();

    return Expense(
      id: expense.id,
      shopId: expense.shopId,
      categoryId: expense.categoryId,
      categoryName: category?.name,
      title: expense.title,
      description: expense.description,
      amount: expense.amount,
      expenseDate: expense.expenseDate,
      paymentMethod: ExpensePaymentMethod.fromCode(expense.paymentMethod),
      createdBy: expense.createdBy,
      createdByName: user?.name,
      supplier: expense.supplier,
      invoiceNumber: expense.invoiceNumber,
      repeatSchedule: ExpenseRepeatSchedule.fromCode(expense.repeatSchedule),
      status: ExpenseStatus.fromCode(expense.status),
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
      attachments: attachments
          .map(
            (a) => ExpenseAttachment(
              id: a.id,
              fileName: a.fileName,
              mimeType: a.mimeType,
              localPath: a.localPath,
              createdAt: a.createdAt,
            ),
          )
          .toList(),
    );
  }

  Future<void> _recordChanges(
    int shopId,
    int expenseId,
    int userId,
    Expense existing,
    CreateExpenseInput input,
  ) async {
    final timestamp = nowMs();
    Future<void> log(String field, String? oldV, String? newV) async {
      if (oldV == newV) return;
      await _db.into(_db.expenseHistoryEntries).insert(
            db.ExpenseHistoryEntriesCompanion.insert(
              shopId: shopId,
              expenseId: expenseId,
              userId: userId,
              fieldName: field,
              oldValue: Value(oldV),
              newValue: Value(newV),
              createdAt: timestamp,
            ),
          );
    }

    await log('title', existing.title, input.title);
    await log('amount', '${existing.amount}', '${input.amount}');
    await log('status', existing.status.code, input.status.code);
  }
}
