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
}

extension CloudLinkStatusLabels on CloudLinkStatus {
  String get label => switch (this) {
        CloudLinkStatus.connected => 'Synchronisé',
        CloudLinkStatus.disconnected => 'Cloud indisponible',
        CloudLinkStatus.syncing => 'Synchronisation en cours',
        CloudLinkStatus.syncError => 'Erreur de synchronisation',
      };

  String get emoji => switch (this) {
        CloudLinkStatus.connected => '🟢',
        CloudLinkStatus.disconnected => '🔴',
        CloudLinkStatus.syncing => '🟡',
        CloudLinkStatus.syncError => '🔴',
      };
}

CloudLinkStatus resolveCloudLinkStatus({
  required bool isConnected,
  required SyncSnapshot sync,
}) {
  if (!sync.cloudSyncEnabled) {
    return isConnected ? CloudLinkStatus.connected : CloudLinkStatus.disconnected;
  }

  if (!isConnected) return CloudLinkStatus.disconnected;

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
