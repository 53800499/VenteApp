import 'package:equatable/equatable.dart';

import 'voice_draft.dart';

/// Candidat d'intention avec score brut (0..20) et confiance normalisée.
class VoiceIntentCandidate extends Equatable {
  const VoiceIntentCandidate({
    required this.kind,
    required this.rawScore,
    required this.confidence,
  });

  final VoiceIntentKind kind;
  final int rawScore;

  /// 0.0 … 1.0 (rawScore / 20).
  final double confidence;

  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  @override
  List<Object?> get props => [kind, rawScore, confidence];
}

/// Résultat du moteur d'intentions (indépendant de la formulation exacte).
class VoiceIntentDetection extends Equatable {
  const VoiceIntentDetection({
    required this.kind,
    required this.confidence,
    required this.rawScore,
    this.alternatives = const [],
    this.needsClarification = false,
  });

  final VoiceIntentKind kind;
  final double confidence;
  final int rawScore;
  final List<VoiceIntentCandidate> alternatives;
  final bool needsClarification;

  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  static const VoiceIntentDetection empty = VoiceIntentDetection(
    kind: VoiceIntentKind.unknown,
    confidence: 0,
    rawScore: 0,
  );

  @override
  List<Object?> get props =>
      [kind, confidence, rawScore, alternatives, needsClarification];
}

/// Seuil sous lequel on clarifie **si** des alternatives existent.
/// Score brut 5/20 ≈ 0.25.
const kVoiceConfidenceClarifyThreshold = 0.25;
