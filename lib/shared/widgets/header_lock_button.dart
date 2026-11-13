import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/di/injection_container.dart';
import '../../core/auth/cloud_session_controller.dart';
import '../../core/auth/cloud_session_repair_service.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_snapshot.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Bouton Cadenas d'en-tête :
/// - Icône cadenas d'origine (`Icons.lock_outline_rounded`).
/// - Gris discret en mode nominal pour verrouiller la session manuellement.
/// - Rouge d'alerte UNIQUEMENT en cas d'action d'authentification/session requise
///   (ex: session révoquée ou jeton invalide nécessitant une réauthentification PIN).
///   Une simple indisponibilité réseau (offline / attente) ne fait PAS rougir le cadenas :
///   elle est gérée de façon non intrusive par SyncStatusIndicator.
/// - Au clic : verrouille vers la page de PIN en plein écran (LockScreenPage).
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

    final listenables = <Listenable>[
      repair.awaitingPinUnlockNotifier,
      if (cloudSession != null) cloudSession.notifier,
    ];

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        return StreamBuilder<SyncSnapshot>(
          stream: syncService.snapshots,
          initialData: syncService.currentSnapshot,
          builder: (context, snapshot) {
            final sync = snapshot.data ?? const SyncSnapshot.idle();

            final isServerReconnectRequired = repair.isCloudReconnectRequired(
              syncBlockReason: sync.blockReason,
              sessionLevel: cloudSession?.status.level,
            );

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

              const tooltip = 'Reconnexion au serveur requise — Touchez le cadenas et entrez votre code PIN';

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
