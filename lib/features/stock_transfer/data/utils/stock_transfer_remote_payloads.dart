import '../../domain/entities/stock_transfer.dart';

class StockTransferRemotePayloads {
  const StockTransferRemotePayloads._();

  static Map<String, dynamic> createBody({
    required int destinationShopId,
    required String reference,
    String? notes,
    required List<Map<String, dynamic>> items,
    String? transferType,
    int? parentTransferId,
  }) {
    return {
      'destinationShopId': destinationShopId,
      'reference': reference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (transferType != null) 'transferType': transferType,
      if (parentTransferId != null) 'parentTransferId': parentTransferId,
      'items': items
          .map(
            (it) => {
              'productId': it['productId'] as int,
              'quantityRequested': it['quantityRequested'] as int,
            },
          )
          .toList(),
    };
  }

  static Map<String, dynamic> shipBody({
    required String label,
    String? notes,
    String? driverName,
    String? vehiclePlate,
    required Map<int, int> quantitiesByItemId,
    required List<Map<String, dynamic>> remoteItems,
  }) {
    final byLocalId = <int, int>{...quantitiesByItemId};
    final items = <Map<String, dynamic>>[];
    for (final raw in remoteItems) {
      final localItemId = raw['localItemId'] as int?;
      final remoteItemId = raw['remoteItemId'] as int?;
      if (localItemId == null || remoteItemId == null) continue;
      final qty = byLocalId[localItemId];
      if (qty == null || qty <= 0) continue;
      items.add({
        'itemId': remoteItemId,
        'quantity': qty,
      });
    }

    return {
      'label': label,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (driverName != null && driverName.trim().isNotEmpty)
        'driverName': driverName.trim(),
      if (vehiclePlate != null && vehiclePlate.trim().isNotEmpty)
        'vehiclePlate': vehiclePlate.trim(),
      'items': items,
    };
  }

  static Map<String, dynamic> receiveBody({
    required Map<int, int> quantitiesByItemId,
    required List<Map<String, dynamic>> remoteItems,
    Map<int, StockTransferReceiveRefusal> refusalsByItemId = const {},
    List<Map<String, dynamic>> productSetups = const [],
    int? shipmentId,
  }) {
    final byLocalId = <int, int>{...quantitiesByItemId};
    final byLocalIdRefused = {...refusalsByItemId};
    final setupsByLocalItemId = {
      for (final setup in productSetups)
        setup['itemId'] as int: setup,
    };

    final items = <Map<String, dynamic>>[];
    for (final raw in remoteItems) {
      final localItemId = raw['localItemId'] as int?;
      final remoteItemId = raw['remoteItemId'] as int?;
      if (localItemId == null || remoteItemId == null) continue;

      final qty = byLocalId[localItemId] ?? 0;
      final refused = byLocalIdRefused[localItemId];
      final refusedQty = refused?.quantity ?? 0;
      if (qty <= 0 && refusedQty <= 0) continue;

      final itemBody = <String, dynamic>{
        'itemId': remoteItemId,
        'quantityReceived': qty,
      };

      if (refusedQty > 0 && refused != null) {
        itemBody['quantityRefused'] = refusedQty;
        itemBody['refusalReason'] = refused.reason;
        itemBody['refusalResolution'] = refused.resolution;
      }

      final setup = setupsByLocalItemId[localItemId];
      if (setup != null) {
        itemBody['productSetup'] = {
          'name': setup['name'],
          'priceSell': setup['priceSell'],
          if (setup['productServerId'] != null)
            'productServerId': setup['productServerId'],
          if (setup['priceBuy'] != null) 'priceBuy': setup['priceBuy'],
        };
      }

      items.add(itemBody);
    }

    return {
      if (shipmentId != null) 'shipmentId': shipmentId,
      'items': items,
    };
  }

  static Map<String, dynamic> closeBody({String? notes}) {
    return {if (notes != null && notes.isNotEmpty) 'notes': notes};
  }

  static Map<String, dynamic> resolveDiscrepancyBody({
    required int itemId,
    required int quantity,
    required String reason,
    required String resolution,
    String? notes,
  }) {
    return {
      'itemId': itemId,
      'quantity': quantity,
      'reason': reason,
      'resolution': resolution,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
  }
}
