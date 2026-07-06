class ExpenseCategoryApiDto {
  const ExpenseCategoryApiDto({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
    this.monthlyBudget,
  });

  final int id;
  final String name;
  final String? color;
  final String? icon;
  final bool isSystem;
  final int createdAt;
  final int updatedAt;
  final int? monthlyBudget;

  factory ExpenseCategoryApiDto.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryApiDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      isSystem: json['isSystem'] as bool? ?? false,
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
      monthlyBudget: (json['monthlyBudget'] as num?)?.toInt(),
    );
  }
}

class ExpenseApiDto {
  const ExpenseApiDto({
    required this.id,
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
    this.deletedAt,
  });

  final int id;
  final int? categoryId;
  final String? categoryName;
  final String title;
  final String? description;
  final int amount;
  final int expenseDate;
  final String paymentMethod;
  final int createdBy;
  final String? createdByName;
  final String? supplier;
  final String? invoiceNumber;
  final String repeatSchedule;
  final String status;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  factory ExpenseApiDto.fromJson(Map<String, dynamic> json) {
    return ExpenseApiDto(
      id: (json['id'] as num).toInt(),
      categoryId: (json['categoryId'] as num?)?.toInt(),
      categoryName: json['categoryName'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toInt(),
      expenseDate: (json['expenseDate'] as num).toInt(),
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      createdBy: (json['createdBy'] as num).toInt(),
      createdByName: json['createdByName'] as String?,
      supplier: json['supplier'] as String?,
      invoiceNumber: json['invoiceNumber'] as String?,
      repeatSchedule: json['repeatSchedule'] as String? ?? 'none',
      status: json['status'] as String? ?? 'validated',
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
      deletedAt: (json['deletedAt'] as num?)?.toInt(),
    );
  }
}

class ExpenseHistoryApiDto {
  const ExpenseHistoryApiDto({
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

  factory ExpenseHistoryApiDto.fromJson(Map<String, dynamic> json) {
    return ExpenseHistoryApiDto(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      userName: json['userName'] as String?,
      fieldName: json['fieldName'] as String,
      oldValue: json['oldValue'] as String?,
      newValue: json['newValue'] as String?,
      createdAt: (json['createdAt'] as num).toInt(),
    );
  }
}
