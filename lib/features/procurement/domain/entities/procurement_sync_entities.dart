/// État cloud d'un document approvisionnement (affichage UX).
enum ProcurementCloudSyncState {
  synced,
  pending,
  error,
}

/// Ligne de la file sync contextualisée pour l'utilisateur.
class ProcurementSyncQueueItem {
  const ProcurementSyncQueueItem({
    required this.entityKind,
    required this.localId,
    required this.label,
    required this.state,
    this.detail,
    this.groupKey,
    this.createdAt,
  });

  final ProcurementSyncEntityKind entityKind;
  final int localId;
  final String label;
  final ProcurementCloudSyncState state;
  final String? detail;
  /// Regroupe réception + facture + paiement d'un même appro direct.
  final String? groupKey;
  final int? createdAt;
}

enum ProcurementSyncEntityKind {
  receipt,
  invoice,
  payment,
  purchaseOrder,
  supplier,
}

/// Vue d'ensemble sync du module approvisionnement.
class ProcurementSyncOverview {
  const ProcurementSyncOverview({
    this.items = const [],
    this.bannerMessage,
    this.pendingCount = 0,
    this.errorCount = 0,
    this.documentStates = const {},
  });

  final List<ProcurementSyncQueueItem> items;
  final String? bannerMessage;
  final int pendingCount;
  final int errorCount;

  /// Clé : `receipt:12`, `invoice:5`, `payment:3`, `order:7`
  final Map<String, ProcurementCloudSyncState> documentStates;

  ProcurementCloudSyncState stateFor({
    required ProcurementSyncEntityKind kind,
    required int localId,
    String? serverId,
  }) {
    final key = '${kind.name}:$localId';
    final fromQueue = documentStates[key];
    if (fromQueue != null) return fromQueue;
    if (serverId != null && serverId.isNotEmpty) {
      return ProcurementCloudSyncState.synced;
    }
    return ProcurementCloudSyncState.pending;
  }

  bool get hasIssues => pendingCount > 0 || errorCount > 0;

  List<ProcurementSyncQueueItem> itemsForGroup(String groupKey) {
    return items.where((i) => i.groupKey == groupKey).toList();
  }
}

/// Suivi post-action (appro direct).
class ProcurementDirectSyncProgress {
  const ProcurementDirectSyncProgress({
    required this.receiptNumber,
    required this.receiptDone,
    required this.invoiceExpected,
    required this.invoiceDone,
    required this.paymentExpected,
    required this.paymentDone,
    required this.allDone,
    required this.hasError,
  });

  final String receiptNumber;
  final bool receiptDone;
  final bool invoiceExpected;
  final bool invoiceDone;
  final bool paymentExpected;
  final bool paymentDone;
  final bool allDone;
  final bool hasError;
}
