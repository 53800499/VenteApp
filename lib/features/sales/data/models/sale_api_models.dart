import '../../domain/entities/sale_entities.dart';

class CreateStandardSaleApiRequest {
  const CreateStandardSaleApiRequest({
    required this.items,
    required this.payment,
    this.discountAmount = 0,
    this.customerId,
    this.note,
  });

  final List<SaleLineApiRequest> items;
  final int discountAmount;
  final int? customerId;
  final SalePaymentApiRequest payment;
  final String? note;

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        if (discountAmount > 0) 'discountAmount': discountAmount,
        if (customerId != null) 'customerId': customerId,
        'payment': payment.toJson(),
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

class SaleLineApiRequest {
  const SaleLineApiRequest({
    required this.productId,
    required this.quantity,
    this.unitPrice,
    this.lineDiscountAmount = 0,
  });

  final int productId;
  final int quantity;
  final int? unitPrice;
  final int lineDiscountAmount;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
        if (lineDiscountAmount > 0) 'lineDiscountAmount': lineDiscountAmount,
      };
}

class SalePaymentApiRequest {
  const SalePaymentApiRequest({
    required this.method,
    this.amountCash = 0,
    this.amountMomo = 0,
    this.amountCredit = 0,
  });

  final PaymentMethod method;
  final int amountCash;
  final int amountMomo;
  final int amountCredit;

  Map<String, dynamic> toJson() => {
        'method': method.code,
        if (amountCash > 0) 'amountCash': amountCash,
        if (amountMomo > 0) 'amountMomo': amountMomo,
        if (amountCredit > 0) 'amountCredit': amountCredit,
      };
}

class SaleApiDto {
  SaleApiDto({
    required this.id,
    required this.receiptNumber,
    required this.totalAmount,
  });

  final int id;
  final String receiptNumber;
  final int totalAmount;

  factory SaleApiDto.fromJson(Map<String, dynamic> json) {
    return SaleApiDto(
      id: json['id'] as int,
      receiptNumber: json['receiptNumber'] as String? ?? '',
      totalAmount: json['totalAmount'] as int? ?? 0,
    );
  }
}

class SaleListItemApiDto {
  const SaleListItemApiDto({
    required this.id,
    required this.receiptNumber,
    required this.saleType,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String receiptNumber;
  final String saleType;
  final int totalAmount;
  final String status;
  final int createdAt;

  factory SaleListItemApiDto.fromJson(Map<String, dynamic> json) {
    return SaleListItemApiDto(
      id: json['id'] as int,
      receiptNumber: json['receiptNumber'] as String? ?? '',
      saleType: json['saleType'] as String? ?? 'standard',
      totalAmount: json['totalAmount'] as int? ?? 0,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['createdAt'] as int,
    );
  }
}
