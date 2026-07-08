import 'package:flutter/material.dart';

import '../../../app/di/injection_container.dart';
import '../cloud_session_controller.dart';
import '../cloud_session_status.dart';

/// Avis de démarrage sur l'ancienneté de la session cloud (politique 3 niveaux).
///
/// - Niveau 2 (prolongé) : informatif, non bloquant.
/// - Niveau 3 (limite atteinte) : accusé de réception obligatoire.
///
/// Ne s'affiche qu'une seule fois par session applicative.
Future<void> maybeShowCloudSessionStartupNotice(BuildContext context) async {
  final controller = sl<CloudSessionController>();
  if (!controller.shouldShowStartupNotice) return;

  final status = controller.status;
  controller.markStartupNoticeShown();

  final isBlockingLevel = status.level == CloudSessionLevel.actionRequired;

  await showDialog<void>(
    context: context,
    barrierDismissible: !isBlockingLevel,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(
          isBlockingLevel ? Icons.gpp_maybe_outlined : Icons.cloud_off_outlined,
          color: isBlockingLevel ? scheme.error : scheme.tertiary,
        ),
        title: Text(
          isBlockingLevel
              ? 'Vérification cloud requise'
              : 'Connexion cloud ancienne',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status.userMessage),
            if (isBlockingLevel) ...[
              const SizedBox(height: 12),
              Text(
                'Vous pouvez continuer à vendre et travailler hors ligne. '
                'Reconnectez-vous dès que possible pour resynchroniser et '
                'rétablir les opérations sensibles (équipe, paramètres, '
                'changement de boutique, sauvegarde).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isBlockingLevel ? "J'ai compris" : 'Continuer'),
          ),
        ],
      );
    },
  );
}
