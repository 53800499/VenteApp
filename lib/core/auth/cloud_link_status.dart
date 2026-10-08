import '../sync/sync_snapshot.dart';

/// État de la liaison cloud, indépendant de l'authentification locale (PIN).
enum CloudLinkStatus {
  /// Réseau disponible et synchronisation à jour.
  connected,

  /// Pas de connexion internet.
  disconnected,

  /// Synchronisation en cours.
  syncing,

  /// Erreur ou conflit de synchronisation.
  syncError,

  /// Synchronisation cloud désactivée intentionnellement (mode local).
  localOnly,
}

extension CloudLinkStatusLabels on CloudLinkStatus {
  String get label => switch (this) {
        CloudLinkStatus.connected => 'Synchronisé',
        CloudLinkStatus.disconnected => 'Cloud indisponible',
        CloudLinkStatus.syncing => 'Synchronisation en cours',
        CloudLinkStatus.syncError => 'Erreur de synchronisation',
        CloudLinkStatus.localOnly => 'Mode local',
      };

  String get emoji => switch (this) {
        CloudLinkStatus.connected => '🟢',
        CloudLinkStatus.disconnected => '🔴',
        CloudLinkStatus.syncing => '🟡',
        CloudLinkStatus.syncError => '🔴',
        CloudLinkStatus.localOnly => '⚫',
      };
}

CloudLinkStatus resolveCloudLinkStatus({
  required bool isConnected,
  required SyncSnapshot sync,
}) {
  // Le statut localOnly ne s'applique que si la boutique a été formellement
  // évaluée avec la synchronisation cloud désactivée (forfait gratuit permanent ou choix explicite).
  // Si le shopId est nul (instantané idle initial avant résolution), on ne doit pas
  // préjuger d'un "Mode local".
  if (sync.shopId != null && !sync.cloudSyncEnabled) {
    return CloudLinkStatus.localOnly;
  }

  if (!isConnected ||
      sync.indicatorState == SyncIndicatorState.offline ||
      sync.indicatorState == SyncIndicatorState.waitingForConnection) {
    return CloudLinkStatus.disconnected;
  }

  if (sync.phase == SyncRunPhase.running) {
    return CloudLinkStatus.syncing;
  }

  if (sync.indicatorState == SyncIndicatorState.conflict ||
      sync.hasFailures ||
      sync.blockReason != null) {
    return CloudLinkStatus.syncError;
  }

  if (sync.indicatorState == SyncIndicatorState.pending ||
      sync.pendingQueueCount > 0) {
    return CloudLinkStatus.syncing;
  }

  return CloudLinkStatus.connected;
}
