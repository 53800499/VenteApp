import '../../domain/entities/customer_entities.dart';
import '../../../debts/data/models/debt_api_models.dart';

class CustomerDetailApiDto {
  CustomerDetailApiDto({
    required this.customer,
    required this.sales,
    required this.debts,
  });

  final CustomerApiDto customer;
  final List<CustomerSaleApiDto> sales;
  final List<DebtApiDto> debts;

  factory CustomerDetailApiDto.fromJson(Map<String, dynamic> json) {
    final customerJson = json['customer'] ?? json;
    final salesJson = json['sales'] ?? [];
    final debtsJson = json['debts'] ?? [];

    return CustomerDetailApiDto(
      customer: CustomerApiDto.fromJson(customerJson as Map<String, dynamic>),
      sales: (salesJson as List)
          .whereType<Map<String, dynamic>>()
          .map(CustomerSaleApiDto.fromJson)
          .toList(),
      debts: (debtsJson as List)
          .whereType<Map<String, dynamic>>()
          .map(DebtApiDto.fromJson)
          .toList(),
    );
  }
}

class CustomerApiDto {
  CustomerApiDto({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.note,
    this.isArchived = false,
    this.isShared = false,
    this.address,
    this.balanceDue = 0,
    this.openDebtsCount = 0,
    this.purchaseCount = 0,
    this.totalPurchases = 0,
    this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
    this.phoneWarning,
    this.recentSales,
  });

  final int id;
  final int shopId;
  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final bool isArchived;
  final bool isShared;
  final int balanceDue;
  final int openDebtsCount;
  final int purchaseCount;
  final int totalPurchases;
  final int? lastActivityAt;
  final int createdAt;
  final int updatedAt;
  final PhoneWarningDto? phoneWarning;
  final List<CustomerSaleApiDto>? recentSales;

  factory CustomerApiDto.fromJson(Map<String, dynamic> json) {
    final warning = json['phoneWarning'];
    final sales = json['recentSales'];
    return CustomerApiDto(
      id: json['id'] as int,
      shopId: json['shopId'] as int? ?? 0,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      note: json['note'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      isShared: json['isShared'] as bool? ?? false,
      balanceDue: json['balanceDue'] as int? ?? 0,
      openDebtsCount: json['openDebtsCount'] as int? ?? 0,
      purchaseCount: json['purchaseCount'] as int? ?? 0,
      totalPurchases: json['totalPurchases'] as int? ?? 0,
      lastActivityAt: json['lastActivityAt'] as int?,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      phoneWarning: warning is Map<String, dynamic>
          ? PhoneWarningDto.fromJson(warning)
          : null,
      recentSales: sales is List
          ? sales
              .whereType<Map<String, dynamic>>()
              .map(CustomerSaleApiDto.fromJson)
              .toList()
          : null,
    );
  }

  Customer toEntity({required int localId, required int shopId}) {
    return Customer(
      id: localId,
      shopId: shopId,
      name: name,
      phone: phone,
      address: address,
      note: note,
      isArchived: isArchived,
      isShared: isShared,
      balanceDue: balanceDue,
      openDebtsCount: openDebtsCount,
      purchaseCount: purchaseCount,
      totalPurchases: totalPurchases,
      lastActivityAt: lastActivityAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      serverId: '$id',
      phoneWarning: phoneWarning?.message,
    );
  }
}

class PhoneWarningDto {
  PhoneWarningDto({required this.code, required this.message});

  final String code;
  final String message;

  factory PhoneWarningDto.fromJson(Map<String, dynamic> json) {
    return PhoneWarningDto(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class CustomerSaleApiDto {
  CustomerSaleApiDto({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.receiptNumber,
  });

  final int id;
  final String? receiptNumber;
  final int totalAmount;
  final String status;
  final int createdAt;

  factory CustomerSaleApiDto.fromJson(Map<String, dynamic> json) {
    return CustomerSaleApiDto(
      id: json['id'] as int,
      receiptNumber: json['receiptNumber'] as String?,
      totalAmount: json['totalAmount'] as int,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['createdAt'] as int,
    );
  }

  CustomerSaleSummary toEntity() {
    return CustomerSaleSummary(
      id: id,
      receiptNumber: receiptNumber,
      totalAmount: totalAmount,
      status: status,
      createdAt: createdAt,
    );
  }
}

class DebtorsApiDto {
  DebtorsApiDto({
    required this.totalDebt,
    required this.debtorCount,
    required this.debtors,
  });

  final int totalDebt;
  final int debtorCount;
  final List<DebtorApiDto> debtors;

  factory DebtorsApiDto.fromJson(Map<String, dynamic> json) {
    final list = json['debtors'];
    return DebtorsApiDto(
      totalDebt: json['totalDebt'] as int? ?? 0,
      debtorCount: json['debtorCount'] as int? ?? 0,
      debtors: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(DebtorApiDto.fromJson)
              .toList()
          : [],
    );
  }

  DebtorsOverview toEntity() {
    return DebtorsOverview(
      totalDebt: totalDebt,
      debtorCount: debtorCount,
      debtors: debtors.map((d) => d.toEntity()).toList(),
    );
  }
}

class DebtorApiDto {
  DebtorApiDto({
    required this.customerId,
    required this.customerName,
    required this.balanceDue,
    required this.openDebtsCount,
    required this.oldestDebtAt,
    this.phone,
    this.isCritical = false,
  });

  final int customerId;
  final String customerName;
  final String? phone;
  final int balanceDue;
  final int openDebtsCount;
  final int oldestDebtAt;
  final bool isCritical;

  factory DebtorApiDto.fromJson(Map<String, dynamic> json) {
    return DebtorApiDto(
      customerId: json['customerId'] as int,
      customerName: json['customerName'] as String,
      phone: json['phone'] as String?,
      balanceDue: json['balanceDue'] as int? ?? 0,
      openDebtsCount: json['openDebtsCount'] as int? ?? 0,
      oldestDebtAt: json['oldestDebtAt'] as int? ?? 0,
      isCritical: json['isCritical'] as bool? ?? false,
    );
  }

  DebtorSummary toEntity() {
    return DebtorSummary(
      customerId: customerId,
      customerName: customerName,
      phone: phone,
      balanceDue: balanceDue,
      openDebtsCount: openDebtsCount,
      oldestDebtAt: oldestDebtAt,
      isCritical: isCritical,
    );
  }
}

class DebtReminderApiDto {
  DebtReminderApiDto({
    required this.customerId,
    required this.customerName,
    required this.balanceDue,
    required this.message,
    required this.whatsappUrl,
  });

  final int customerId;
  final String customerName;
  final int balanceDue;
  final String message;
  final String whatsappUrl;

  factory DebtReminderApiDto.fromJson(Map<String, dynamic> json) {
    return DebtReminderApiDto(
      customerId: json['customerId'] as int,
      customerName: json['customerName'] as String,
      balanceDue: json['balanceDue'] as int? ?? 0,
      message: json['message'] as String,
      whatsappUrl: json['whatsappUrl'] as String,
    );
  }

  DebtReminder toEntity() => DebtReminder(
        customerId: customerId,
        customerName: customerName,
        balanceDue: balanceDue,
        message: message,
        whatsappUrl: whatsappUrl,
      );
}
