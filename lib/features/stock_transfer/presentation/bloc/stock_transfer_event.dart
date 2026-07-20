part of 'stock_transfer_bloc.dart';

sealed class StockTransferEvent extends Equatable {
  const StockTransferEvent();

  @override
  List<Object?> get props => [];
}

class StockTransferListLoadRequested extends StockTransferEvent {
  const StockTransferListLoadRequested();
}

class StockTransferListRefreshRequested extends StockTransferEvent {
  const StockTransferListRefreshRequested({this.forceRemote = true});

  final bool forceRemote;

  @override
  List<Object?> get props => [forceRemote];
}

class StockTransferDetailLoadRequested extends StockTransferEvent {
  const StockTransferDetailLoadRequested(this.transferId);

  final int transferId;

  @override
  List<Object?> get props => [transferId];
}

class StockTransferDestinationsLoadRequested extends StockTransferEvent {
  const StockTransferDestinationsLoadRequested();
}

class StockTransferCreateSubmitted extends StockTransferEvent {
  const StockTransferCreateSubmitted({
    required this.destinationShopId,
    required this.reference,
    this.notes,
    required this.items,
  });

  final int destinationShopId;
  final String reference;
  final String? notes;
  final List<Map<String, dynamic>> items;

  @override
  List<Object?> get props => [destinationShopId, reference, notes, items];
}

class StockTransferReturnCreateRequested extends StockTransferEvent {
  const StockTransferReturnCreateRequested({
    required this.parentTransferId,
    this.quantitiesByParentItemId,
  });

  final int parentTransferId;
  final Map<int, int>? quantitiesByParentItemId;

  @override
  List<Object?> get props => [parentTransferId, quantitiesByParentItemId];
}

class StockTransferShipRequested extends StockTransferEvent {
  const StockTransferShipRequested({
    required this.transferId,
    required this.shipmentLabel,
    this.shipmentNotes,
    this.driverName,
    this.vehiclePlate,
    this.quantitiesByItemId,
  });

  final int transferId;
  final String shipmentLabel;
  final String? shipmentNotes;
  final String? driverName;
  final String? vehiclePlate;
  final Map<int, int>? quantitiesByItemId;

  @override
  List<Object?> get props => [
        transferId,
        shipmentLabel,
        shipmentNotes,
        driverName,
        vehiclePlate,
        quantitiesByItemId,
      ];
}

class StockTransferValidateRequested extends StockTransferEvent {
  const StockTransferValidateRequested(this.transferId);

  final int transferId;

  @override
  List<Object?> get props => [transferId];
}

class StockTransferReportLoadRequested extends StockTransferEvent {
  const StockTransferReportLoadRequested();
}

class StockTransferSubmitForApprovalRequested extends StockTransferEvent {
  const StockTransferSubmitForApprovalRequested(this.transferId);

  final int transferId;

  @override
  List<Object?> get props => [transferId];
}

class StockTransferApproveRequested extends StockTransferEvent {
  const StockTransferApproveRequested(this.transferId);

  final int transferId;

  @override
  List<Object?> get props => [transferId];
}

class StockTransferReceiveSubmitted extends StockTransferEvent {
  const StockTransferReceiveSubmitted({
    required this.transferId,
    this.quantitiesByItemId,
    this.refusalsByItemId,
    this.salePriceByItemId,
    this.shipmentId,
  });

  final int transferId;
  final Map<int, int>? quantitiesByItemId;
  final Map<int, StockTransferReceiveRefusal>? refusalsByItemId;
  final Map<int, int>? salePriceByItemId;
  final int? shipmentId;

  @override
  List<Object?> get props => [
        transferId,
        quantitiesByItemId,
        refusalsByItemId,
        salePriceByItemId,
        shipmentId,
      ];
}

class StockTransferCancelRequested extends StockTransferEvent {
  const StockTransferCancelRequested(this.transferId);

  final int transferId;

  @override
  List<Object?> get props => [transferId];
}

class StockTransferCloseRequested extends StockTransferEvent {
  const StockTransferCloseRequested({
    required this.transferId,
    this.notes,
  });

  final int transferId;
  final String? notes;

  @override
  List<Object?> get props => [transferId, notes];
}

class StockTransferResolveDiscrepancySubmitted extends StockTransferEvent {
  const StockTransferResolveDiscrepancySubmitted({
    required this.transferId,
    required this.itemId,
    required this.quantity,
    required this.reason,
    required this.resolution,
    this.notes,
  });

  final int transferId;
  final int itemId;
  final int quantity;
  final String reason;
  final String resolution;
  final String? notes;

  @override
  List<Object?> get props =>
      [transferId, itemId, quantity, reason, resolution, notes];
}
