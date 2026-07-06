import 'package:equatable/equatable.dart';

enum ExpensePaymentMethod {
  cash,
  mtnMomo,
  moovMoney,
  card,
  transfer,
  check;

  String get code => switch (this) {
        ExpensePaymentMethod.cash => 'cash',
        ExpensePaymentMethod.mtnMomo => 'mtn_momo',
        ExpensePaymentMethod.moovMoney => 'moov_money',
        ExpensePaymentMethod.card => 'card',
        ExpensePaymentMethod.transfer => 'transfer',
        ExpensePaymentMethod.check => 'check',
      };

  static ExpensePaymentMethod fromCode(String code) => switch (code) {
        'mtn_momo' => ExpensePaymentMethod.mtnMomo,
        'moov_money' => ExpensePaymentMethod.moovMoney,
        'card' => ExpensePaymentMethod.card,
        'transfer' => ExpensePaymentMethod.transfer,
        'check' => ExpensePaymentMethod.check,
        _ => ExpensePaymentMethod.cash,
      };

  String get label => switch (this) {
        ExpensePaymentMethod.cash => 'Espèces',
        ExpensePaymentMethod.mtnMomo => 'MTN MoMo',
        ExpensePaymentMethod.moovMoney => 'Moov Money',
        ExpensePaymentMethod.card => 'Carte bancaire',
        ExpensePaymentMethod.transfer => 'Virement',
        ExpensePaymentMethod.check => 'Chèque',
      };
}

enum ExpenseRepeatSchedule {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  String get code => name;

  static ExpenseRepeatSchedule fromCode(String code) =>
      ExpenseRepeatSchedule.values.firstWhere(
        (v) => v.code == code,
        orElse: () => ExpenseRepeatSchedule.none,
      );

  String get label => switch (this) {
        ExpenseRepeatSchedule.none => 'Aucune',
        ExpenseRepeatSchedule.daily => 'Quotidienne',
        ExpenseRepeatSchedule.weekly => 'Hebdomadaire',
        ExpenseRepeatSchedule.monthly => 'Mensuelle',
        ExpenseRepeatSchedule.yearly => 'Annuelle',
      };
}

enum ExpenseStatus {
  draft,
  pending,
  validated,
  refused;

  String get code => switch (this) {
        ExpenseStatus.draft => 'draft',
        ExpenseStatus.pending => 'pending',
        ExpenseStatus.validated => 'validated',
        ExpenseStatus.refused => 'refused',
      };

  static ExpenseStatus fromCode(String code) => switch (code) {
        'draft' => ExpenseStatus.draft,
        'pending' => ExpenseStatus.pending,
        'refused' => ExpenseStatus.refused,
        _ => ExpenseStatus.validated,
      };

  String get label => switch (this) {
        ExpenseStatus.draft => 'Brouillon',
        ExpenseStatus.pending => 'En attente',
        ExpenseStatus.validated => 'Validée',
        ExpenseStatus.refused => 'Refusée',
      };
}

class ExpenseCategory extends Equatable {
  const ExpenseCategory({
    required this.id,
    required this.shopId,
    required this.name,
    this.color,
    this.icon,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
    this.monthlyBudget,
  });

  final int id;
  final int shopId;
  final String name;
  final String? color;
  final String? icon;
  final bool isSystem;
  final int createdAt;
  final int updatedAt;
  final int? monthlyBudget;

  @override
  List<Object?> get props =>
      [id, shopId, name, color, icon, isSystem, monthlyBudget];
}

class ExpenseAttachment extends Equatable {
  const ExpenseAttachment({
    required this.id,
    required this.fileName,
    this.mimeType,
    required this.localPath,
    required this.createdAt,
  });

  final int id;
  final String fileName;
  final String? mimeType;
  final String localPath;
  final int createdAt;

  @override
  List<Object?> get props => [id, fileName, mimeType, localPath, createdAt];
}

class ExpenseHistoryEntry extends Equatable {
  const ExpenseHistoryEntry({
    required this.id,
    required this.userId,
    this.userName,
    required this.fieldName,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String? userName;
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final int createdAt;

  @override
  List<Object?> get props =>
      [id, userId, userName, fieldName, oldValue, newValue, createdAt];
}

class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.shopId,
    this.categoryId,
    this.categoryName,
    required this.title,
    this.description,
    required this.amount,
    required this.expenseDate,
    required this.paymentMethod,
    required this.createdBy,
    this.createdByName,
    this.supplier,
    this.invoiceNumber,
    required this.repeatSchedule,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
  });

  final int id;
  final int shopId;
  final int? categoryId;
  final String? categoryName;
  final String title;
  final String? description;
  final int amount;
  final int expenseDate;
  final ExpensePaymentMethod paymentMethod;
  final int createdBy;
  final String? createdByName;
  final String? supplier;
  final String? invoiceNumber;
  final ExpenseRepeatSchedule repeatSchedule;
  final ExpenseStatus status;
  final int createdAt;
  final int updatedAt;
  final List<ExpenseAttachment> attachments;

  bool get isValidated => status == ExpenseStatus.validated;

  bool get affectsCash => isValidated &&
      (paymentMethod == ExpensePaymentMethod.cash ||
          paymentMethod == ExpensePaymentMethod.mtnMomo ||
          paymentMethod == ExpensePaymentMethod.moovMoney);

  @override
  List<Object?> get props => [
        id,
        shopId,
        categoryId,
        categoryName,
        title,
        amount,
        expenseDate,
        paymentMethod,
        status,
        attachments,
      ];
}

class ExpenseSummaryPeriod extends Equatable {
  const ExpenseSummaryPeriod({
    required this.expenseCount,
    required this.totalAmount,
  });

  final int expenseCount;
  final int totalAmount;

  @override
  List<Object?> get props => [expenseCount, totalAmount];
}

class ExpenseSummary extends Equatable {
  const ExpenseSummary({
    required this.today,
    required this.week,
    required this.month,
    required this.cashCollectedToday,
    required this.cashExpensesToday,
    required this.estimatedCashBalance,
  });

  final ExpenseSummaryPeriod today;
  final ExpenseSummaryPeriod week;
  final ExpenseSummaryPeriod month;
  final int cashCollectedToday;
  final int cashExpensesToday;
  final int estimatedCashBalance;

  @override
  List<Object?> get props =>
      [today, week, month, cashCollectedToday, cashExpensesToday, estimatedCashBalance];
}

class ExpenseByCategory extends Equatable {
  const ExpenseByCategory({
    this.categoryId,
    required this.categoryName,
    required this.expenseCount,
    required this.totalAmount,
    this.budgetAmount,
  });

  final int? categoryId;
  final String categoryName;
  final int expenseCount;
  final int totalAmount;
  final int? budgetAmount;

  @override
  List<Object?> get props =>
      [categoryId, categoryName, expenseCount, totalAmount, budgetAmount];
}

class ExpenseNetProfit extends Equatable {
  const ExpenseNetProfit({
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.profitAvailable,
    this.profitWarning,
  });

  final int? grossProfit;
  final int totalExpenses;
  final int? netProfit;
  final bool profitAvailable;
  final String? profitWarning;

  @override
  List<Object?> get props =>
      [grossProfit, totalExpenses, netProfit, profitAvailable, profitWarning];
}

class CreateExpenseInput extends Equatable {
  const CreateExpenseInput({
    this.categoryId,
    required this.title,
    this.description,
    required this.amount,
    required this.expenseDate,
    required this.paymentMethod,
    this.supplier,
    this.invoiceNumber,
    this.repeatSchedule = ExpenseRepeatSchedule.none,
    this.status = ExpenseStatus.validated,
    this.attachmentPaths = const [],
  });

  final int? categoryId;
  final String title;
  final String? description;
  final int amount;
  final int expenseDate;
  final ExpensePaymentMethod paymentMethod;
  final String? supplier;
  final String? invoiceNumber;
  final ExpenseRepeatSchedule repeatSchedule;
  final ExpenseStatus status;
  final List<String> attachmentPaths;

  @override
  List<Object?> get props => [title, amount, expenseDate, paymentMethod];
}

class ExpenseListFilters extends Equatable {
  const ExpenseListFilters({
    this.fromMs,
    this.toMs,
    this.categoryId,
    this.paymentMethod,
    this.search,
  });

  final int? fromMs;
  final int? toMs;
  final int? categoryId;
  final ExpensePaymentMethod? paymentMethod;
  final String? search;

  @override
  List<Object?> get props => [fromMs, toMs, categoryId, paymentMethod, search];
}

class ExpenseDetail extends Equatable {
  const ExpenseDetail({
    required this.expense,
    required this.history,
  });

  final Expense expense;
  final List<ExpenseHistoryEntry> history;

  @override
  List<Object?> get props => [expense, history];
}
