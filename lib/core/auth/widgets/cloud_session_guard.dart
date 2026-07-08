import 'package:flutter/material.dart';

import '../../../app/di/injection_container.dart';
import '../cloud_session_controller.dart';

/// Garde des opérations « à confiance serveur ».
///
/// Au Niveau 3 (>7 jours sans validation cloud), certaines opérations sensibles
/// (gestion d'équipe/droits, paramètres sensibles, changement de boutique,
/// sauvegarde/restauration) sont temporairement indisponibles jusqu'à un
/// nouveau contact serveur. Le cœur métier (ventes, dépenses, stock) n'est
/// jamais bloqué par cette garde.
///
/// Retourne `true` si l'opération est autorisée, `false` sinon (un message
/// explicatif est alors présenté à l'utilisateur).
Future<bool> ensureCloudTrustedOperation(
  BuildContext context, {
  required String actionLabel,
}) async {
  final controller = sl<CloudSessionController>();
  if (controller.allowsTrustedServerOperations) return true;

  await showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.gpp_maybe_outlined, color: scheme.error),
        title: const Text('Vérification cloud requise'),
        content: Text(
          '« $actionLabel » nécessite une session cloud vérifiée.\n\n'
          'Votre application n\'a pas contacté le serveur depuis plus de '
          '7 jours. Connectez-vous à Internet pour synchroniser, puis '
          'réessayez. Vos ventes et opérations locales restent disponibles.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("J'ai compris"),
          ),
        ],
      );
    },
  );
  return false;
}
