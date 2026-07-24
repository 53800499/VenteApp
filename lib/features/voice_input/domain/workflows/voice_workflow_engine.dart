import 'voice_workflow.dart';

export 'voice_workflow.dart';
export 'debt_payment_workflow.dart';
export 'fx_exchange_workflow.dart';
export 'receive_po_workflow.dart';
export 'sale_cart_workflow.dart';

/// Fabrique légère (documentation du contrat moteur).
abstract final class VoiceWorkflowEngine {
  /// Boucle générique : tant que [VoiceWorkflow.status] == asking,
  /// poser [VoiceWorkflow.currentPrompt] et appeler [VoiceWorkflow.advance].
  static bool isTerminal(VoiceWorkflowStatus status) =>
      status != VoiceWorkflowStatus.asking;
}
