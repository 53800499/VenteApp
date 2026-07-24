import '../sync_constants.dart';

/// Contrat d'un workflow multi-étapes synchronisé vers le cloud.
abstract class SyncWorkflow {
  String get entityTable;

  /// Étapes métier ordonnées (hors update/cancel transverses si besoin).
  List<String> get steps;

  /// Priorité de tri dans la file (plus petit = plus tôt).
  int operationPriority(String operation);

  /// Ops amont qui doivent être absentes de la file `pending` avant [operation].
  /// Une entrée peut être un groupe alternatif (ex. validate OU approve).
  List<List<String>> prerequisites(String operation);

  String humanLabel(String operation);

  /// Message actionnable quand [waitingFor] bloque [current].
  String blockedMessage({
    required String current,
    required String waitingFor,
  });

  /// True si le snapshot cloud indique que [operation] est déjà appliquée.
  bool isAlreadyApplied(Map<String, dynamic> remoteSnapshot, String operation);

  /// True si l'erreur Nest suggère un heal idempotent (fetch + isAlreadyApplied).
  bool shouldAttemptHeal(String errorMessage, String operation);
}

/// Opération en file pour dériver la progression.
class WorkflowPendingOp {
  const WorkflowPendingOp({
    required this.operation,
    this.lastError,
  });

  final String operation;
  final String? lastError;
}

/// Progression dérivée (pas de table Drift V1).
class WorkflowProgress {
  const WorkflowProgress({
    required this.entityTable,
    required this.recordId,
    required this.steps,
    required this.completed,
    required this.pending,
    this.current,
    this.waitingFor,
    this.blockedReason,
  });

  final String entityTable;
  final int recordId;
  final List<String> steps;
  final List<String> completed;
  final List<String> pending;
  final String? current;
  final String? waitingFor;
  final String? blockedReason;

  /// Lignes UI : `✓ Création`, `⏳ Confirmation`, `○ Livraison`.
  List<String> formatLines(SyncWorkflow workflow) {
    return [
      for (final step in steps)
        if (completed.contains(step))
          '✓ ${workflow.humanLabel(step)}'
        else if (step == current ||
            step == waitingFor ||
            pending.contains(step))
          '⏳ ${workflow.humanLabel(step)}'
        else
          '○ ${workflow.humanLabel(step)}',
    ];
  }

  static WorkflowProgress derive({
    required SyncWorkflow workflow,
    required int recordId,
    required List<WorkflowPendingOp> pendingOps,
    String? attemptingOperation,
  }) {
    final pendingSet = {
      for (final op in pendingOps) op.operation,
    };

    final completed = <String>[];
    for (final step in workflow.steps) {
      if (pendingSet.contains(step)) break;
      completed.add(step);
    }

    String? waitingFor;
    String? blockedReason;
    final current = attemptingOperation ??
        (pendingOps.isEmpty ? null : _earliestPending(workflow, pendingSet));

    if (current != null) {
      waitingFor = firstPendingPrerequisite(
        workflow: workflow,
        operation: current,
        pendingOperations: pendingSet,
      );
      if (waitingFor != null) {
        blockedReason = workflow.blockedMessage(
          current: current,
          waitingFor: waitingFor,
        );
      } else {
        for (final op in pendingOps) {
          if (op.operation == current &&
              op.lastError != null &&
              op.lastError!.trim().isNotEmpty) {
            blockedReason = op.lastError;
            break;
          }
        }
      }
    }

    return WorkflowProgress(
      entityTable: workflow.entityTable,
      recordId: recordId,
      steps: List.unmodifiable(workflow.steps),
      completed: List.unmodifiable(completed),
      pending: List.unmodifiable(pendingSet.toList()),
      current: current,
      waitingFor: waitingFor,
      blockedReason: blockedReason,
    );
  }

  static String? _earliestPending(SyncWorkflow workflow, Set<String> pending) {
    for (final step in workflow.steps) {
      if (pending.contains(step)) return step;
    }
    for (final op in pending) {
      return op;
    }
    return null;
  }
}

/// Arrêt de chaîne après un échec / différé / conflit.
enum QueueItemOutcome { processed, deferred, failed, conflict }

bool shouldContinueChain(QueueItemOutcome outcome) =>
    outcome == QueueItemOutcome.processed;

/// Résout le premier prérequis encore pending pour [operation].
String? firstPendingPrerequisite({
  required SyncWorkflow workflow,
  required String operation,
  required Set<String> pendingOperations,
}) {
  for (final group in workflow.prerequisites(operation)) {
    for (final op in group) {
      if (pendingOperations.contains(op)) return op;
    }
  }
  return null;
}

/// Libellés partagés pour ops transverses.
String defaultOperationLabel(String operation) => switch (operation) {
      SyncOperation.create => 'Création',
      SyncOperation.update => 'Modification',
      SyncOperation.validate => 'Validation',
      SyncOperation.submit => 'Soumission',
      SyncOperation.approve => 'Approbation',
      SyncOperation.send => 'Expédition',
      SyncOperation.receive => 'Réception',
      SyncOperation.confirm => 'Confirmation',
      SyncOperation.preparing => 'Préparation',
      SyncOperation.deliver => 'Livraison',
      SyncOperation.close => 'Clôture',
      SyncOperation.cancel => 'Annulation',
      SyncOperation.resolveDiscrepancy => 'Résolution d\'écart',
      _ => operation,
    };
