/// Corps de requêtes alignés sur les DTO NestJS (`forbidNonWhitelisted`).
abstract final class ProcurementRemotePayloads {
  static Map<String, dynamic> directReceiptItem({
    required int serverProductId,
    required int quantityReceived,
    required int unitCost,
    String? batchNumber,
    int? expiryDate,
  }) {
    return {
      'productId': serverProductId,
      'quantityReceived': quantityReceived,
      'unitCost': unitCost,
      if (batchNumber != null && batchNumber.isNotEmpty)
        'batchNumber': batchNumber,
      if (expiryDate != null) 'expiryDate': expiryDate,
    };
  }

  static Map<String, dynamic> directGoodsReceiptBody({
    required int serverSupplierId,
    required String receiptNumber,
    required int receivedAt,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) {
    return {
      'supplierId': serverSupplierId,
      'receiptNumber': receiptNumber,
      'receivedAt': receivedAt,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': items,
    };
  }

  static Map<String, dynamic> purchaseOrderReceiptItem({
    required int serverPurchaseOrderItemId,
    required int quantityReceived,
    required int unitCost,
    String? batchNumber,
    int? expiryDate,
  }) {
    return {
      'purchaseOrderItemId': serverPurchaseOrderItemId,
      'quantityReceived': quantityReceived,
      'unitCost': unitCost,
      if (batchNumber != null && batchNumber.isNotEmpty)
        'batchNumber': batchNumber,
      if (expiryDate != null) 'expiryDate': expiryDate,
    };
  }

  static Map<String, dynamic> purchaseOrderReceiveBody({
    required String receiptNumber,
    required int receivedAt,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) {
    return {
      'receiptNumber': receiptNumber,
      'receivedAt': receivedAt,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': items,
    };
  }
}
