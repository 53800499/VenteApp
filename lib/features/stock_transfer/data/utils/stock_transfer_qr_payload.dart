import 'dart:convert';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/stock_transfer.dart';

/// Payload QR embarqué (offline-first, lisible cross-appareils).
class StockTransferQrPayload {
  const StockTransferQrPayload({
    required this.reference,
    required this.shipmentLabel,
    required this.shippedAt,
    required this.items,
    this.sourceShopServerId,
    this.destinationShopServerId,
  });

  final String reference;
  final String shipmentLabel;
  final int shippedAt;
  final String? sourceShopServerId;
  final String? destinationShopServerId;
  final List<StockTransferQrPayloadItem> items;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'type': 'stock_transfer_shipment',
        'reference': reference,
        'shipmentLabel': shipmentLabel,
        'shippedAt': shippedAt,
        if (sourceShopServerId != null)
          'sourceShopServerId': sourceShopServerId,
        if (destinationShopServerId != null)
          'destinationShopServerId': destinationShopServerId,
        'items': items.map((i) => i.toJson()).toList(),
      };

  static StockTransferQrPayload fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? [];
    return StockTransferQrPayload(
      reference: json['reference'] as String? ?? '',
      shipmentLabel: json['shipmentLabel'] as String? ?? '',
      shippedAt: (json['shippedAt'] as num?)?.toInt() ?? 0,
      sourceShopServerId: json['sourceShopServerId']?.toString(),
      destinationShopServerId: json['destinationShopServerId']?.toString(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(StockTransferQrPayloadItem.fromJson)
          .toList(),
    );
  }

  static const prefix = 'arike:trf:';

  String encode() {
    final jsonStr = jsonEncode(toJson());
    return '$prefix${base64Url.encode(utf8.encode(jsonStr))}';
  }

  static StockTransferQrPayload decode(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith(prefix)) {
      throw const ValidationFailure('QR transfert invalide.');
    }
    try {
      final payload = trimmed.substring(prefix.length);
      final jsonStr = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (map['type'] != 'stock_transfer_shipment') {
        throw const ValidationFailure('Type de QR non reconnu.');
      }
      return fromJson(map);
    } catch (_) {
      throw const ValidationFailure('Impossible de lire le QR de l\'expédition.');
    }
  }
}

class StockTransferQrPayloadItem {
  const StockTransferQrPayloadItem({
    required this.productServerId,
    required this.quantity,
    this.productName,
  });

  final String productServerId;
  final int quantity;
  final String? productName;

  Map<String, dynamic> toJson() => {
        'productServerId': productServerId,
        'quantity': quantity,
        if (productName != null) 'productName': productName,
      };

  static StockTransferQrPayloadItem fromJson(Map<String, dynamic> json) {
    return StockTransferQrPayloadItem(
      productServerId: json['productServerId']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      productName: json['productName'] as String?,
    );
  }
}

StockTransferQrPayload buildShipmentQrPayload({
  required StockTransfer transfer,
  required StockTransferShipment shipment,
  String? sourceShopServerId,
  String? destinationShopServerId,
}) {
  final items = <StockTransferQrPayloadItem>[];
  for (final item in transfer.items ?? []) {
    final qty = item.quantityInShipment(shipment.id);
    if (qty <= 0) continue;
    final serverId = item.productServerId;
    if (serverId == null || serverId.isEmpty) continue;
    items.add(
      StockTransferQrPayloadItem(
        productServerId: serverId,
        quantity: qty,
        productName: item.productName,
      ),
    );
  }

  return StockTransferQrPayload(
    reference: transfer.reference,
    shipmentLabel: shipment.label,
    shippedAt: shipment.shippedAt,
    sourceShopServerId: sourceShopServerId,
    destinationShopServerId: destinationShopServerId,
    items: items,
  );
}
