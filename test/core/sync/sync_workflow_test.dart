import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/sync/sync_constants.dart';
import 'package:venteapp/core/sync/workflow/sync_workflow.dart';
import 'package:venteapp/core/sync/workflow/sync_workflow_registry.dart';
import 'package:venteapp/core/sync/workflow/workflows.dart';

void main() {
  group('shouldContinueChain', () {
    test('continue seulement après processed', () {
      expect(shouldContinueChain(QueueItemOutcome.processed), isTrue);
      expect(shouldContinueChain(QueueItemOutcome.deferred), isFalse);
      expect(shouldContinueChain(QueueItemOutcome.failed), isFalse);
      expect(shouldContinueChain(QueueItemOutcome.conflict), isFalse);
    });
  });

  group('SalesOrderWorkflow', () {
    const workflow = SalesOrderWorkflow();

    test('priorités confirm < preparing < deliver', () {
      expect(
        workflow.operationPriority(SyncOperation.confirm),
        lessThan(workflow.operationPriority(SyncOperation.preparing)),
      );
      expect(
        workflow.operationPriority(SyncOperation.preparing),
        lessThan(workflow.operationPriority(SyncOperation.deliver)),
      );
    });

    test('deliver bloque si confirm encore pending', () {
      expect(
        firstPendingPrerequisite(
          workflow: workflow,
          operation: SyncOperation.deliver,
          pendingOperations: {
            SyncOperation.confirm,
            SyncOperation.deliver,
          },
        ),
        SyncOperation.confirm,
      );
    });

    test('isAlreadyApplied confirm si preparing cloud', () {
      expect(
        workflow.isAlreadyApplied({'status': 'preparing'}, SyncOperation.confirm),
        isTrue,
      );
      expect(
        workflow.isAlreadyApplied({'status': 'draft'}, SyncOperation.confirm),
        isFalse,
      );
    });

    test('blockedMessage actionnable', () {
      final msg = workflow.blockedMessage(
        current: SyncOperation.deliver,
        waitingFor: SyncOperation.confirm,
      );
      expect(msg.toLowerCase(), contains('confirmation'));
      expect(msg.toLowerCase(), contains('sync'));
    });
  });

  group('StockTransferWorkflow', () {
    const workflow = StockTransferWorkflow();

    test('send bloque sur validate pending', () {
      expect(
        firstPendingPrerequisite(
          workflow: workflow,
          operation: SyncOperation.send,
          pendingOperations: {
            SyncOperation.validate,
            SyncOperation.send,
          },
        ),
        SyncOperation.validate,
      );
    });

    test('send bloque sur submit pending', () {
      expect(
        firstPendingPrerequisite(
          workflow: workflow,
          operation: SyncOperation.send,
          pendingOperations: {SyncOperation.submit, SyncOperation.send},
        ),
        SyncOperation.submit,
      );
    });

    test('resolve_discrepancy bloque sur send', () {
      expect(
        firstPendingPrerequisite(
          workflow: workflow,
          operation: SyncOperation.resolveDiscrepancy,
          pendingOperations: {
            SyncOperation.send,
            SyncOperation.resolveDiscrepancy,
          },
        ),
        SyncOperation.send,
      );
    });
  });

  group('WorkflowProgress.derive', () {
    test('montre completed puis waiting', () {
      const workflow = SalesOrderWorkflow();
      final progress = WorkflowProgress.derive(
        workflow: workflow,
        recordId: 45,
        pendingOps: const [
          WorkflowPendingOp(operation: SyncOperation.confirm),
          WorkflowPendingOp(operation: SyncOperation.preparing),
          WorkflowPendingOp(operation: SyncOperation.deliver),
        ],
        attemptingOperation: SyncOperation.confirm,
      );

      expect(progress.completed, [SyncOperation.create]);
      expect(progress.current, SyncOperation.confirm);
      expect(progress.waitingFor, isNull);

      final lines = progress.formatLines(workflow);
      expect(lines.first, startsWith('✓'));
      expect(lines.any((l) => l.startsWith('⏳')), isTrue);
    });

    test('waitingFor quand prérequis pending', () {
      const workflow = SalesOrderWorkflow();
      final progress = WorkflowProgress.derive(
        workflow: workflow,
        recordId: 45,
        pendingOps: const [
          WorkflowPendingOp(operation: SyncOperation.confirm),
          WorkflowPendingOp(operation: SyncOperation.deliver),
        ],
        attemptingOperation: SyncOperation.deliver,
      );
      expect(progress.waitingFor, SyncOperation.confirm);
      expect(progress.blockedReason, isNotNull);
    });
  });

  group('SyncWorkflowRegistry', () {
    test('lookup tables connues', () {
      expect(
        SyncWorkflowRegistry.forTable(SyncEntityTable.salesOrders),
        isA<SalesOrderWorkflow>(),
      );
      expect(
        SyncWorkflowRegistry.forTable(SyncEntityTable.stockTransfers),
        isA<StockTransferWorkflow>(),
      );
      expect(
        SyncWorkflowRegistry.forTable(SyncEntityTable.purchaseOrders),
        isA<PurchaseOrderWorkflow>(),
      );
      expect(SyncWorkflowRegistry.forTable(SyncEntityTable.sales), isNull);
    });

    test('priority via registry pour SO', () {
      expect(
        SyncWorkflowRegistry.operationPriority(
          SyncEntityTable.salesOrders,
          SyncOperation.confirm,
        ),
        2,
      );
      expect(
        SyncWorkflowRegistry.operationPriority(
          SyncEntityTable.salesOrders,
          SyncOperation.deliver,
        ),
        4,
      );
    });
  });
}
