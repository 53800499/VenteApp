import '../sync_constants.dart';
import 'sync_workflow.dart';
import 'workflows.dart';

/// Registre des workflows multi-étapes connus du moteur de sync.
abstract final class SyncWorkflowRegistry {
  static const Map<String, SyncWorkflow> _byTable = {
    SyncEntityTable.salesOrders: SalesOrderWorkflow(),
    SyncEntityTable.stockTransfers: StockTransferWorkflow(),
    SyncEntityTable.purchaseOrders: PurchaseOrderWorkflow(),
  };

  static SyncWorkflow? forTable(String entityTable) => _byTable[entityTable];

  static Iterable<SyncWorkflow> get all => _byTable.values;

  /// Priorité d'opération : workflow si connu, sinon legacy globale.
  static int operationPriority(String entityTable, String operation) {
    final workflow = forTable(entityTable);
    if (workflow != null) return workflow.operationPriority(operation);
    return legacyOperationPriority(operation);
  }

  static int legacyOperationPriority(String operation) => switch (operation) {
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
        SyncOperation.confirm => 2,
        SyncOperation.preparing => 3,
        SyncOperation.deliver => 4,
        SyncOperation.archive => 10,
        SyncOperation.stockAdjust => 11,
        SyncOperation.payment => 12,
        SyncOperation.forgive => 13,
        SyncOperation.saleQuick => 14,
        SyncOperation.cashSessionOpen => 15,
        SyncOperation.cashSessionClose => 16,
        SyncOperation.cashMovementCreate => 17,
        SyncOperation.fxSessionOpen => 18,
        SyncOperation.fxSessionClose => 19,
        SyncOperation.fxSessionConfirmClose => 20,
        SyncOperation.fxSessionCancelClose => 21,
        SyncOperation.fxOperationCreate => 22,
        SyncOperation.fxMovementCreate => 23,
        _ => 50,
      };
}
