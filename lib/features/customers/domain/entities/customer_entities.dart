import 'package:equatable/equatable.dart';
import '../../../debts/domain/entities/debt_entities.dart';

enum CustomerSort { name, debt, lastActivity }

class CustomerDetail extends Equatable {
  const CustomerDetail({
    required this.customer,
    required this.sales,
    required this.debts,
    this.paidDebts = const [],
    this.forgivenDebts = const [],
  });

  final Customer customer;
  final List<CustomerSaleSummary> sales;
  /// Dettes ouvertes ou partielles.
  final List<Debt> debts;
  /// Dettes entièrement remboursées (statut `paid`).
  final List<Debt> paidDebts;
  /// Dettes pardonnées (statut `forgiven`).
  final List<ForgivenDebtEntry> forgivenDebts;

  @override
  List<Object?> get props => [customer, sales, debts, paidDebts, forgivenDebts];
}

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.address,
    this.note,
    this.isArchived = false,
    this.isShared = false,
    this.balanceDue = 0,
    this.openDebtsCount = 0,
    this.purchaseCount = 0,
    this.totalPurchases = 0,
    this.lifetimePurchaseCount = 0,
    this.lifetimeTotalPurchases = 0,
    this.lifetimeLastActivityAt,
    this.lastActivityAt,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.serverId,
    this.phoneWarning,
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
  final int lifetimePurchaseCount;
  final int lifetimeTotalPurchases;
  final int? lifetimeLastActivityAt;
  final int? lastActivityAt;
  final int createdAt;
  final int updatedAt;
  final String? serverId;
  final String? phoneWarning;

  int? get apiId => serverId != null ? int.tryParse(serverId!) : null;

  bool get hasDebt => balanceDue > 0;

  bool get isCriticalDebt {
    if (!hasDebt || lastActivityAt == null) return false;
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    return DateTime.now().millisecondsSinceEpoch - lastActivityAt! >= thirtyDaysMs;
  }

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? note,
    bool? isArchived,
    bool? isShared,
    int? balanceDue,
    int? openDebtsCount,
    int? purchaseCount,
    int? totalPurchases,
    int? lifetimePurchaseCount,
    int? lifetimeTotalPurchases,
    int? lifetimeLastActivityAt,
    int? lastActivityAt,
    int? createdAt,
    int? updatedAt,
    String? serverId,
    String? phoneWarning,
  }) {
    return Customer(
      id: id,
      shopId: shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      isArchived: isArchived ?? this.isArchived,
      isShared: isShared ?? this.isShared,
      balanceDue: balanceDue ?? this.balanceDue,
      openDebtsCount: openDebtsCount ?? this.openDebtsCount,
      purchaseCount: purchaseCount ?? this.purchaseCount,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      lifetimePurchaseCount:
          lifetimePurchaseCount ?? this.lifetimePurchaseCount,
      lifetimeTotalPurchases:
          lifetimeTotalPurchases ?? this.lifetimeTotalPurchases,
      lifetimeLastActivityAt:
          lifetimeLastActivityAt ?? this.lifetimeLastActivityAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverId: serverId ?? this.serverId,
      phoneWarning: phoneWarning ?? this.phoneWarning,
    );
  }

  bool isFromOtherShop(int currentShopId) =>
      isShared && shopId != currentShopId;

  @override
  List<Object?> get props =>
      [id, shopId, name, phone, balanceDue, isArchived, isShared];
}

class CustomerSaleSummary extends Equatable {
  const CustomerSaleSummary({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.receiptNumber,
    this.shopId,
    this.shopName,
  });

  final int id;
  final String? receiptNumber;
  final int totalAmount;
  final String status;
  final int createdAt;
  final int? shopId;
  final String? shopName;

  @override
  List<Object?> get props =>
      [id, receiptNumber, totalAmount, createdAt, shopId, shopName];
}

class CreateCustomerInput extends Equatable {
  const CreateCustomerInput({
    required this.name,
    this.phone,
    this.address,
    this.note,
    this.isShared = false,
  });

  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final bool isShared;

  @override
  List<Object?> get props => [name, phone, address, note, isShared];
}

class UpdateCustomerInput extends Equatable {
  const UpdateCustomerInput({
    this.name,
    this.phone,
    this.address,
    this.note,
    this.isShared,
  });

  final String? name;
  final String? phone;
  final String? address;
  final String? note;
  final bool? isShared;

  @override
  List<Object?> get props => [name, phone, address, note, isShared];
}

class DebtorSummary extends Equatable {
  const DebtorSummary({
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

  @override
  List<Object?> get props => [customerId, customerName, balanceDue];
}

class DebtorsOverview extends Equatable {
  const DebtorsOverview({
    required this.totalDebt,
    required this.debtorCount,
    required this.debtors,
  });

  final int totalDebt;
  final int debtorCount;
  final List<DebtorSummary> debtors;

  @override
  List<Object?> get props => [totalDebt, debtorCount, debtors];
}

class DebtReminder extends Equatable {
  const DebtReminder({
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

  @override
  List<Object?> get props => [customerId, message, whatsappUrl];
}

class CustomerListFilters extends Equatable {
  const CustomerListFilters({
    this.search = '',
    this.hasDebtOnly = false,
    this.includeArchived = false,
    this.sort = CustomerSort.name,
    this.limit = 100,
  });

  final String search;
  final bool hasDebtOnly;
  final bool includeArchived;
  final CustomerSort sort;
  final int limit;

  CustomerListFilters copyWith({
    String? search,
    bool clearSearch = false,
    bool? hasDebtOnly,
    bool? includeArchived,
    CustomerSort? sort,
    int? limit,
  }) {
    return CustomerListFilters(
      search: clearSearch ? '' : (search ?? this.search),
      hasDebtOnly: hasDebtOnly ?? this.hasDebtOnly,
      includeArchived: includeArchived ?? this.includeArchived,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
    );
  }

  @override
  List<Object?> get props =>
      [search, hasDebtOnly, includeArchived, sort, limit];
}
