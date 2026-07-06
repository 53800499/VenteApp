import '../../data/datasources/local/expenses_local_datasource.dart';
import '../entities/expense_entities.dart';

typedef ExpenseCreator = Future<Expense> Function(CreateExpenseInput input);

/// Génère les occurrences manquantes des dépenses récurrentes (offline-first).
class RecurringExpenseService {
  const RecurringExpenseService(this._local, this._create);

  final ExpensesLocalDatasource _local;
  final ExpenseCreator _create;

  Future<int> generateDueExpenses({
    required int shopId,
    required int userId,
  }) async {
    final templates = await _local.listRecurringTemplates(shopId);
    if (templates.isEmpty) return 0;

    var created = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final template in templates) {
      var cursor = template.expenseDate;
      while (true) {
        final next = _nextOccurrence(template.repeatSchedule, cursor);
        if (next > now) break;

        final period = _periodBounds(template.repeatSchedule, next);
        final exists = await _local.hasRecurringOccurrence(
          shopId: shopId,
          title: template.title,
          categoryId: template.categoryId,
          amount: template.amount,
          fromMs: period.$1,
          toMs: period.$2,
        );
        if (!exists) {
          await _create(
            CreateExpenseInput(
              categoryId: template.categoryId,
              title: template.title,
              description: template.description,
              amount: template.amount,
              expenseDate: next,
              paymentMethod: template.paymentMethod,
              supplier: template.supplier,
              invoiceNumber: template.invoiceNumber,
              repeatSchedule: ExpenseRepeatSchedule.none,
              status: template.status,
            ),
          );
          created++;
        }
        cursor = next;
      }
    }
    return created;
  }

  int _nextOccurrence(ExpenseRepeatSchedule schedule, int fromMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(fromMs);
    final next = switch (schedule) {
      ExpenseRepeatSchedule.daily => date.add(const Duration(days: 1)),
      ExpenseRepeatSchedule.weekly => date.add(const Duration(days: 7)),
      ExpenseRepeatSchedule.monthly =>
        DateTime(date.year, date.month + 1, date.day),
      ExpenseRepeatSchedule.yearly =>
        DateTime(date.year + 1, date.month, date.day),
      ExpenseRepeatSchedule.none => date,
    };
    return next.millisecondsSinceEpoch;
  }

  (int, int) _periodBounds(ExpenseRepeatSchedule schedule, int occurrenceMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(occurrenceMs);
    return switch (schedule) {
      ExpenseRepeatSchedule.daily => (
          DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
          DateTime(date.year, date.month, date.day, 23, 59, 59, 999)
              .millisecondsSinceEpoch,
        ),
      ExpenseRepeatSchedule.weekly => (
          date.subtract(Duration(days: date.weekday - 1)).millisecondsSinceEpoch,
          date
              .add(Duration(days: 7 - date.weekday))
              .add(const Duration(hours: 23, minutes: 59, seconds: 59))
              .millisecondsSinceEpoch,
        ),
      ExpenseRepeatSchedule.monthly => (
          DateTime(date.year, date.month, 1).millisecondsSinceEpoch,
          DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999)
              .millisecondsSinceEpoch,
        ),
      ExpenseRepeatSchedule.yearly => (
          DateTime(date.year, 1, 1).millisecondsSinceEpoch,
          DateTime(date.year, 12, 31, 23, 59, 59, 999).millisecondsSinceEpoch,
        ),
      ExpenseRepeatSchedule.none => (occurrenceMs, occurrenceMs),
    };
  }
}
