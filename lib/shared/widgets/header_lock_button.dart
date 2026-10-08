import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/di/injection_container.dart';
import '../../core/auth/cloud_session_controller.dart';
import '../../core/auth/cloud_session_repair_service.dart';
import '../../core/auth/cloud_session_status.dart';
import '../../core/auth/recent_pin_proof.dart';
import '../../core/network/network_monitor.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_snapshot.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Bouton Cadenas d'en-tête :
/// - Icône cadenas d'origine (`Icons.lock_outline_rounded`).
/// - Grise si la session est active et connectée au serveur.
/// - Rouge d'alerte vif dès qu'il n'y a plus de connexion au serveur ou qu'une reconnexion PIN est requise.
/// - Au clic : verrouille vers la vraie page de PIN en plein écran (LockScreenPage)
///   pour permettre la reconnexion immédiate au serveur.
class HeaderLockButton extends StatelessWidget {
  const HeaderLockButton({
    super.key,
    this.onLock,
    this.filledTonal = false,
    this.iconSize = 22.0,
  });

  final VoidCallback? onLock;
  final bool filledTonal;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final repair = sl<CloudSessionRepairService>();
    final syncService = sl<SyncService>();
    final cloudSession = sl.isRegistered<CloudSessionController>()
        ? sl<CloudSessionController>()
        : null;
    final networkMonitor = sl.isRegistered<NetworkMonitor>()
        ? sl<NetworkMonitor>()
        : null;

    final listenables = <Listenable>[
      repair.awaitingPinUnlockNotifier,
      if (cloudSession != null) cloudSession.notifier,
      if (networkMonitor != null) networkMonitor.stateNotifier,
    ];

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final isAwaitingPin = repair.isAwaitingPinUnlock;
        return StreamBuilder<SyncSnapshot>(
          stream: syncService.snapshots,
          initialData: syncService.currentSnapshot,
          builder: (context, snapshot) {
            final sync = snapshot.data ?? const SyncSnapshot.idle();

            final isSyncBlockedBySession = sync.blockReason != null &&
                (sync.blockReason!.toLowerCase().contains('session') ||
                    sync.blockReason!.toLowerCase().contains('authentification') ||
                    sync.blockReason!.toLowerCase().contains('reconnecter') ||
                    sync.blockReason!.toLowerCase().contains('token') ||
                    sync.blockReason!.toLowerCase().contains('jeton') ||
                    sync.blockReason!.toLowerCase().contains('non autorisé') ||
                    sync.blockReason!.toLowerCase().contains('pin'));

            final sessionNeedsValidation = cloudSession != null &&
                cloudSession.status.level == CloudSessionLevel.actionRequired;

            final isServerDisconnected = (networkMonitor != null &&
                    (networkMonitor.currentState == NetworkState.offline ||
                        networkMonitor.currentState ==
                            NetworkState.localNetworkOnly)) ||
                sync.indicatorState == SyncIndicatorState.offline ||
                sync.indicatorState == SyncIndicatorState.waitingForConnection;

            final hasRecentPinProof = sl.isRegistered<RecentPinProof>() &&
                sl<RecentPinProof>().hasRecentProof;

            // Déconnexion serveur ou session expirée : la saisie du code PIN est requise pour rétablir la connexion
            // SAUF si l'utilisateur a déjà saisi son code PIN récemment en mémoire vive (la reconnexion
            // se fait automatiquement en arrière-plan dès que le serveur est joignable).
            final isServerReconnectRequired = !hasRecentPinProof &&
                (isAwaitingPin ||
                    isSyncBlockedBySession ||
                    sessionNeedsValidation ||
                    isServerDisconnected);

            void lockApp() {
              if (onLock != null) {
                onLock!();
              } else {
                try {
                  context.read<AuthBloc>().add(const AuthAppLockedRequested());
                } catch (_) {}
              }
            }

            if (isServerReconnectRequired) {
              // Action requise : Bouton Cadenas en ROUGE vif pour signaler la reconnexion nécessaire
              final redColor = Colors.red.shade700;
              final redBg = Colors.red.shade50;

              final tooltip = isServerDisconnected
                  ? 'Connexion au serveur perdue — Touchez le cadenas et entrez votre code PIN pour vous reconnecter'
                  : 'Reconnexion au serveur requise — Touchez le cadenas et entrez votre code PIN';

              if (filledTonal) {
                return IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: redBg,
                    foregroundColor: redColor,
                    side: BorderSide(
                      color: redColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  onPressed: lockApp,
                  icon: Icon(
                    Icons.lock_rounded,
                    size: iconSize,
                    color: redColor,
                  ),
                  tooltip: tooltip,
                );
              }

              return IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: redBg,
                  foregroundColor: redColor,
                ),
                onPressed: lockApp,
                icon: Badge(
                  backgroundColor: redColor,
                  smallSize: 9,
                  child: Icon(
                    Icons.lock_rounded,
                    size: iconSize,
                    color: redColor,
                  ),
                ),
                tooltip: tooltip,
              );
            }

            // Normal : Cadenas discret gris d'origine
            final greyColor = Theme.of(context).colorScheme.outline;

            if (filledTonal) {
              return IconButton.filledTonal(
                style: IconButton.styleFrom(
                  foregroundColor: greyColor,
                ),
                onPressed: lockApp,
                icon: Icon(
                  Icons.lock_outline_rounded,
                  size: iconSize,
                  color: greyColor,
                ),
                tooltip: 'Verrouiller la session',
              );
            }

            return IconButton(
              onPressed: lockApp,
              icon: Icon(
                Icons.lock_outline_rounded,
                size: iconSize,
                color: greyColor,
              ),
              tooltip: 'Verrouiller la session',
            );
          },
        );
      },
    );
  }
}
