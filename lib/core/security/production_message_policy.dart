import 'package:flutter/foundation.dart';

/// Masque les détails d'infrastructure (URL, hôte, IP) dans l'UI et les messages.
abstract final class ProductionMessagePolicy {
  /// Écran de configuration manuelle du backend — réservé au mode debug.
  static bool get showServerConfiguration => kDebugMode;

  static final _urlPattern = RegExp(r'https?://\S+', caseSensitive: false);
  static final _hostPattern = RegExp(
    r'\b[\w.-]+\.(onrender|com|net|io|app|local)\S*\b',
    caseSensitive: false,
  );
  static final _ipPattern = RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b');
  static final _connexionServeurMenu = RegExp(
    r'Plus\s*→\s*Connexion serveur\.?',
    caseSensitive: false,
  );

  /// Retire URL, hôtes et chemins de configuration des messages utilisateur.
  static String sanitize(String message) {
    var text = message;
    text = text.replaceAll(_urlPattern, '');
    text = text.replaceAll(_hostPattern, '');
    text = text.replaceAll(_ipPattern, '');
    text = text.replaceAll(_connexionServeurMenu, '');
    text = text.replaceAll(
      RegExp(
        r"l['']adresse (du serveur|dans Plus)[^.]*\.?",
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(RegExp(r'\(\s*\)'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.replaceAll(RegExp(r'\.\s*\.'), '.');
    return text.trim();
  }

  static String networkUnreachableHint({bool localDevelopmentContext = false}) {
    if (localDevelopmentContext && kDebugMode) {
      return ' Assurez-vous que le backend de développement est lancé sur '
          'votre ordinateur, puis réessayez.';
    }
    return ' Vérifiez votre connexion internet et réessayez.';
  }

  static String networkUnreachableMessage({
    bool localDevelopmentContext = false,
  }) =>
      'Impossible de se connecter au service en ligne.'
      '${networkUnreachableHint(localDevelopmentContext: localDevelopmentContext)}';

  static String internetRequiredMessage() =>
      'Connexion internet requise. Vérifiez le réseau et réessayez.';

  static String onlineWriteRequiredMessage(String scope) =>
      'Connexion au service en ligne requise pour $scope. '
      'Vérifiez le réseau et réessayez.';

  static String onlineActionRequiredMessage() =>
      'Connexion au service en ligne requise pour cette action. '
      'Vérifiez le réseau et réessayez.';

  static String onlinePinTimeoutMessage() =>
      'Le service met trop de temps à répondre. '
      'Vérifiez la connexion internet et réessayez.';

  static String activateCloudInstruction() =>
      'Connectez-vous via WhatsApp pour activer la synchronisation cloud.';

  static String activateCloudShortInstruction() =>
      'Connectez-vous via WhatsApp pour activer le cloud.';

  static String cloudSessionExpiredMessage() =>
      'Session cloud expirée. Votre PIN local reste valide — '
      'réessayez. La synchro reprendra après ouverture.';

  static String cloudConnectionRestoredMessage() =>
      'Connexion cloud rétablie.';

  static String cloudSessionRepairTitle() => 'Rétablir la session cloud';

  static String cloudSessionRepairOfflineMessage() =>
      'Connexion internet requise pour rétablir la session cloud.';

  static String cloudSessionRepairFailedMessage() =>
      'Impossible de rétablir la session cloud. Vérifiez votre code PIN '
      'ou utilisez la bannière de synchronisation.';

  static String cloudReconnectRequiredMessage() =>
      'Connexion cloud requise. Saisissez votre PIN via la bannière '
      'pour rétablir la synchronisation.';

  static String onlineRequiredMessage() =>
      'Connexion au service en ligne requise.';
}
