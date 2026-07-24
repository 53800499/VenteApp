import '../sync_constants.dart';
import 'sync_workflow.dart';

class SalesOrderWorkflow implements SyncWorkflow {
  const SalesOrderWorkflow();

  @override
  String get entityTable => SyncEntityTable.salesOrders;

  @override
  List<String> get steps => const [
        SyncOperation.create,
        SyncOperation.confirm,
        SyncOperation.preparing,
        SyncOperation.deliver,
        SyncOperation.close,
      ];

  @override
  int operationPriority(String operation) => switch (operation) {
        SyncOperation.create => 0,
        SyncOperation.update => 1,
        SyncOperation.confirm => 2,
        SyncOperation.preparing => 3,
        SyncOperation.deliver => 4,
        SyncOperation.close => 5,
        SyncOperation.cancel => 6,
        _ => 50,
      };

  @override
  List<List<String>> prerequisites(String operation) => switch (operation) {
        SyncOperation.confirm => const [
            [SyncOperation.create],
          ],
        SyncOperation.preparing => const [
            [SyncOperation.create],
            [SyncOperation.confirm],
          ],
        SyncOperation.deliver => const [
            [SyncOperation.create],
            [SyncOperation.confirm],
          ],
        SyncOperation.close || SyncOperation.cancel => const [
            [SyncOperation.create],
          ],
        _ => const [],
      };

  @override
  String humanLabel(String operation) => switch (operation) {
        SyncOperation.confirm => 'Confirmation',
        SyncOperation.preparing => 'Préparation',
        SyncOperation.deliver => 'Livraison',
        _ => defaultOperationLabel(operation),
      };

  @override
  String blockedMessage({
    required String current,
    required String waitingFor,
  }) {
    return '${humanLabel(waitingFor)} encore en attente de synchronisation. '
        '${humanLabel(current)} sera envoyée automatiquement dès que '
        'l\'étape précédente sera synchronisée. Relancez simplement la sync.';
  }

  @override
  bool isAlreadyApplied(Map<String, dynamic> remoteSnapshot, String operation) {
    final status = (remoteSnapshot['status'] as String? ?? '').toLowerCase();
    return switch (operation) {
      SyncOperation.create => remoteSnapshot['id'] != null,
      SyncOperation.confirm => _rank(status) >= _rank('confirmed'),
      SyncOperation.preparing => _rank(status) >= _rank('preparing'),
      SyncOperation.deliver =>
        status == 'partially_delivered' ||
            status == 'delivered' ||
            status == 'closed',
      SyncOperation.close => status == 'closed' || status == 'cancelled',
      SyncOperation.cancel => status == 'cancelled',
      _ => false,
    };
  }

  @override
  bool shouldAttemptHeal(String errorMessage, String operation) {
    final lower = errorMessage.toLowerCase();
    if (lower.contains('déjà') || lower.contains('deja')) return true;
    if (lower.contains('already')) return true;
    if (lower.contains('ne peut pas') || lower.contains('statut')) return true;
    if (lower.contains('409') || lower.contains('conflict')) return true;
    return operation == SyncOperation.confirm ||
        operation == SyncOperation.preparing ||
        operation == SyncOperation.deliver ||
        operation == SyncOperation.close;
  }

  static int _rank(String status) => switch (status) {
        'draft' => 0,
        'confirmed' => 1,
        'preparing' => 2,
        'partially_delivered' => 3,
        'delivered' => 4,
        'closed' => 5,
        'cancelled' => 6,
        _ => -1,
      };
}

class StockTransferWorkflow implements SyncWorkflow {
  const StockTransferWorkflow();

  @override
  String get entityTable => SyncEntityTable.stockTransfers;

  @override
  List<String> get steps => const [
        SyncOperation.create,
        SyncOperation.validate,
        SyncOperation.submit,
        SyncOperation.approve,
        SyncOperation.send,
        SyncOperation.receive,
        SyncOperation.resolveDiscrepancy,
        SyncOperation.close,
      ];

  @override
  int operationPriority(String operation) => switch (operation) {
        SyncOperation.create => 0,
        SyncOperation.update => 1,
        SyncOperation.validate => 2,
        SyncOperation.submit => 3,
        SyncOperation.approve => 4,
        SyncOperation.send => 5,
        SyncOperation.receive => 6,
        SyncOperation.resolveDiscrepancy => 7,
        SyncOperation.cancel => 8,
        SyncOperation.close => 9,
        _ => 50,
      };

  @override
  List<List<String>> prerequisites(String operation) => switch (operation) {
        SyncOperation.validate || SyncOperation.submit => const [
            [SyncOperation.create],
          ],
        SyncOperation.approve => const [
            [SyncOperation.create],
            [SyncOperation.submit],
          ],
        SyncOperation.send => const [
            [SyncOperation.create],
            [SyncOperation.submit],
            [SyncOperation.validate, SyncOperation.approve],
          ],
        SyncOperation.receive => const [
            [SyncOperation.create],
            [SyncOperation.send],
          ],
        SyncOperation.resolveDiscrepancy => const [
            [SyncOperation.create],
            [SyncOperation.send],
          ],
        SyncOperation.close || SyncOperation.cancel => const [
            [SyncOperation.create],
          ],
        _ => const [],
      };

  @override
  String humanLabel(String operation) => switch (operation) {
        SyncOperation.send => 'Expédition',
        SyncOperation.resolveDiscrepancy => 'Résolution d\'écart',
        _ => defaultOperationLabel(operation),
      };

  @override
  String blockedMessage({
    required String current,
    required String waitingFor,
  }) {
    return '${humanLabel(waitingFor)} encore en file cloud. '
        '${humanLabel(current)} partira automatiquement ensuite. '
        'Relancez la synchronisation — ne recréez pas l\'action.';
  }

  @override
  bool isAlreadyApplied(Map<String, dynamic> remoteSnapshot, String operation) {
    final status = remoteSnapshot['status'] as String? ?? '';
    return switch (operation) {
      SyncOperation.create => remoteSnapshot['id'] != null,
      SyncOperation.validate || SyncOperation.approve =>
        status != 'draft' &&
            status != 'pending_approval' &&
            status != 'cancelled',
      SyncOperation.submit =>
        status == 'pending_approval' ||
            status == 'validated' ||
            _isPostValidated(status),
      SyncOperation.send =>
        status == 'partially_shipped' ||
            status == 'shipped' ||
            status == 'partially_received' ||
            status == 'received' ||
            status == 'closed' ||
            status == 'closed_with_exception',
      SyncOperation.receive =>
        status == 'partially_received' ||
            status == 'received' ||
            status == 'closed' ||
            status == 'closed_with_exception',
      SyncOperation.resolveDiscrepancy =>
        status == 'closed' || status == 'closed_with_exception',
      SyncOperation.close =>
        status == 'closed' || status == 'closed_with_exception',
      SyncOperation.cancel => status == 'cancelled',
      _ => false,
    };
  }

  @override
  bool shouldAttemptHeal(String errorMessage, String operation) {
    final lower = errorMessage.toLowerCase();
    return lower.contains('ne peut pas') ||
        lower.contains('trop élevée') ||
        lower.contains('trop elevee') ||
        lower.contains('déjà') ||
        lower.contains('deja') ||
        lower.contains('brouillon') ||
        operation == SyncOperation.send ||
        operation == SyncOperation.resolveDiscrepancy ||
        operation == SyncOperation.receive;
  }

  static bool _isPostValidated(String status) =>
      status == 'validated' ||
      status == 'partially_shipped' ||
      status == 'shipped' ||
      status == 'partially_received' ||
      status == 'received' ||
      status == 'closed' ||
      status == 'closed_with_exception';
}

class PurchaseOrderWorkflow implements SyncWorkflow {
  const PurchaseOrderWorkflow();

  @override
  String get entityTable => SyncEntityTable.purchaseOrders;

  @override
  List<String> get steps => const [
        SyncOperation.create,
        SyncOperation.validate,
        SyncOperation.send,
        SyncOperation.receive,
        SyncOperation.cancel,
      ];

  @override
  int operationPriority(String operation) => switch (operation) {
        SyncOperation.create => 0,
        SyncOperation.update => 1,
        SyncOperation.validate => 2,
        SyncOperation.send => 3,
        SyncOperation.receive => 4,
        SyncOperation.cancel => 5,
        _ => 50,
      };

  @override
  List<List<String>> prerequisites(String operation) => switch (operation) {
        SyncOperation.validate => const [
            [SyncOperation.create],
          ],
        SyncOperation.send => const [
            [SyncOperation.create],
            [SyncOperation.validate],
          ],
        SyncOperation.receive => const [
            [SyncOperation.create],
            [SyncOperation.send],
          ],
        SyncOperation.cancel => const [
            [SyncOperation.create],
          ],
        _ => const [],
      };

  @override
  String humanLabel(String operation) => defaultOperationLabel(operation);

  @override
  String blockedMessage({
    required String current,
    required String waitingFor,
  }) {
    return '${humanLabel(waitingFor)} de la commande d\'achat encore en attente. '
        '${humanLabel(current)} suivra automatiquement. Relancez la sync.';
  }

  @override
  bool isAlreadyApplied(Map<String, dynamic> remoteSnapshot, String operation) {
    final status = (remoteSnapshot['status'] as String? ?? '').toLowerCase();
    return switch (operation) {
      SyncOperation.create => remoteSnapshot['id'] != null,
      SyncOperation.validate =>
        status == 'validated' ||
            status == 'sent' ||
            status == 'partially_received' ||
            status == 'received' ||
            status == 'closed',
      SyncOperation.send =>
        status == 'sent' ||
            status == 'partially_received' ||
            status == 'received' ||
            status == 'closed',
      SyncOperation.receive =>
        status == 'partially_received' ||
            status == 'received' ||
            status == 'closed',
      SyncOperation.cancel => status == 'cancelled',
      _ => false,
    };
  }

  @override
  bool shouldAttemptHeal(String errorMessage, String operation) {
    final lower = errorMessage.toLowerCase();
    return lower.contains('ne peut pas') ||
        lower.contains('déjà') ||
        lower.contains('deja') ||
        lower.contains('statut');
  }
}
