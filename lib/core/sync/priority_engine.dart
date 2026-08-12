import '../database/app_database.dart';

/// Niveaux de criticité métier pour les opérations de synchronisation.
enum BusinessCriticality {
  critical,
  high,
  normal,
  low,
}

/// Moteur de calcul dynamique de priorité au runtime pour ARIKE.
///
/// **Principe d'Architecture** :
/// Le score n'est pas figé de manière absolue en BDD, mais calculé au runtime par ce moteur
/// pour prendre en compte le surélévation par dépendance (Priority Boosting) et l'ancienneté
/// bornée (Bounded Aging) sans risque de starvation.
class PriorityEngine {
  const PriorityEngine();

  /// Poids de base selon la criticité métier.
  static int weightForCriticality(BusinessCriticality criticality) {
    switch (criticality) {
      case BusinessCriticality.critical:
        return 100000;
      case BusinessCriticality.high:
        return 10000;
      case BusinessCriticality.normal:
        return 1000;
      case BusinessCriticality.low:
        return 100;
    }
  }

  /// Convertit une chaîne de texte en [BusinessCriticality].
  static BusinessCriticality parseCriticality(String value) {
    switch (value.toUpperCase()) {
      case 'CRITICAL':
        return BusinessCriticality.critical;
      case 'HIGH':
        return BusinessCriticality.high;
      case 'LOW':
        return BusinessCriticality.low;
      case 'NORMAL':
      default:
        return BusinessCriticality.normal;
    }
  }

  /// Calcule le score de priorité effectif au runtime.
  ///
  /// $$\text{Score} = \text{CriticalityWeight} + \text{BasePriority} + \text{DependencyBoost} + \text{BoundedAging}$$
  int computeEffectiveScore(SyncQueueData item, {int nowMs = 0}) {
    final now = nowMs > 0 ? nowMs : DateTime.now().millisecondsSinceEpoch;
    final criticality = parseCriticality(item.businessCriticality);
    final criticalityWeight = weightForCriticality(criticality);

    // Aging calculé en minutes écoulées depuis la création
    final ageInMinutes = ((now - item.createdAt) / 60000).floor().clamp(0, 10000);

    // Bounded Aging : L'aging est plafonné selon le niveau de criticité pour qu'un
    // élément LOW (rapport) ne dépasse JAMAIS une vente CRITICAL ou une clôture de caisse HIGH.
    final maxAgingCap = switch (criticality) {
      BusinessCriticality.critical => 5000,
      BusinessCriticality.high => 2000,
      BusinessCriticality.normal => 400,
      BusinessCriticality.low => 50,
    };

    final boundedAging = ageInMinutes.clamp(0, maxAgingCap);

    return criticalityWeight + item.basePriority + item.dependencyBoost + boundedAging;
  }

  /// Trie une liste d'éléments de la file d'attente par score effectif décroissant.
  List<SyncQueueData> rankQueueItems(List<SyncQueueData> items, {int nowMs = 0}) {
    final ranked = List<SyncQueueData>.from(items);
    ranked.sort((a, b) {
      final scoreA = computeEffectiveScore(a, nowMs: nowMs);
      final scoreB = computeEffectiveScore(b, nowMs: nowMs);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Score élevé en premier
      }
      return a.createdAt.compareTo(b.createdAt); // FIFO en cas d'égalité
    });
    return ranked;
  }
}
