import '../entities/voice_draft.dart';

enum VoiceWorkflowStatus {
  asking,
  ready,
  readyBatch,
  openForm,
  failed,
  cancelled,
}

/// Question posée à l'utilisateur pendant un workflow.
class VoiceWorkflowPrompt {
  const VoiceWorkflowPrompt({
    required this.question,
    this.details,
  });

  final String question;
  final String? details;
}

/// Contrat d'un workflow conversationnel métier.
abstract class VoiceWorkflow {
  VoiceIntentKind get kind;
  VoiceWorkflowStatus get status;
  VoiceWorkflowPrompt? get currentPrompt;
  String? get failureMessage;

  /// Brouillon unique quand [status] == ready.
  VoiceDraft? get draft;

  /// Plusieurs paiements (ex. « tout ») quand [status] == readyBatch.
  List<VoiceDebtPaymentDraft> get batchDrafts => const [];

  /// Résumé pour confirmation batch.
  String? get batchSummary => null;

  /// Cible formulaire quand [status] == openForm (ex. PO multi-lignes).
  Object? get formTarget => null;

  /// Démarre avec la phrase d'intention (peut déjà poser une question).
  Future<void> bootstrap(String initialTranscript);

  /// Avance avec la réponse vocale de l'utilisateur.
  Future<void> advance(String transcript);

  void cancel() {}
}

/// Helpers partagés pour réponses oui/non / numéros.
abstract final class VoiceWorkflowParsing {
  static bool isYes(String lower) => RegExp(
        r"\b(oui|ouais|ok|d['’]?accord|confirme|confirmer|valide|valider|yes)\b",
      ).hasMatch(lower);

  static bool isNo(String lower) => RegExp(
        r'\b(non|annule|annuler|stop|no)\b',
      ).hasMatch(lower);

  static bool isAll(String lower) => RegExp(
        r'\b(tout|toutes|tous|int[eé]gral|sold[eé]r?\s+tout)\b',
      ).hasMatch(lower);

  static bool isLast(String lower) => RegExp(
        r'\b(derni[eè]re|dernier|la\s+derni[eè]re|le\s+dernier)\b',
      ).hasMatch(lower);

  static int? extractInt(String lower) {
    final m = RegExp(r'(\d{1,9})').firstMatch(lower);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static int? extractAmount(String lower) {
    final m = RegExp(
      r'(\d{1,3}(?:[\s.\u00a0]\d{3})+|\d+)\s*(?:fcfa|francs?|f)?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (m == null) return extractInt(lower);
    final digits = m.group(1)!.replaceAll(RegExp(r'[\s.\u00a0]'), '');
    return int.tryParse(digits);
  }
}
