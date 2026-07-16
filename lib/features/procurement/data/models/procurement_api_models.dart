import '../../domain/entities/procurement.dart';

class SupplierApiDto {
  const SupplierApiDto({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.serverId,
  });

  final int id;
  final int shopId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final int version;
  final String? serverId;

  factory SupplierApiDto.fromJson(Map<String, dynamic> json) {
    return SupplierApiDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
      version: (json['version'] as num? ?? 1).toInt(),
      serverId: json['serverId'] as String?,
    );
  }

  Supplier toEntity() => Supplier(
        id: id,
        shopId: shopId,
        name: name,
        phone: phone,
        email: email,
        address: address,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        version: version,
        serverId: serverId,
      );
}

class PurchaseOrderApiDto {
  const PurchaseOrderApiDto({
    required this.id,
    required this.shopId,
    required this.supplierId,
    this.supplierName,
    required this.number,
    required this.status,
    required this.orderedAt,
    this.expectedAt,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.notes,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.serverId,
    this.items,
  });

  final int id;
  final int shopId;
  final int supplierId;
  final String? supplierName;
  final String number;
  final String status;
  final int orderedAt;
  final int? expectedAt;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  final String? notes;
  final int createdBy;
  final String? createdByName;
  final int createdAt;
  final int updatedAt;
  final int version;
  final String? serverId;
  final List<PurchaseOrderItemApiDto>? items;

  factory PurchaseOrderApiDto.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderApiDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      supplierId: (json['supplierId'] as num).toInt(),
      supplierName: json['supplierName'] as String?,
      number: json['number'] as String,
      status: json['status'] as String? ?? 'draft',
      orderedAt: (json['orderedAt'] as num).toInt(),
      expectedAt: (json['expectedAt'] as num?)?.toInt(),
      subtotal: (json['subtotal'] as num).toInt(),
      discount: (json['discount'] as num? ?? 0).toInt(),
      tax: (json['tax'] as num? ?? 0).toInt(),
      total: (json['total'] as num).toInt(),
      notes: json['notes'] as String?,
      createdBy: (json['createdBy'] as num).toInt(),
      createdByName: json['createdByName'] as String?,
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
      version: (json['version'] as num? ?? 1).toInt(),
      serverId: json['serverId'] as String?,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((it) => PurchaseOrderItemApiDto.fromJson(it as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  PurchaseOrderStatus _parseStatus(String value) {
    if (value == 'partially_received') {
      return PurchaseOrderStatus.partiallyReceived;
    }
    return PurchaseOrderStatus.values.firstWhere(
      (e) => e.name == value || e.toString().split('.').last == value,
      orElse: () => PurchaseOrderStatus.draft,
    );
  }

  PurchaseOrder toEntity() => PurchaseOrder(
        id: id,
        shopId: shopId,
        supplierId: supplierId,
        supplierName: supplierName,
        number: number,
        status: _parseStatus(status),
        orderedAt: orderedAt,
        expectedAt: expectedAt,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        notes: notes,
        createdBy: createdBy,
        createdByName: createdByName,
        createdAt: createdAt,
        updatedAt: updatedAt,
        version: version,
        serverId: serverId,
        items: items?.map((it) => it.toEntity()).toList(),
      );
}

class PurchaseOrderItemApiDto {
  const PurchaseOrderItemApiDto({
    required this.id,
    required this.shopId,
    required this.purchaseOrderId,
    required this.productId,
    this.productName,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
    required this.discount,
    required this.tax,
    required this.subtotal,
    required this.version,
    this.serverId,
  });

  final int id;
  final int shopId;
  final int purchaseOrderId;
  final int productId;
  final String? productName;
  final int quantityOrdered;
  final int quantityReceived;
  final int unitCost;
  final int discount;
  final int tax;
  final int subtotal;
  final int version;
  final String? serverId;

  factory PurchaseOrderItemApiDto.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemApiDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      purchaseOrderId: (json['purchaseOrderId'] as num).toInt(),
      productId: (json['productId'] as num).toInt(),
      productName: json['productName'] as String?,
      quantityOrdered: (json['quantityOrdered'] as num).toInt(),
      quantityReceived: (json['quantityReceived'] as num? ?? 0).toInt(),
      unitCost: (json['unitCost'] as num).toInt(),
      discount: (json['discount'] as num? ?? 0).toInt(),
      tax: (json['tax'] as num? ?? 0).toInt(),
      subtotal: (json['subtotal'] as num).toInt(),
      version: (json['version'] as num? ?? 1).toInt(),
      serverId: json['serverId'] as String?,
    );
  }

  PurchaseOrderItem toEntity() => PurchaseOrderItem(
        id: id,
        shopId: shopId,
        purchaseOrderId: purchaseOrderId,
        productId: productId,
        productName: productName,
        quantityOrdered: quantityOrdered,
        quantityReceived: quantityReceived,
        unitCost: unitCost,
        discount: discount,
        tax: tax,
        subtotal: subtotal,
        version: version,
        serverId: serverId,
      );
}

class PurchaseReceiptApiDto {
  const PurchaseReceiptApiDto({
    required this.id,
    required this.shopId,
    this.purchaseOrderId,
    required this.supplierId,
    this.receiptType = PurchaseReceiptType.fromOrder,
    required this.receiptNumber,
    required this.receivedAt,
    required this.receivedBy,
    this.receivedByName,
    this.notes,
    required this.version,
    this.serverId,
    this.items,
  });

  final int id;
  final int shopId;
  final int? purchaseOrderId;
  final int supplierId;
  final String receiptType;
  final String receiptNumber;
  final int receivedAt;
  final int receivedBy;
  final String? receivedByName;
  final String? notes;
  final int version;
  final String? serverId;
  final List<PurchaseReceiptItemApiDto>? items;

  factory PurchaseReceiptApiDto.fromJson(Map<String, dynamic> json) {
    return PurchaseReceiptApiDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      purchaseOrderId: json['purchaseOrderId'] == null
          ? null
          : (json['purchaseOrderId'] as num).toInt(),
      supplierId: (json['supplierId'] as num).toInt(),
      receiptType: json['receiptType'] as String? ?? PurchaseReceiptType.fromOrder,
      receiptNumber: json['receiptNumber'] as String,
      receivedAt: (json['receivedAt'] as num).toInt(),
      receivedBy: (json['receivedBy'] as num).toInt(),
      receivedByName: json['receivedByName'] as String?,
      notes: json['notes'] as String?,
      version: (json['version'] as num? ?? 1).toInt(),
      serverId: json['serverId'] as String?,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((it) => PurchaseReceiptItemApiDto.fromJson(it as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  PurchaseReceipt toEntity() => PurchaseReceipt(
        id: id,
        shopId: shopId,
        purchaseOrderId: purchaseOrderId,
        supplierId: supplierId,
        receiptType: receiptType,
        receiptNumber: receiptNumber,
        receivedAt: receivedAt,
        receivedBy: receivedBy,
        receivedByName: receivedByName,
        notes: notes,
        version: version,
        serverId: serverId,
        items: items?.map((it) => it.toEntity()).toList(),
      );
}

class PurchaseReceiptItemApiDto {
  const PurchaseReceiptItemApiDto({
    required this.id,
    required this.shopId,
    required this.purchaseReceiptId,
    this.purchaseOrderItemId,
    required this.productId,
    this.productName,
    required this.quantityReceived,
    required this.unitCost,
    this.batchNumber,
    this.expiryDate,
    required this.version,
    this.serverId,
  });

  final int id;
  final int shopId;
  final int purchaseReceiptId;
  final int? purchaseOrderItemId;
  final int productId;
  final String? productName;
  final int quantityReceived;
  final int unitCost;
  final String? batchNumber;
  final int? expiryDate;
  final int version;
  final String? serverId;

  factory PurchaseReceiptItemApiDto.fromJson(Map<String, dynamic> json) {
    return PurchaseReceiptItemApiDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      purchaseReceiptId: (json['purchaseReceiptId'] as num).toInt(),
      purchaseOrderItemId: json['purchaseOrderItemId'] == null
          ? null
          : (json['purchaseOrderItemId'] as num).toInt(),
      productId: (json['productId'] as num).toInt(),
      productName: json['productName'] as String?,
      quantityReceived: (json['quantityReceived'] as num).toInt(),
      unitCost: (json['unitCost'] as num).toInt(),
      batchNumber: json['batchNumber'] as String?,
      expiryDate: (json['expiryDate'] as num?)?.toInt(),
      version: (json['version'] as num? ?? 1).toInt(),
      serverId: json['serverId'] as String?,
    );
  }

  PurchaseReceiptItem toEntity() => PurchaseReceiptItem(
        id: id,
        shopId: shopId,
        purchaseReceiptId: purchaseReceiptId,
        purchaseOrderItemId: purchaseOrderItemId,
        productId: productId,
        productName: productName,
        quantityReceived: quantityReceived,
        unitCost: unitCost,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        version: version,
        serverId: serverId,
      );
}

class SupplierInvoiceApiDto {
  const SupplierInvoiceApiDto({
    required this.id,
    required this.shopId,
    this.purchaseOrderId,
    required this.invoiceNumber,
    required this.supplierId,
    this.supplierName,
    required this.invoiceDate,
    this.dueDate,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.serverId,
    this.payments,
  });

  final int id;
  final int shopId;
  final int? purchaseOrderId;
  final String invoiceNumber;
  final int supplierId;
  final String? supplierName;
  final int invoiceDate;
  final int? dueDate;
  final int subtotal;
  final int tax;
  final int total;
  final String status;
  final int createdAt;
  final int updatedAt;
  final int version;
  final String? serverId;
  final List<SupplierPaymentApiDto>? payments;

  factory SupplierInvoiceApiDto.fromJson(Map<String, dynamic> json) {
    return SupplierInvoiceApiDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      purchaseOrderId: (json['purchaseOrderId'] as num?)?.toInt(),
      invoiceNumber: json['invoiceNumber'] as String,
      supplierId: (json['supplierId'] as num).toInt(),
      supplierName: json['supplierName'] as String?,
      invoiceDate: (json['invoiceDate'] as num).toInt(),
      dueDate: (json['dueDate'] as num?)?.toInt(),
      subtotal: (json['subtotal'] as num).toInt(),
      tax: (json['tax'] as num? ?? 0).toInt(),
      total: (json['total'] as num).toInt(),
      status: json['status'] as String? ?? 'unpaid',
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
      version: (json['version'] as num? ?? 1).toInt(),
      serverId: json['serverId'] as String?,
      payments: json['payments'] != null
          ? (json['payments'] as List)
              .map((it) => SupplierPaymentApiDto.fromJson(it as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  SupplierInvoiceStatus _parseStatus(String value) {
    return SupplierInvoiceStatus.values.firstWhere(
      (e) => e.name == value || e.toString().split('.').last == value,
      orElse: () => SupplierInvoiceStatus.unpaid,
    );
  }

  SupplierInvoice toEntity() => SupplierInvoice(
        id: id,
        shopId: shopId,
        purchaseOrderId: purchaseOrderId,
        invoiceNumber: invoiceNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        subtotal: subtotal,
        tax: tax,
        total: total,
        status: _parseStatus(status),
        createdAt: createdAt,
        updatedAt: updatedAt,
        version: version,
        serverId: serverId,
        payments: payments?.map((it) => it.toEntity()).toList(),
      );
}

class SupplierPaymentApiDto {
  const SupplierPaymentApiDto({
    required this.id,
    required this.shopId,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    this.reference,
    required this.createdAt,
    required this.version,
    this.serverId,
  });

  final int id;
  final int shopId;
  final int invoiceId;
  final int amount;
  final String paymentMethod;
  final int paymentDate;
  final String? reference;
  final int createdAt;
  final int version;
  final String? serverId;

  factory SupplierPaymentApiDto.fromJson(Map<String, dynamic> json) {
    return SupplierPaymentApiDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      invoiceId: (json['invoiceId'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      paymentDate: (json['paymentDate'] as num).toInt(),
      reference: json['reference'] as String?,
      createdAt: (json['createdAt'] as num).toInt(),
      version: (json['version'] as num? ?? 1).toInt(),
      serverId: json['serverId'] as String?,
    );
  }

  PurchasePaymentMethod _parseMethod(String value) {
    if (value == 'mtn_momo') return PurchasePaymentMethod.mtnMomo;
    if (value == 'moov_money') return PurchasePaymentMethod.moovMoney;
    return PurchasePaymentMethod.values.firstWhere(
      (e) => e.name == value || e.toString().split('.').last == value,
      orElse: () => PurchasePaymentMethod.cash,
    );
  }

  SupplierPayment toEntity() => SupplierPayment(
        id: id,
        shopId: shopId,
        invoiceId: invoiceId,
        amount: amount,
        paymentMethod: _parseMethod(paymentMethod),
        paymentDate: paymentDate,
        reference: reference,
        createdAt: createdAt,
        version: version,
        serverId: serverId,
      );
}

class PurchaseOrderHistoryApiDto {
  const PurchaseOrderHistoryApiDto({
    required this.id,
    required this.shopId,
    required this.purchaseOrderId,
    required this.action,
    required this.performedBy,
    this.performedByName,
    required this.performedAt,
    this.details,
  });

  final int id;
  final int shopId;
  final int purchaseOrderId;
  final String action;
  final int performedBy;
  final String? performedByName;
  final int performedAt;
  final String? details;

  factory PurchaseOrderHistoryApiDto.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderHistoryApiDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      purchaseOrderId: (json['purchaseOrderId'] as num).toInt(),
      action: json['action'] as String,
      performedBy: (json['performedBy'] as num).toInt(),
      performedByName: json['performedByName'] as String?,
      performedAt: (json['performedAt'] as num).toInt(),
      details: json['details'] as String?,
    );
  }

  PurchaseOrderHistory toEntity() => PurchaseOrderHistory(
        id: id,
        shopId: shopId,
        purchaseOrderId: purchaseOrderId,
        action: action,
        performedBy: performedBy,
        performedByName: performedByName,
        performedAt: performedAt,
        details: details,
      );
}
