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
    this.customerId,
    this.amountCash = 0,
    this.amountMomo = 0,
    this.amountCredit = 0,
    this.paymentMethod,
  });

  final int id;
  final String receiptNumber;
  final String saleType;
  final int totalAmount;
  final String status;
  final int createdAt;
  final int? customerId;
  final int amountCash;
  final int amountMomo;
  final int amountCredit;
  final String? paymentMethod;

  factory SaleListItemApiDto.fromJson(Map<String, dynamic> json) {
    return SaleListItemApiDto(
      id: json['id'] as int,
      receiptNumber: json['receiptNumber'] as String? ?? '',
      saleType: json['saleType'] as String? ?? 'standard',
      totalAmount: json['totalAmount'] as int? ?? 0,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['createdAt'] as int,
      customerId: json['customerId'] as int?,
      amountCash: json['amountCash'] as int? ?? 0,
      amountMomo: json['amountMomo'] as int? ?? 0,
      amountCredit: json['amountCredit'] as int? ?? 0,
      paymentMethod: json['paymentMethod'] as String?,
    );
  }
}

class SaleDetailApiDto {
  const SaleDetailApiDto({
    required this.id,
    required this.receiptNumber,
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
    this.customerId,
    required this.userId,
    this.note,
    required this.createdAt,
    required this.items,
  });

  final int id;
  final String receiptNumber;
  final String saleType;
  final int subtotal;
  final int discountAmount;
  final int totalAmount;
  final int amountPaid;
  final int amountCash;
  final int amountMomo;
  final int amountCredit;
  final String paymentMethod;
  final String status;
  final int? customerId;
  final int userId;
  final String? note;
  final int createdAt;
  final List<SaleDetailItemApiDto> items;

  factory SaleDetailApiDto.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    return SaleDetailApiDto(
      id: json['id'] as int,
      receiptNumber: json['receiptNumber'] as String? ?? '',
      saleType: json['saleType'] as String? ?? 'standard',
      subtotal: json['subtotal'] as int? ?? 0,
      discountAmount: json['discountAmount'] as int? ?? 0,
      totalAmount: json['totalAmount'] as int? ?? 0,
      amountPaid: json['amountPaid'] as int? ?? 0,
      amountCash: json['amountCash'] as int? ?? 0,
      amountMomo: json['amountMomo'] as int? ?? 0,
      amountCredit: json['amountCredit'] as int? ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      status: json['status'] as String? ?? 'completed',
      customerId: json['customerId'] as int?,
      userId: json['userId'] as int,
      note: json['note'] as String?,
      createdAt: json['createdAt'] as int,
      items: itemsList
          .whereType<Map<String, dynamic>>()
          .map(SaleDetailItemApiDto.fromJson)
          .toList(),
    );
  }
}

class SaleDetailItemApiDto {
  const SaleDetailItemApiDto({
    required this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unitCost,
    required this.lineTotal,
  });

  final int id;
  final int? productId;
  final String productName;
  final double quantity;
  final int unitPrice;
  final int? unitCost;
  final int lineTotal;

  factory SaleDetailItemApiDto.fromJson(Map<String, dynamic> json) {
    return SaleDetailItemApiDto(
      id: json['id'] as int,
      productId: json['productId'] as int?,
      productName: json['productName'] as String? ?? '',
      quantity: (json['quantity'] as num? ?? 0).toDouble(),
      unitPrice: json['unitPrice'] as int? ?? 0,
      unitCost: (json['unitCost'] as num?)?.toInt(),
      lineTotal: json['lineTotal'] as int? ?? 0,
    );
  }
}
