import '../entities/stock_transfer.dart';
import '../../data/utils/stock_transfer_qr_payload.dart';

abstract class StockTransferRepository {
  Future<List<ShopOption>> listDestinationShops({required int currentShopId});

  Future<List<StockTransfer>> listOutgoing({required int shopId});

  Future<List<StockTransfer>> listIncoming({required int shopId});

  Future<List<StockTransfer>> listInTransit({required int shopId});

  Future<StockTransfer?> findTransfer({
    required int transferId,
    required int shopId,
  });

  Future<List<TransferMissingDestinationProduct>> listMissingDestinationProducts({
    required int destinationShopId,
    required int transferId,
    Map<int, int>? quantitiesByItemId,
    int? shipmentId,
  });

  Future<String> nextReference({required int shopId});

  Future<StockTransfer> createTransfer({
    required int sourceShopId,
    required int destinationShopId,
    required int userId,
    required String reference,
    String? notes,
    required List<Map<String, dynamic>> items,
  });

  Future<StockTransfer> validateTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  });

  Future<StockTransfer> submitTransferForApproval({
    required int sourceShopId,
    required int userId,
    required int transferId,
  });

  Future<StockTransfer> approveTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  });

  Future<StockTransfer> shipTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
    required String shipmentLabel,
    String? shipmentNotes,
    String? driverName,
    String? vehiclePlate,
    Map<int, int>? quantitiesByItemId,
  });

  Future<StockTransfer> receiveTransfer({
    required int destinationShopId,
    required int userId,
    required int transferId,
    Map<int, int>? quantitiesByItemId,
    Map<int, int>? salePriceByItemId,
    Map<int, StockTransferReceiveRefusal>? refusalsByItemId,
    int? shipmentId,
  });

  Future<void> cancelTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
  });

  Future<StockTransfer> closeTransfer({
    required int sourceShopId,
    required int userId,
    required int transferId,
    String? notes,
  });

  Future<StockTransfer> resolveDiscrepancy({
    required int sourceShopId,
    required int userId,
    required int transferId,
    required int itemId,
    required int quantity,
    required String reason,
    required String resolution,
    String? notes,
  });

  Future<StockTransferReportSummary> buildReportSummary({required int shopId});

  /// Ids locaux équivalents (même boutique cloud).
  Future<Set<int>> shopAliases(int shopId);

  Future<StockTransferQrReceiveIntent> resolveQrReceiveIntent({
    required String rawPayload,
    required int destinationShopId,
  });

  Future<StockTransferQrPayload> buildShipmentQrPayload({
    required int transferId,
    required int shipmentId,
  });

  Future<StockTransfer> createReturnTransfer({
    required int shopId,
    required int userId,
    required int parentTransferId,
    Map<int, int>? quantitiesByParentItemId,
  });

  Future<void> syncFromRemote({
    required int shopId,
    bool force = false,
    int? importUserId,
  });
}
