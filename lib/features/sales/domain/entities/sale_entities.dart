import 'package:equatable/equatable.dart';

enum SaleStatus { completed, cancelled }

enum SaleType { standard, quick }

enum PaymentMethod { cash, mtnMomo, moovMoney, credit, mixed }

extension PaymentMethodX on PaymentMethod {
  String get code => switch (this) {
        PaymentMethod.cash => 'cash',
        PaymentMethod.mtnMomo => 'mtn_momo',
        PaymentMethod.moovMoney => 'moov_money',
        PaymentMethod.credit => 'credit',
        PaymentMethod.mixed => 'mixed',
      };

  String get label => switch (this) {
        PaymentMethod.cash => 'Espèces',
        PaymentMethod.mtnMomo => 'MTN MoMo',
        PaymentMethod.moovMoney => 'Moov Money',
        PaymentMethod.credit => 'Crédit',
        PaymentMethod.mixed => 'Mixte',
      };

  static PaymentMethod fromCode(String? code) {
    return switch (code) {
      'mtn_momo' => PaymentMethod.mtnMomo,
      'moov_money' => PaymentMethod.moovMoney,
      'credit' => PaymentMethod.credit,
      'mixed' => PaymentMethod.mixed,
      _ => PaymentMethod.cash,
    };
  }
}

class SaleLineDraft extends Equatable {
  const SaleLineDraft({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.lineDiscountAmount = 0,
  });

  final int productId;
  final int quantity;
  final int unitPrice;
  final int lineDiscountAmount;

  @override
  List<Object?> get props => [productId, quantity, unitPrice, lineDiscountAmount];
}

class PaymentDraft extends Equatable {
  const PaymentDraft({
    required this.method,
    this.amountCash = 0,
    this.amountMomo = 0,
    this.amountCredit = 0,
  });

  final PaymentMethod method;
  final int amountCash;
  final int amountMomo;
  final int amountCredit;

  @override
  List<Object?> get props =>
      [method, amountCash, amountMomo, amountCredit];
}

class SaleItem extends Equatable {
  const SaleItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.unitCost,
    this.discountAmount = 0,
  });

  final int id;
  final int? productId;
  final String productName;
  final int quantity;
  final int unitPrice;
  final int lineTotal;
  final int? unitCost;
  final int discountAmount;

  @override
  List<Object?> get props =>
      [id, productId, productName, quantity, unitPrice, lineTotal];
}

class Sale extends Equatable {
  const Sale({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.saleType,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountCash,
    required this.amountMomo,
    required this.amountCredit,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.receiptNumber,
    this.customerId,
    this.customerName,
    this.note,
    this.updatedAt,
    this.cancelledAt,
    this.cancelledByUserId,
    this.cancelReason,
    this.items = const [],
  });

  final int id;
  final int shopId;
  final int userId;
  final String? receiptNumber;
  final SaleType saleType;
  final int? customerId;
  final String? customerName;
  final int subtotal;
  final int discountAmount;
  final int totalAmount;
  final int amountPaid;
  final int amountCash;
  final int amountMomo;
  final int amountCredit;
  final PaymentMethod paymentMethod;
  final SaleStatus status;
  final String? note;
  final int createdAt;
  final int? updatedAt;
  final int? cancelledAt;
  final int? cancelledByUserId;
  final String? cancelReason;
  final List<SaleItem> items;

  bool get isCancelled => status == SaleStatus.cancelled;

  @override
  List<Object?> get props => [id, receiptNumber, status, totalAmount, createdAt];
}

class SaleListRow extends Equatable {
  const SaleListRow({
    required this.id,
    required this.receiptNumber,
    required this.saleType,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.customerName,
  });

  final int id;
  final String? receiptNumber;
  final SaleType saleType;
  final int totalAmount;
  final SaleStatus status;
  final int createdAt;
  final String? customerName;

  @override
  List<Object?> get props => [id, receiptNumber, totalAmount, createdAt];
}

class SaleCustomerOption extends Equatable {
  const SaleCustomerOption({
    required this.id,
    required this.name,
    this.phone,
  });

  final int id;
  final String name;
  final String? phone;

  @override
  List<Object?> get props => [id, name];
}

class CreateStandardSaleInput extends Equatable {
  const CreateStandardSaleInput({
    required this.items,
    required this.payment,
    this.discountAmount = 0,
    this.customerId,
    this.note,
  });

  final List<SaleLineDraft> items;
  final int discountAmount;
  final int? customerId;
  final PaymentDraft payment;
  final String? note;

  @override
  List<Object?> get props => [items, discountAmount, customerId, payment];
}

class CreateQuickSaleInput extends Equatable {
  const CreateQuickSaleInput({
    required this.totalAmount,
    required this.payment,
    this.note,
  });

  final int totalAmount;
  final PaymentDraft payment;
  final String? note;

  @override
  List<Object?> get props => [totalAmount, payment];
}

class SaleListFilters extends Equatable {
  const SaleListFilters({
    this.search = '',
    this.status,
    this.from,
    this.to,
    this.limit = 50,
  });

  final String search;
  final SaleStatus? status;
  final int? from;
  final int? to;
  final int limit;

  SaleListFilters copyWith({
    String? search,
    bool clearSearch = false,
    SaleStatus? status,
    bool clearStatus = false,
    int? from,
    bool clearFrom = false,
    int? to,
    bool clearTo = false,
    int? limit,
  }) {
    return SaleListFilters(
      search: clearSearch ? '' : (search ?? this.search),
      status: clearStatus ? null : (status ?? this.status),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      limit: limit ?? this.limit,
    );
  }

  @override
  List<Object?> get props => [search, status, from, to, limit];
}
