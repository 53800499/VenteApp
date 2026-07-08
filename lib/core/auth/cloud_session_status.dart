import '../constants/api_config.dart';

/// Niveaux de confiance de la session cloud pour une application offline-first.
///
/// La durée de fonctionnement local n'est pas « tout permis sans serveur » mais
/// une **durée maximale de fonctionnement avec une session cloud non validée**.
/// Plus le dernier contact serveur réussi est ancien, plus l'application perd
/// des capacités nécessitant une confiance serveur — sans jamais désactiver le
/// cœur métier (ventes, dépenses, stock restent locaux).
enum CloudSessionLevel {
  /// Session cloud fraîche : jeton valide ou fenêtre d'accès serveur ouverte.
  online,

  /// Hors ligne récent (0–24 h) : tout fonctionne, indicateur discret.
  offlineRecent,

  /// Hors ligne prolongé (1–7 j) : fonctionnel, mais l'app insiste au démarrage.
  offlineProlonged,

  /// Limite atteinte (>7 j) : validation cloud requise pour les opérations
  /// sensibles (le cœur métier reste utilisable).
  actionRequired,
}

/// État agrégé de la session cloud, dérivé du dernier contact serveur réussi.
class CloudSessionStatus {
  const CloudSessionStatus({
    required this.level,
    required this.lastServerContactAt,
    required this.evaluatedAtMs,
  });

  /// État neutre initial (aucune dégradation signalée).
  const CloudSessionStatus.initial()
      : level = CloudSessionLevel.online,
        lastServerContactAt = null,
        evaluatedAtMs = 0;

  final CloudSessionLevel level;

  /// Horodatage (ms epoch) du dernier contact serveur réussi, si connu.
  final int? lastServerContactAt;

  /// Instant (ms epoch) auquel le niveau a été évalué.
  final int evaluatedAtMs;

  /// Échéance de la période de grâce hors ligne (dernier contact + 7 j).
  int? get offlineGraceUntilMs => lastServerContactAt == null
      ? null
      : lastServerContactAt! + ApiConfig.offlineGraceMs;

  /// Durée écoulée depuis le dernier contact serveur réussi.
  Duration? get sinceLastContact => lastServerContactAt == null
      ? null
      : Duration(milliseconds: evaluatedAtMs - lastServerContactAt!);

  /// Temps restant avant la limite des 7 jours (0 si dépassée).
  Duration get remainingGrace {
    final until = offlineGraceUntilMs;
    if (until == null) return Duration.zero;
    final remaining = until - evaluatedAtMs;
    return remaining <= 0 ? Duration.zero : Duration(milliseconds: remaining);
  }

  /// Les opérations nécessitant une confiance serveur sont-elles autorisées ?
  /// Faux uniquement à la limite atteinte (>7 j sans validation cloud).
  bool get allowsTrustedServerOperations =>
      level != CloudSessionLevel.actionRequired;

  /// Faut-il présenter un avis au démarrage (prolongé ou limite atteinte) ?
  bool get needsStartupNotice =>
      level == CloudSessionLevel.offlineProlonged ||
      level == CloudSessionLevel.actionRequired;

  CloudSessionStatus copyWith({
    CloudSessionLevel? level,
    int? lastServerContactAt,
    int? evaluatedAtMs,
  }) {
    return CloudSessionStatus(
      level: level ?? this.level,
      lastServerContactAt: lastServerContactAt ?? this.lastServerContactAt,
      evaluatedAtMs: evaluatedAtMs ?? this.evaluatedAtMs,
    );
  }

  /// Libellé relatif du dernier contact serveur (« aujourd'hui », « il y a 3 j »).
  String get relativeLastContactLabel {
    final since = sinceLastContact;
    if (since == null) return 'jamais synchronisé';
    if (since.inMinutes < 60) return "il y a moins d'une heure";
    if (since.inHours < 24) {
      final h = since.inHours;
      return 'il y a $h heure${h > 1 ? 's' : ''}';
    }
    final days = since.inDays;
    return 'il y a $days jour${days > 1 ? 's' : ''}';
  }

  /// Message utilisateur adapté au niveau (pour bannière / avis de démarrage).
  String get userMessage => switch (level) {
        CloudSessionLevel.online =>
          'Synchronisé — vos données sont à jour sur le cloud.',
        CloudSessionLevel.offlineRecent =>
          'Hors ligne — dernière synchronisation $relativeLastContactLabel. '
              'Vos ventes continuent, synchronisation à la reconnexion.',
        CloudSessionLevel.offlineProlonged =>
          'Hors ligne depuis un moment (dernier contact serveur '
              '$relativeLastContactLabel). Vos données seront synchronisées dès '
              'que possible.',
        CloudSessionLevel.actionRequired =>
          'Session cloud à vérifier (plus de 7 jours sans contact serveur). '
              'Connectez-vous à Internet pour synchroniser ; certaines '
              'opérations sensibles sont temporairement indisponibles.',
      };

  @override
  bool operator ==(Object other) =>
      other is CloudSessionStatus &&
      other.level == level &&
      other.lastServerContactAt == lastServerContactAt;

  @override
  int get hashCode => Object.hash(level, lastServerContactAt);
}

/// Résout le niveau de session cloud à partir du dernier contact serveur.
///
/// - [serverReachableNow] : jeton d'accès valide OU fenêtre d'accès serveur
///   ouverte (contact récent garanti) → [CloudSessionLevel.online].
/// - Sinon, l'ancienneté du dernier contact détermine le niveau dégradé.
///
/// Si [lastServerContactAt] est inconnu (jamais enregistré), on reste prudent
/// mais non punitif : niveau prolongé (avis au démarrage) sans blocage, sauf si
/// [assumeStaleWhenUnknown] force la limite atteinte.
CloudSessionLevel resolveCloudSessionLevel({
  required bool serverReachableNow,
  required int? lastServerContactAt,
  required int nowMs,
  bool assumeStaleWhenUnknown = false,
}) {
  if (serverReachableNow) return CloudSessionLevel.online;

  if (lastServerContactAt == null) {
    return assumeStaleWhenUnknown
        ? CloudSessionLevel.actionRequired
        : CloudSessionLevel.offlineProlonged;
  }

  final ageMs = nowMs - lastServerContactAt;
  if (ageMs < ApiConfig.offlineRecentMs) return CloudSessionLevel.offlineRecent;
  if (ageMs < ApiConfig.offlineGraceMs) return CloudSessionLevel.offlineProlonged;
  return CloudSessionLevel.actionRequired;
}
