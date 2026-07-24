import 'package:equatable/equatable.dart';

enum SalesOrderStatus {
  draft,
  confirmed,
  preparing,
  partiallyDelivered,
  delivered,
  cancelled,
  closed;

  String get code => switch (this) {
        SalesOrderStatus.draft => 'draft',
        SalesOrderStatus.confirmed => 'confirmed',
        SalesOrderStatus.preparing => 'preparing',
        SalesOrderStatus.partiallyDelivered => 'partially_delivered',
        SalesOrderStatus.delivered => 'delivered',
        SalesOrderStatus.cancelled => 'cancelled',
        SalesOrderStatus.closed => 'closed',
      };

  String get labelFr => switch (this) {
        SalesOrderStatus.draft => 'Brouillon',
        SalesOrderStatus.confirmed => 'Confirmée',
        SalesOrderStatus.preparing => 'Préparation',
        SalesOrderStatus.partiallyDelivered => 'Partiellement livrée',
        SalesOrderStatus.delivered => 'Livrée',
        SalesOrderStatus.cancelled => 'Annulée',
        SalesOrderStatus.closed => 'Clôturée',
      };

  static SalesOrderStatus fromCode(String code) {
    return SalesOrderStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => SalesOrderStatus.draft,
    );
  }
}

/// Actions d’historique (journal métier léger — pas un event store).
enum SalesOrderHistoryAction {
  created,
  updated,
  confirmed,
  preparing,
  delivered,
  cancelled,
  closed,
  replacement;

  String get code => name;

  String get labelFr => switch (this) {
        SalesOrderHistoryAction.created => 'Création',
        SalesOrderHistoryAction.updated => 'Modification',
        SalesOrderHistoryAction.confirmed => 'Confirmation',
        SalesOrderHistoryAction.preparing => 'Préparation',
        SalesOrderHistoryAction.delivered => 'Livraison',
        SalesOrderHistoryAction.cancelled => 'Annulation',
        SalesOrderHistoryAction.closed => 'Clôture',
        SalesOrderHistoryAction.replacement => 'Remplacement',
      };

  static SalesOrderHistoryAction? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final normalized = code.toLowerCase();
    for (final a in SalesOrderHistoryAction.values) {
      if (a.code == normalized) return a;
    }
    if (normalized == 'create') return SalesOrderHistoryAction.created;
    if (normalized == 'update') return SalesOrderHistoryAction.updated;
    if (normalized == 'confirm') return SalesOrderHistoryAction.confirmed;
    return null;
  }
}

enum SalesOrderRefusalReason {
  breakage,
  humidity,
  quality,
  wrongOrder,
  clientAbsent,
  clientRefused,
  expired,
  other;

  String get code => switch (this) {
        SalesOrderRefusalReason.breakage => 'breakage',
        SalesOrderRefusalReason.humidity => 'humidity',
        SalesOrderRefusalReason.quality => 'quality',
        SalesOrderRefusalReason.wrongOrder => 'wrong_order',
        SalesOrderRefusalReason.clientAbsent => 'client_absent',
        SalesOrderRefusalReason.clientRefused => 'client_refused',
        SalesOrderRefusalReason.expired => 'expired',
        SalesOrderRefusalReason.other => 'other',
      };

  String get labelFr => switch (this) {
        SalesOrderRefusalReason.breakage => 'Produit cassé / déchiré',
        SalesOrderRefusalReason.humidity => 'Produit humide',
        SalesOrderRefusalReason.quality => 'Qualité',
        SalesOrderRefusalReason.wrongOrder => 'Erreur de commande',
        SalesOrderRefusalReason.clientAbsent => 'Client absent',
        SalesOrderRefusalReason.clientRefused => 'Client refuse',
        SalesOrderRefusalReason.expired => 'Produit périmé',
        SalesOrderRefusalReason.other => 'Autre',
      };

  static SalesOrderRefusalReason? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final r in SalesOrderRefusalReason.values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// Destination physique du refus à la livraison.
enum SalesOrderRefusalDestination {
  returnToStock,
  loss;

  String get code => switch (this) {
        SalesOrderRefusalDestination.returnToStock => 'return_to_stock',
        SalesOrderRefusalDestination.loss => 'loss',
      };

  String get labelFr => switch (this) {
        SalesOrderRefusalDestination.returnToStock => 'Retour stock',
        SalesOrderRefusalDestination.loss => 'Perte',
      };

  static SalesOrderRefusalDestination? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final d in SalesOrderRefusalDestination.values) {
      if (d.code == code) return d;
    }
    return null;
  }
}

/// Pourquoi un reliquat reste après une livraison partielle.
enum SalesOrderRemainingReason {
  truckFull,
  postponed,
  stockShort,
  clientRequest,
  other;

  String get code => switch (this) {
        SalesOrderRemainingReason.truckFull => 'truck_full',
        SalesOrderRemainingReason.postponed => 'postponed',
        SalesOrderRemainingReason.stockShort => 'stock_short',
        SalesOrderRemainingReason.clientRequest => 'client_request',
        SalesOrderRemainingReason.other => 'other',
      };

  String get labelFr => switch (this) {
        SalesOrderRemainingReason.truckFull => 'Camion plein',
        SalesOrderRemainingReason.postponed => 'Livraison reportée',
        SalesOrderRemainingReason.stockShort => 'Stock insuffisant',
        SalesOrderRemainingReason.clientRequest => 'Demande client',
        SalesOrderRemainingReason.other => 'Autre',
      };

  static SalesOrderRemainingReason? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final r in SalesOrderRemainingReason.values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

class SalesOrderItem extends Equatable {
  const SalesOrderItem({
    required this.id,
    required this.salesOrderId,
    required this.productId,
    required this.productName,
    required this.quantityOrdered,
    required this.quantityDelivered,
    required this.quantityRefused,
    required this.quantityReplaced,
    required this.unitPrice,
    required this.lineTotal,
    this.quantityInStock,
    this.serverId,
  });

  final int id;
  final int salesOrderId;
  final int productId;
  final String productName;
  final int quantityOrdered;
  final int quantityDelivered;
  final int quantityRefused;
  final int quantityReplaced;
  final int unitPrice;
  final int lineTotal;
  final int? quantityInStock;
  final String? serverId;

  /// Reste à livrer (hors déjà livré / refusé / remplacé).
  int get quantityRemaining =>
      (quantityOrdered -
              quantityDelivered -
              quantityRefused -
              quantityReplaced)
          .clamp(0, quantityOrdered);

  @override
  List<Object?> get props => [
        id,
        salesOrderId,
        productId,
        quantityOrdered,
        quantityDelivered,
        quantityRefused,
        quantityReplaced,
        unitPrice,
        serverId,
      ];
}

class SalesOrderDeliveryItem extends Equatable {
  const SalesOrderDeliveryItem({
    required this.id,
    required this.deliveryId,
    required this.salesOrderItemId,
    required this.productId,
    required this.productName,
    required this.quantitySent,
    required this.quantityAccepted,
    required this.quantityRefused,
    required this.quantityReplaced,
    required this.unitPrice,
    this.refusalReason,
    this.refusalDestination,
    this.replacementProductId,
    this.replacementProductName,
    this.replacementUnitPrice,
  });

  final int id;
  final int deliveryId;
  final int salesOrderItemId;
  final int productId;
  final String productName;
  final int quantitySent;
  final int quantityAccepted;
  final int quantityRefused;
  final int quantityReplaced;
  final int unitPrice;
  final SalesOrderRefusalReason? refusalReason;
  final SalesOrderRefusalDestination? refusalDestination;
  final int? replacementProductId;
  final String? replacementProductName;
  final int? replacementUnitPrice;

  @override
  List<Object?> get props => [
        id,
        deliveryId,
        salesOrderItemId,
        quantitySent,
        quantityAccepted,
        quantityRefused,
        quantityReplaced,
        refusalDestination,
        replacementProductId,
      ];
}

class SalesOrderDelivery extends Equatable {
  const SalesOrderDelivery({
    required this.id,
    required this.salesOrderId,
    required this.number,
    required this.status,
    required this.deliveredAt,
    required this.deliveredBy,
    required this.items,
    this.saleId,
    this.notes,
    this.driverName,
    this.vehiclePlate,
    this.remainingReason,
  });

  final int id;
  final int salesOrderId;
  final String number;
  final String status;
  final int deliveredAt;
  final int deliveredBy;
  final int? saleId;
  final String? notes;
  final String? driverName;
  final String? vehiclePlate;
  final SalesOrderRemainingReason? remainingReason;
  final List<SalesOrderDeliveryItem> items;

  @override
  List<Object?> get props => [
        id,
        salesOrderId,
        number,
        saleId,
        notes,
        driverName,
        vehiclePlate,
        remainingReason,
        items,
      ];
}

class SalesOrderHistoryEntry extends Equatable {
  const SalesOrderHistoryEntry({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.performedAt,
    this.details,
    this.payload,
  });

  final int id;
  final String action;
  final int performedBy;
  final int performedAt;
  final String? details;
  final Map<String, dynamic>? payload;

  SalesOrderHistoryAction? get actionEnum =>
      SalesOrderHistoryAction.fromCode(action);

  @override
  List<Object?> get props => [id, action, performedAt, payload];
}

class SalesOrder extends Equatable {
  const SalesOrder({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.customerName,
    required this.number,
    required this.status,
    required this.orderedAt,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.notes,
    this.deliveries = const [],
    this.history = const [],
    this.serverId,
    this.version = 1,
    this.updatedBy,
    this.deviceId,
  });

  final int id;
  final int shopId;
  final int customerId;
  final String customerName;
  final String number;
  final SalesOrderStatus status;
  final int orderedAt;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  final String? notes;
  final int createdBy;
  final int createdAt;
  final int updatedAt;
  final int version;
  final int? updatedBy;
  final String? deviceId;
  final String? serverId;
  final List<SalesOrderItem> items;
  final List<SalesOrderDelivery> deliveries;
  final List<SalesOrderHistoryEntry> history;

  int get totalOrdered =>
      items.fold(0, (s, i) => s + i.quantityOrdered);

  int get totalDelivered =>
      items.fold(0, (s, i) => s + i.quantityDelivered);

  int get totalRefused =>
      items.fold(0, (s, i) => s + i.quantityRefused);

  int get totalReplaced =>
      items.fold(0, (s, i) => s + i.quantityReplaced);

  int get totalRemaining =>
      items.fold(0, (s, i) => s + i.quantityRemaining);

  bool get canConfirm => status == SalesOrderStatus.draft;

  bool get canPrepare =>
      status == SalesOrderStatus.confirmed ||
      status == SalesOrderStatus.preparing;

  bool get canDeliver =>
      status == SalesOrderStatus.confirmed ||
      status == SalesOrderStatus.preparing ||
      status == SalesOrderStatus.partiallyDelivered;

  bool get canCancel =>
      (status == SalesOrderStatus.draft ||
          status == SalesOrderStatus.confirmed ||
          status == SalesOrderStatus.preparing) &&
      totalDelivered == 0 &&
      totalRefused == 0 &&
      totalReplaced == 0;

  bool get canClose => status == SalesOrderStatus.delivered;

  /// Calcule le statut après mise à jour des quantités livrées/refusées.
  static SalesOrderStatus statusAfterFulfillment({
    required List<SalesOrderItem> items,
    required SalesOrderStatus current,
  }) {
    if (current == SalesOrderStatus.cancelled ||
        current == SalesOrderStatus.closed) {
      return current;
    }
    final remaining =
        items.fold(0, (s, i) => s + i.quantityRemaining);
    final delivered =
        items.fold(0, (s, i) => s + i.quantityDelivered);
    if (delivered <= 0 && remaining > 0) {
      return current == SalesOrderStatus.confirmed
          ? SalesOrderStatus.preparing
          : current;
    }
    if (remaining <= 0) return SalesOrderStatus.delivered;
    return SalesOrderStatus.partiallyDelivered;
  }

  @override
  List<Object?> get props => [
        id,
        number,
        status,
        customerId,
        total,
        items,
        deliveries,
      ];
}

class SalesOrderLineInput {
  const SalesOrderLineInput({
    required this.productId,
    required this.quantityOrdered,
    required this.unitPrice,
  });

  final int productId;
  final int quantityOrdered;
  final int unitPrice;

  int get lineTotal => quantityOrdered * unitPrice;
}

class DeliveryLineInput {
  const DeliveryLineInput({
    required this.salesOrderItemId,
    required this.quantitySent,
    required this.quantityAccepted,
    this.quantityRefused = 0,
    this.quantityReplaced = 0,
    this.refusalReason,
    this.refusalDestination,
    this.replacementProductId,
    this.replacementUnitPrice,
  });

  final int salesOrderItemId;
  final int quantitySent;
  final int quantityAccepted;
  final int quantityRefused;
  final int quantityReplaced;
  final SalesOrderRefusalReason? refusalReason;
  final SalesOrderRefusalDestination? refusalDestination;
  final int? replacementProductId;
  final int? replacementUnitPrice;
}

/// Perte inventaire créée pendant une livraison (pour sync).
class SalesOrderStockLoss {
  const SalesOrderStockLoss({
    required this.productId,
    required this.quantity,
    required this.reason,
  });

  final int productId;
  final int quantity;
  final String reason;
}

class SalesOrderDeliverResult {
  const SalesOrderDeliverResult({
    required this.delivery,
    this.stockLosses = const [],
  });

  final SalesOrderDelivery delivery;
  final List<SalesOrderStockLoss> stockLosses;
}

/// Une ligne d’agrégation pour les rapports commandes clients.
class SalesOrderReportBucket {
  const SalesOrderReportBucket({
    required this.code,
    required this.labelFr,
    required this.value,
  });

  final String code;
  final String labelFr;
  final int value;

  double shareOf(int total) =>
      total <= 0 ? 0 : value / total;
}

class SalesOrderFulfillmentReport {
  const SalesOrderFulfillmentReport({
    required this.fromMs,
    required this.toMs,
    required this.byRefusalReason,
    required this.byDestination,
    required this.byRemainingReason,
  });

  final int fromMs;
  final int toMs;
  final List<SalesOrderReportBucket> byRefusalReason;
  final List<SalesOrderReportBucket> byDestination;
  final List<SalesOrderReportBucket> byRemainingReason;

  int get totalRefusedQty =>
      byRefusalReason.fold(0, (s, b) => s + b.value);

  int get totalDestinationQty =>
      byDestination.fold(0, (s, b) => s + b.value);

  int get totalPartialDeliveries =>
      byRemainingReason.fold(0, (s, b) => s + b.value);
}
