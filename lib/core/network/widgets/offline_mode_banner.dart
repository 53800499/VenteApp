import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../app/di/injection_container.dart';
import '../../../app/theme/app_tokens.dart';
import '../../auth/cloud_link_status.dart';
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
      'Hors ligne — données affichées depuis le cache. '
      'Les modifications nécessitent le serveur.';

  /// Statistiques / rapports basés sur les données locales.
  static const hybridReadMessage =
      'Hors ligne — statistiques basées sur les données locales.';

  @override
  State<OfflineModeBanner> createState() => _OfflineModeBannerState();
}

class _OfflineModeBannerState extends State<OfflineModeBanner> {
  bool? _offline;

  @override
  void initState() {
    super.initState();
    sl<NetworkInfo>().isConnected.then((connected) {
      if (mounted) setState(() => _offline = !connected);
    });
  }

  String _messageForStatus(CloudLinkStatus status) {
    if (widget.onlinePreferredMessage != null &&
        status == CloudLinkStatus.disconnected) {
      return widget.onlinePreferredMessage!;
    }

    return switch (status) {
      CloudLinkStatus.connected =>
        'Synchronisé — vos données sont à jour sur le cloud.',
      CloudLinkStatus.disconnected =>
        'Hors ligne — les ventes continuent, synchronisation à la reconnexion.',
      CloudLinkStatus.syncing =>
        'Synchronisation en cours — vos modifications seront envoyées.',
      CloudLinkStatus.syncError =>
        'Problème de synchronisation — vérifiez votre connexion.',
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
            final sync = syncSnapshot.data ?? const SyncSnapshot.idle();
            final status = resolveCloudLinkStatus(
              isConnected: offline != true,
              sync: sync,
            );

            if (status == CloudLinkStatus.connected && !widget.showWhenSynced) {
              return const SizedBox.shrink();
            }

            final message = _messageForStatus(status);
            final foreground = _foregroundForStatus(context, status);

            return Material(
              color: _backgroundForStatus(context, status),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconForStatus(status),
                      size: 18,
                      color: foreground,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${status.emoji} $message',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: foreground,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
