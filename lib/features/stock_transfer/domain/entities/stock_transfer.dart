import 'package:equatable/equatable.dart';

abstract final class StockTransferType {
  static const outbound = 'outbound';
  static const returnTransfer = 'return';

  static String label(String type) => switch (type) {
        outbound => 'Transfert',
        returnTransfer => 'Retour',
        _ => type,
      };

  static bool isReturn(String type) => type == returnTransfer;
}

abstract final class StockTransferStatus {
  static const draft = 'draft';
  static const pendingApproval = 'pending_approval';
  static const validated = 'validated';
  static const partiallyShipped = 'partially_shipped';
  static const shipped = 'shipped';
  static const partiallyReceived = 'partially_received';
  static const received = 'received';
  static const closed = 'closed';
  static const closedWithException = 'closed_with_exception';
  static const cancelled = 'cancelled';

  static String label(String status) => switch (status) {
        draft => 'Brouillon',
        pendingApproval => 'En attente d\'approbation',
        validated => 'Validé',
        partiallyShipped => 'Partiellement expédié',
        shipped => 'Expédié',
        partiallyReceived => 'Partiellement reçu',
        received => 'Reçu',
        closed => 'Clôturé',
        closedWithException => 'Clôturé avec écart',
        cancelled => 'Annulé',
        _ => status,
      };

  static bool canValidate(String status) => status == draft;

  static bool canSubmitForApproval(String status) => status == draft;

  static bool canApprove(String status) => status == pendingApproval;

  static bool canShip(String status) =>
      status == validated || status == partiallyShipped;

  static bool canReceive(String status) =>
      status == shipped ||
      status == partiallyShipped ||
      status == partiallyReceived;

  static bool canCancel(String status) =>
      status == draft ||
      status == pendingApproval ||
      status == validated;

  static bool canCancelWithRestock(String status) => false;

  static bool canClose(String status) =>
      status == partiallyShipped ||
      status == shipped ||
      status == partiallyReceived ||
      status == received;

  static bool isTerminal(String status) =>
      status == closed ||
      status == closedWithException ||
      status == cancelled;

  static bool canResolveDiscrepancy(String status) =>
      status == partiallyShipped ||
      status == shipped ||
      status == partiallyReceived ||
      status == received;

  /// Transferts visibles dans l'onglet « Entrants » (boutique destination).
  static const incomingTabStatuses = [
    validated,
    partiallyShipped,
    shipped,
    partiallyReceived,
    received,
  ];

  /// Entrants expédiés, réception incomplète (vue boutique destination).
  static const inTransitTabStatuses = [
    partiallyShipped,
    shipped,
    partiallyReceived,
  ];

  static bool isInTransit(String status) =>
      inTransitTabStatuses.contains(status);
  static bool canCreateReturn(String status, String transferType) =>
      transferType == StockTransferType.outbound &&
      (status == received ||
          status == partiallyReceived ||
          status == closed ||
          status == closedWithException);

  /// Ordre de progression métier (ne jamais rétrograder local ← cloud).
  static int progressionRank(String status) => switch (status) {
        draft => 0,
        pendingApproval => 5,
        validated => 10,
        partiallyShipped => 20,
        shipped => 30,
        partiallyReceived => 40,
        received => 50,
        closedWithException => 60,
        closed => 65,
        cancelled => 100,
        _ => 0,
      };

  /// Fusionne le statut local et cloud sans régression.
  static String mergeStatus(String localStatus, String remoteStatus) {
    if (localStatus == cancelled || remoteStatus == cancelled) {
      return cancelled;
    }
    if (localStatus == closed || remoteStatus == closed) {
      return closed;
    }
    if (localStatus == closedWithException ||
        remoteStatus == closedWithException) {
      return closedWithException;
    }
    return progressionRank(localStatus) >= progressionRank(remoteStatus)
        ? localStatus
        : remoteStatus;
  }

  static int? mergeTimestamp(int? localValue, int? remoteValue) {
    if (localValue == null) return remoteValue;
    if (remoteValue == null) return localValue;
    return localValue > remoteValue ? localValue : remoteValue;
  }

  static int mergeQuantity(int localValue, int remoteValue) =>
      localValue > remoteValue ? localValue : remoteValue;
}

abstract final class StockTransferRefusalReason {
  static const loss = 'loss';
  static const breakage = 'breakage';
  static const theft = 'theft';
  static const other = 'other';

  static String label(String reason) => switch (reason) {
        loss => 'Perte',
        breakage => 'Casse',
        theft => 'Vol',
        other => 'Autre',
        _ => reason,
      };

  static const values = [loss, breakage, theft, other];
}

abstract final class StockTransferRefusalResolution {
  static const returnToSource = 'return';
  static const replacement = 'replacement';

  static String label(String resolution) => switch (resolution) {
        returnToSource => 'Retour boutique source',
        replacement => 'Remplacement',
        _ => resolution,
      };

  static const values = [returnToSource, replacement];
}

class StockTransferReceiveRefusal extends Equatable {
  const StockTransferReceiveRefusal({
    required this.quantity,
    required this.reason,
    required this.resolution,
  });

  final int quantity;
  final String reason;
  final String resolution;

  @override
  List<Object?> get props => [quantity, reason, resolution];
}

abstract final class StockTransferDiscrepancyReason {
  static const loss = 'loss';
  static const breakage = 'breakage';
  static const theft = 'theft';
  static const other = 'other';

  static String label(String reason) => switch (reason) {
        loss => 'Perte',
        breakage => 'Casse',
        theft => 'Vol',
        other => 'Autre',
        _ => reason,
      };
}

abstract final class StockTransferDiscrepancyResolution {
  static const writeOff = 'write_off';
  static const restockSource = 'restock_source';

  static String label(String resolution) => switch (resolution) {
        writeOff => 'Perte acceptée',
        restockSource => 'Restock boutique source',
        _ => resolution,
      };
}

abstract final class StockTransferEventType {
  static const created = 'created';
  static const submittedForApproval = 'submitted_for_approval';
  static const validated = 'validated';
  static const shipped = 'shipped';
  static const received = 'received';
  static const refused = 'refused';
  static const cancelled = 'cancelled';
  static const discrepancyResolved = 'discrepancy_resolved';
  static const closed = 'closed';
  static const closedWithException = 'closed_with_exception';

  static String label(String type) => switch (type) {
        created => 'Création',
        submittedForApproval => 'Soumission approbation',
        validated => 'Validation',
        shipped => 'Expédition',
        received => 'Réception',
        refused => 'Refus réception',
        cancelled => 'Annulation',
        discrepancyResolved => 'Écart résolu',
        closed => 'Clôture',
        closedWithException => 'Clôture avec écart',
        _ => type,
      };
}

class StockTransferEvent extends Equatable {
  const StockTransferEvent({
    required this.id,
    required this.transferId,
    required this.shopId,
    required this.eventType,
    required this.actorUserId,
    this.notes,
    this.payloadJson,
    required this.createdAt,
  });

  final int id;
  final int transferId;
  final int shopId;
  final String eventType;
  final int actorUserId;
  final String? notes;
  final String? payloadJson;
  final int createdAt;

  @override
  List<Object?> get props =>
      [id, transferId, shopId, eventType, actorUserId, notes, payloadJson, createdAt];
}

class StockTransferDiscrepancy extends Equatable {
  const StockTransferDiscrepancy({
    required this.id,
    required this.transferId,
    required this.transferItemId,
    required this.quantity,
    required this.reason,
    required this.resolution,
    this.notes,
    required this.resolvedBy,
    required this.resolvedAt,
    required this.createdAt,
  });

  final int id;
  final int transferId;
  final int transferItemId;
  final int quantity;
  final String reason;
  final String resolution;
  final String? notes;
  final int resolvedBy;
  final int resolvedAt;
  final int createdAt;

  @override
  List<Object?> get props => [
        id,
        transferId,
        transferItemId,
        quantity,
        reason,
        resolution,
        notes,
        resolvedBy,
        resolvedAt,
        createdAt,
      ];
}

class StockTransferReceiptItem extends Equatable {
  const StockTransferReceiptItem({
    required this.id,
    required this.receiptId,
    required this.transferItemId,
    required this.quantityReceived,
    this.quantityRefused = 0,
    this.refusalReason,
    this.refusalResolution,
  });

  final int id;
  final int receiptId;
  final int transferItemId;
  final int quantityReceived;
  final int quantityRefused;
  final String? refusalReason;
  final String? refusalResolution;

  @override
  List<Object?> get props => [
        id,
        receiptId,
        transferItemId,
        quantityReceived,
        quantityRefused,
        refusalReason,
        refusalResolution,
      ];
}

class StockTransferReceipt extends Equatable {
  const StockTransferReceipt({
    required this.id,
    required this.transferId,
    this.shipmentId,
    required this.reference,
    this.notes,
    required this.receivedBy,
    required this.receivedAt,
    this.items,
  });

  final int id;
  final int transferId;
  final int? shipmentId;
  final String reference;
  final String? notes;
  final int receivedBy;
  final int receivedAt;
  final List<StockTransferReceiptItem>? items;

  int get totalQuantityReceived =>
      (items ?? []).fold<int>(0, (sum, item) => sum + item.quantityReceived);

  @override
  List<Object?> get props =>
      [id, transferId, shipmentId, reference, notes, receivedBy, receivedAt, items];
}

class StockTransferQrReceiveIntent extends Equatable {
  const StockTransferQrReceiveIntent({
    required this.transferId,
    required this.reference,
    required this.shipmentLabel,
    required this.quantitiesByItemId,
    this.shipmentId,
  });

  final int transferId;
  final int? shipmentId;
  final String reference;
  final String shipmentLabel;
  final Map<int, int> quantitiesByItemId;

  @override
  List<Object?> get props =>
      [transferId, shipmentId, reference, shipmentLabel, quantitiesByItemId];
}

/// Produit absent du catalogue destination, à créer avant réception.
class TransferMissingDestinationProduct extends Equatable {
  const TransferMissingDestinationProduct({
    required this.itemId,
    required this.productName,
    this.productServerId,
    this.suggestedPriceBuy,
    this.suggestedPriceSell,
  });

  final int itemId;
  final String productName;
  final String? productServerId;
  final int? suggestedPriceBuy;
  final int? suggestedPriceSell;

  @override
  List<Object?> get props =>
      [itemId, productName, productServerId, suggestedPriceBuy, suggestedPriceSell];
}

class StockTransfer extends Equatable {
  const StockTransfer({
    required this.id,
    required this.reference,
    required this.sourceShopId,
    required this.destinationShopId,
    this.sourceShopName,
    this.destinationShopName,
    required this.status,
    this.transferType = StockTransferType.outbound,
    this.parentTransferId,
    this.parentReference,
    this.notes,
    required this.createdBy,
    this.validatedBy,
    this.shippedBy,
    this.receivedBy,
    this.closedBy,
    required this.createdAt,
    required this.updatedAt,
    this.validatedAt,
    this.shippedAt,
    this.receivedAt,
    this.closedAt,
    this.items,
    this.shipments,
    this.receipts,
    this.events,
    this.discrepancies,
    this.serverId,
    this.syncStatus,
    this.pendingSyncOperations = const [],
    this.cloudSyncEnabled = false,
  });

  final int id;
  final String reference;
  final int sourceShopId;
  final int destinationShopId;
  final String? sourceShopName;
  final String? destinationShopName;
  final String status;
  final String transferType;
  final int? parentTransferId;
  final String? parentReference;
  final String? notes;
  final int createdBy;
  final int? validatedBy;
  final int? shippedBy;
  final int? receivedBy;
  final int? closedBy;
  final int createdAt;
  final int updatedAt;
  final int? validatedAt;
  final int? shippedAt;
  final int? receivedAt;
  final int? closedAt;
  final List<StockTransferItem>? items;
  final List<StockTransferShipment>? shipments;
  final List<StockTransferReceipt>? receipts;
  final List<StockTransferEvent>? events;
  final List<StockTransferDiscrepancy>? discrepancies;
  final String? serverId;
  final String? syncStatus;
  final List<String> pendingSyncOperations;
  final bool cloudSyncEnabled;

  bool get isReturn => StockTransferType.isReturn(transferType);

  bool get isCreateSynced => serverId != null && serverId!.isNotEmpty;

  String get sourceShopLabel =>
      _shopLabel(sourceShopName, sourceShopId);

  String get destinationShopLabel =>
      _shopLabel(destinationShopName, destinationShopId);

  static String _shopLabel(String? name, int shopId) {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return 'Boutique #$shopId';
  }

  bool get hasPendingCreate => pendingSyncOperations.contains('create');

  bool get hasPendingValidate => pendingSyncOperations.contains('validate');

  bool get hasPendingSubmit => pendingSyncOperations.contains('submit');

  bool get hasPendingApprove => pendingSyncOperations.contains('approve');

  bool get hasPendingShip => pendingSyncOperations.contains('send');

  bool get hasPendingReceive => pendingSyncOperations.contains('receive');

  bool get hasDiscrepancy {
    if (status == StockTransferStatus.closedWithException) return true;
    if (status != StockTransferStatus.received &&
        status != StockTransferStatus.partiallyReceived) {
      return false;
    }
    return openDiscrepancyQuantity > 0;
  }

  int get openDiscrepancyQuantity {
    return (items ?? []).fold<int>(
      0,
      (sum, item) => sum + item.openDiscrepancyQuantity(discrepancies ?? []),
    );
  }

  bool get hasOpenDiscrepancy => openDiscrepancyQuantity > 0;

  /// Unités expédiées mais pas encore reçues (étape normale après expédition).
  int get pendingReceptionQuantity =>
      totalQuantityShipped - totalQuantityReceived;

  bool get isAwaitingReception =>
      pendingReceptionQuantity > 0 &&
      (status == StockTransferStatus.shipped ||
          status == StockTransferStatus.partiallyShipped ||
          status == StockTransferStatus.partiallyReceived);

  int get totalQuantityShipped =>
      (items ?? []).fold(0, (s, i) => s + i.quantityShipped);

  int get totalQuantityReceived =>
      (items ?? []).fold(0, (s, i) => s + i.quantityReceived);

  StockTransfer copyWith({
    String? status,
    List<StockTransferItem>? items,
    List<StockTransferShipment>? shipments,
    List<StockTransferReceipt>? receipts,
    List<StockTransferEvent>? events,
    List<StockTransferDiscrepancy>? discrepancies,
    String? serverId,
    String? syncStatus,
    List<String>? pendingSyncOperations,
    bool? cloudSyncEnabled,
  }) {
    return StockTransfer(
      id: id,
      reference: reference,
      sourceShopId: sourceShopId,
      destinationShopId: destinationShopId,
      sourceShopName: sourceShopName,
      destinationShopName: destinationShopName,
      status: status ?? this.status,
      transferType: transferType,
      parentTransferId: parentTransferId,
      parentReference: parentReference,
      notes: notes,
      createdBy: createdBy,
      validatedBy: validatedBy,
      shippedBy: shippedBy,
      receivedBy: receivedBy,
      closedBy: closedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      validatedAt: validatedAt,
      shippedAt: shippedAt,
      receivedAt: receivedAt,
      closedAt: closedAt,
      items: items ?? this.items,
      shipments: shipments ?? this.shipments,
      receipts: receipts ?? this.receipts,
      events: events ?? this.events,
      discrepancies: discrepancies ?? this.discrepancies,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingSyncOperations: pendingSyncOperations ?? this.pendingSyncOperations,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
    );
  }

  @override
  List<Object?> get props => [
        id,
        reference,
        sourceShopId,
        destinationShopId,
        sourceShopName,
        destinationShopName,
        status,
        transferType,
        parentTransferId,
        parentReference,
        notes,
        createdBy,
        validatedBy,
        shippedBy,
        receivedBy,
        createdAt,
        updatedAt,
        validatedAt,
        shippedAt,
        receivedAt,
        items,
        shipments,
        serverId,
        syncStatus,
        pendingSyncOperations,
        cloudSyncEnabled,
      ];
}

class StockTransferShipment extends Equatable {
  const StockTransferShipment({
    required this.id,
    required this.transferId,
    required this.reference,
    required this.label,
    this.notes,
    this.driverName,
    this.vehiclePlate,
    required this.shippedBy,
    required this.shippedAt,
  });

  final int id;
  final int transferId;
  final String reference;
  final String label;
  final String? notes;
  final String? driverName;
  final String? vehiclePlate;
  final int shippedBy;
  final int shippedAt;

  int pendingReceiveQuantity(StockTransfer transfer) {
    return (transfer.items ?? []).fold<int>(
      0,
      (sum, item) => sum + item.quantityPendingReceiveInShipment(id),
    );
  }

  List<StockTransferReceipt> receiptsFor(StockTransfer transfer) {
    return (transfer.receipts ?? [])
        .where((receipt) => receipt.shipmentId == id)
        .toList();
  }

  @override
  List<Object?> get props => [
        id,
        transferId,
        reference,
        label,
        notes,
        driverName,
        vehiclePlate,
        shippedBy,
        shippedAt,
      ];
}

class StockTransferItem extends Equatable {
  const StockTransferItem({
    required this.id,
    required this.transferId,
    required this.sourceProductId,
    this.destinationProductId,
    this.productServerId,
    this.productName,
    required this.quantityRequested,
    required this.quantityShipped,
    required this.quantityReceived,
    this.lotLines,
  });

  final int id;
  final int transferId;
  final int sourceProductId;
  final int? destinationProductId;
  final String? productServerId;
  final String? productName;
  final int quantityRequested;
  final int quantityShipped;
  final int quantityReceived;
  final List<StockTransferLotLine>? lotLines;

  int get quantityPendingShip => quantityRequested - quantityShipped;

  int get quantityPendingReceive => quantityShipped - quantityReceived;

  int get quantityDiscrepancy => quantityShipped - quantityReceived;

  bool get hasDiscrepancy => quantityDiscrepancy > 0;

  int quantityInShipment(int shipmentId) =>
      (lotLines ?? [])
          .where((l) => l.shipmentId == shipmentId)
          .fold<int>(0, (sum, l) => sum + l.quantity);

  int quantityPendingReceiveInShipment(int shipmentId) =>
      (lotLines ?? [])
          .where((l) => l.shipmentId == shipmentId)
          .fold<int>(0, (sum, l) => sum + l.quantityPendingReceive);

  int openDiscrepancyQuantity(List<StockTransferDiscrepancy> resolutions) {
    final gap = quantityShipped - quantityReceived;
    if (gap <= 0) return 0;
    final resolved = resolutions
        .where((row) => row.transferItemId == id)
        .fold<int>(0, (sum, row) => sum + row.quantity);
    return (gap - resolved).clamp(0, gap);
  }

  @override
  List<Object?> get props => [
        id,
        transferId,
        sourceProductId,
        destinationProductId,
        productServerId,
        productName,
        quantityRequested,
        quantityShipped,
        quantityReceived,
        lotLines,
      ];
}

class StockTransferLotLine extends Equatable {
  const StockTransferLotLine({
    required this.id,
    required this.transferItemId,
    this.shipmentId,
    this.sourceLotId,
    this.destinationLotId,
    required this.quantity,
    required this.quantityReceived,
    required this.unitCost,
  });

  final int id;
  final int transferItemId;
  final int? shipmentId;
  final int? sourceLotId;
  final int? destinationLotId;
  final int quantity;
  final int quantityReceived;
  final int unitCost;

  int get quantityPendingReceive => quantity - quantityReceived;

  @override
  List<Object?> get props => [
        id,
        transferItemId,
        shipmentId,
        sourceLotId,
        destinationLotId,
        quantity,
        quantityReceived,
        unitCost,
      ];
}

class ShopOption extends Equatable {
  const ShopOption({
    required this.id,
    required this.name,
    this.serverId,
    this.address,
  });

  final int id;
  final String name;
  final String? serverId;
  final String? address;

  String get displayLabel {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'Boutique #$id';
  }

  @override
  List<Object?> get props => [id, name, serverId, address];
}

class StockTransferReportSummary extends Equatable {
  const StockTransferReportSummary({
    required this.totalTransfers,
    required this.inTransitCount,
    required this.discrepancyCount,
    required this.totalUnitsShipped,
    required this.totalUnitsReceived,
    required this.discrepancies,
  });

  final int totalTransfers;
  final int inTransitCount;
  final int discrepancyCount;
  final int totalUnitsShipped;
  final int totalUnitsReceived;
  final List<StockTransferDiscrepancyRow> discrepancies;

  int get totalDiscrepancyUnits => totalUnitsShipped - totalUnitsReceived;

  @override
  List<Object?> get props => [
        totalTransfers,
        inTransitCount,
        discrepancyCount,
        totalUnitsShipped,
        totalUnitsReceived,
        discrepancies,
      ];
}

class StockTransferDiscrepancyRow extends Equatable {
  const StockTransferDiscrepancyRow({
    required this.transferId,
    required this.reference,
    required this.productName,
    required this.quantityShipped,
    required this.quantityReceived,
    required this.status,
  });

  final int transferId;
  final String reference;
  final String productName;
  final int quantityShipped;
  final int quantityReceived;
  final String status;

  int get gap => quantityShipped - quantityReceived;

  @override
  List<Object?> get props => [
        transferId,
        reference,
        productName,
        quantityShipped,
        quantityReceived,
        status,
      ];
}
