import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../app/di/injection_container.dart';
import '../../../app/theme/app_tokens.dart';
import '../network_info.dart';

/// Bandeau discret quand l'appareil est hors ligne.
class OfflineModeBanner extends StatefulWidget {
  const OfflineModeBanner({
    super.key,
    this.onlinePreferredMessage,
  });

  /// Message alternatif sur les écrans admin (Paramètres, Équipe…).
  final String? onlinePreferredMessage;

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final offline = snapshot.hasData
            ? snapshot.data!.every((r) => r == ConnectivityResult.none)
            : _offline;
        if (offline != true) return const SizedBox.shrink();

        final message = widget.onlinePreferredMessage ??
            'Hors ligne — les ventes continuent, synchronisation à la reconnexion.';

        return Material(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
