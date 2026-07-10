import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection_container.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../auth/cloud_link_status.dart';
import '../../auth/cloud_session_controller.dart';
import '../../auth/cloud_session_coordinator.dart';
import '../../auth/cloud_session_status.dart';
import '../../auth/cloud_session_repair_service.dart';
import '../../auth/widgets/cloud_session_pin_repair_dialog.dart';
import '../../security/production_message_policy.dart';
import '../../sync/sync_display_message.dart';
import '../../sync/sync_service.dart';
import '../../sync/sync_snapshot.dart';
import '../network_info.dart';

/// Bandeau d'état cloud (connexion + synchronisation), indépendant de l'auth locale.
class OfflineModeBanner extends StatefulWidget {
  const OfflineModeBanner({
    super.key,
    this.onlinePreferredMessage,
    this.showWhenSynced = false,
  });

  /// Message alternatif sur les écrans admin (Paramètres, Équipe…).
  final String? onlinePreferredMessage;

  /// Afficher aussi l'état « synchronisé » (🟢) sur l'accueil.
  final bool showWhenSynced;

  /// Cache local affiché ; écritures réservées au serveur.
  static const adminCacheMessage =
      'Hors ligne — affichage des données de cet appareil. '
      'La connexion cloud est nécessaire pour faire des modifications.';

  /// Statistiques / rapports basés sur les données locales.
  static const hybridReadMessage =
      'Hors ligne — statistiques basées sur les données de cet appareil.';

  @override
  State<OfflineModeBanner> createState() => _OfflineModeBannerState();
}

class _OfflineModeBannerState extends State<OfflineModeBanner> {
  /// Durée d'affichage du bandeau « Synchronisé » avant disparition auto.
  /// Les autres états (hors ligne, en cours, erreur) restent affichés.
  static const _syncedAutoHideDelay = Duration(minutes: 3);

  bool? _offline;

  /// Vrai lorsque le bandeau « Synchronisé » a été masqué après son délai.
  bool _syncedDismissed = false;
  Timer? _syncedHideTimer;

  @override
  void initState() {
    super.initState();
    sl<NetworkInfo>().isConnected.then((connected) {
      if (mounted) setState(() => _offline = !connected);
    });
  }

  @override
  void dispose() {
    _syncedHideTimer?.cancel();
    super.dispose();
  }

  /// Gère la disparition automatique du seul état « synchronisé ».
  ///
  /// - État synchronisé : programme un masquage après [_syncedAutoHideDelay].
  /// - Tout autre état : réarme (le bandeau réapparaîtra brièvement au prochain
  ///   retour à l'état synchronisé) et n'est jamais masqué automatiquement.
  void _handleSyncedVisibility(CloudLinkStatus status) {
    final isSynced = status == CloudLinkStatus.connected;
    if (isSynced && widget.showWhenSynced) {
      if (!_syncedDismissed && _syncedHideTimer == null) {
        _syncedHideTimer = Timer(_syncedAutoHideDelay, () {
          _syncedHideTimer = null;
          if (mounted) setState(() => _syncedDismissed = true);
        });
      }
    } else {
      _syncedHideTimer?.cancel();
      _syncedHideTimer = null;
      // Réarme pour que le prochain « Synchronisé » soit de nouveau affiché.
      _syncedDismissed = false;
    }
  }

  String _messageForStatus(CloudLinkStatus status) {
    if (widget.onlinePreferredMessage != null &&
        status == CloudLinkStatus.disconnected) {
      return widget.onlinePreferredMessage!;
    }

    return switch (status) {
      CloudLinkStatus.connected =>
        'Données synchronisées avec le cloud.',
      CloudLinkStatus.disconnected =>
        'Hors ligne — vous pouvez continuer à vendre sans connexion.',
      CloudLinkStatus.syncing =>
        'Synchronisation en cours...',
      CloudLinkStatus.syncError =>
        'Erreur de synchronisation. Vérifiez votre connexion.',
    };
  }

  Color _backgroundForStatus(BuildContext context, CloudLinkStatus status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      CloudLinkStatus.connected => scheme.primaryContainer,
      CloudLinkStatus.disconnected => scheme.tertiaryContainer,
      CloudLinkStatus.syncing => scheme.secondaryContainer,
      CloudLinkStatus.syncError => scheme.errorContainer,
    };
  }

  Color _foregroundForStatus(BuildContext context, CloudLinkStatus status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      CloudLinkStatus.connected => scheme.onPrimaryContainer,
      CloudLinkStatus.disconnected => scheme.onTertiaryContainer,
      CloudLinkStatus.syncing => scheme.onSecondaryContainer,
      CloudLinkStatus.syncError => scheme.onErrorContainer,
    };
  }

  IconData _iconForStatus(CloudLinkStatus status) => switch (status) {
        CloudLinkStatus.connected => Icons.cloud_done_outlined,
        CloudLinkStatus.disconnected => Icons.cloud_off_outlined,
        CloudLinkStatus.syncing => Icons.cloud_sync_outlined,
        CloudLinkStatus.syncError => Icons.warning_amber_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CloudSessionStatus>(
      valueListenable: sl<CloudSessionController>().notifier,
      builder: (context, session, _) {
        return StreamBuilder<List<ConnectivityResult>>(
          stream: Connectivity().onConnectivityChanged,
          builder: (context, connectivitySnapshot) {
            final offline = connectivitySnapshot.hasData
                ? connectivitySnapshot.data!
                    .every((r) => r == ConnectivityResult.none)
                : _offline;

            return StreamBuilder(
              stream: sl<SyncService>().snapshots,
              builder: (context, syncSnapshot) {
                return ValueListenableBuilder<bool>(
                  valueListenable: sl<CloudSessionRepairService>()
                      .awaitingPinUnlockNotifier,
                  builder: (context, isAwaitingPin, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: sl<CloudSessionRepairService>()
                          .repairInProgressNotifier,
                      builder: (context, isRepairing, _) {
                        final sync = syncSnapshot.data ?? const SyncSnapshot.idle();

                        if (isRepairing && sync.blockReason == null && offline != true) {
                          return _sessionBanner(
                            context,
                            message: 'Reconnexion cloud en cours…',
                            background: Theme.of(context).colorScheme.secondaryContainer,
                            foreground: Theme.of(context).colorScheme.onSecondaryContainer,
                            icon: Icons.cloud_sync_outlined,
                            emoji: '🔄',
                          );
                        }

                        final status = resolveCloudLinkStatus(
                          isConnected: offline != true,
                          sync: sync,
                        );

                        if (isAwaitingPin &&
                            sync.blockReason == null &&
                            offline != true) {
                          return _sessionBanner(
                            context,
                            message: CloudSessionRepairService.awaitingPinUnlockMessage,
                            background: Theme.of(context).colorScheme.tertiaryContainer,
                            foreground: Theme.of(context).colorScheme.onTertiaryContainer,
                            icon: Icons.cloud_off_outlined,
                            emoji: '🟠',
                            actions: [
                              TextButton(
                                onPressed: () => _retryCloudRepair(context),
                                child: const Text('Réessayer'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    showCloudSessionPinRepairDialog(context),
                                child: const Text('Code PIN'),
                              ),
                            ],
                          );
                        }

                        // Niveaux dégradés de session cloud : priment sur l'indicateur de
                        // synchro, restent visibles (pas de disparition auto).
                        if (session.level == CloudSessionLevel.actionRequired) {
                          return _sessionBanner(
                            context,
                            message: session.userMessage,
                            background: Theme.of(context).colorScheme.errorContainer,
                            foreground: Theme.of(context).colorScheme.onErrorContainer,
                            icon: Icons.gpp_maybe_outlined,
                            emoji: '⛔',
                          );
                        }
                        if (session.level == CloudSessionLevel.offlineProlonged) {
                          return _sessionBanner(
                            context,
                            message: session.userMessage,
                            background: Theme.of(context).colorScheme.tertiaryContainer,
                            foreground: Theme.of(context).colorScheme.onTertiaryContainer,
                            icon: Icons.cloud_off_outlined,
                            emoji: '🟠',
                          );
                        }

                        _handleSyncedVisibility(status);

                        if (status == CloudLinkStatus.connected &&
                            (!widget.showWhenSynced || _syncedDismissed)) {
                          return const SizedBox.shrink();
                        }

                        final message = SyncDisplayMessage.dedupe(sync.blockReason) ??
                            _messageForStatus(status);
                        final foreground = _foregroundForStatus(context, status);

                        return _sessionBanner(
                          context,
                          message: message,
                          background: _backgroundForStatus(context, status),
                          foreground: foreground,
                          icon: _iconForStatus(status),
                          emoji: status.emoji,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _retryCloudRepair(BuildContext context) async {
    final repair = sl<CloudSessionRepairService>();
    final outcome = await repair.repair(attemptRefresh: true);
    if (!context.mounted) return;

    if (outcome == CloudRepairOutcome.alreadyValid ||
        outcome == CloudRepairOutcome.refreshed ||
        outcome == CloudRepairOutcome.pinLogin) {
      sl<CloudSessionCoordinator>().markCloudSessionValid();
      repair.clearAwaitingState();
      unawaited(sl<CloudSessionController>().refresh());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProductionMessagePolicy.cloudConnectionRestoredMessage()),
        ),
      );
      return;
    }

    if (outcome == CloudRepairOutcome.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion internet requise pour rétablir la session.'),
        ),
      );
    }
  }

  Widget _sessionBanner(
    BuildContext context, {
    required String message,
    required Color background,
    required Color foreground,
    required IconData icon,
    required String emoji,
    List<Widget>? actions,
  }) {
    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$emoji $message',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                  ),
                ),
              ],
            ),
            if (actions != null && actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
