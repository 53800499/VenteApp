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

  static final _technicalExceptionPatterns = [
    RegExp(r'DioException\s*(\[[^\]]*\])?:?', caseSensitive: false),
    RegExp(r'The request returned an invalid status code of \d+\.?', caseSensitive: false),
    RegExp(r'status code:?\s*\[?\d+\]?', caseSensitive: false),
    RegExp(r'DioExceptionType\.\w+', caseSensitive: false),
    RegExp(r'(Socket|Http|Format|Platform|Handshake|Tls|Sqlite)Exception:?', caseSensitive: false),
    RegExp(r'#\d+\s+.*?(?=(\n|$))'),
    RegExp(r'package:\S+'),
    RegExp(r'<[^>]*>'),
  ];

  /// Détecte si un message contient du jargon technique ou des traces d'exceptions.
  static bool isTechnicalMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('dioexception') ||
        lower.contains('bad response') ||
        lower.contains('this exception was thrown') ||
        lower.contains('requestoptions') ||
        lower.contains('validatestatus') ||
        lower.contains('status code of') ||
        lower.contains('invalid status code') ||
        lower.contains('socketexception') ||
        lower.contains('httpexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('tlsexception') ||
        lower.contains('certificateexception') ||
        lower.contains('os error') ||
        lower.contains('errno =') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('formatexception') ||
        lower.contains('unhandled exception') ||
        lower.contains('null check operator') ||
        lower.contains('nosuchmethoderror') ||
        lower.contains('lateinitializationerror') ||
        lower.contains('stacktrace') ||
        lower.contains('package:') ||
        lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('forbidden resource');
  }

  /// Traduit une erreur technique brute en message utilisateur français, clair et rassurant.
  static String humanizeTechnicalError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('action non autorisée')) {
      return 'Cette action n’est pas autorisée ou n’est pas incluse dans votre forfait actuel.';
    }
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('jwt') ||
        lower.contains('token')) {
      return 'Votre session a expiré. Veuillez vous reconnecter avec votre code PIN.';
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return 'Élément introuvable sur le service en ligne.';
    }
    if (lower.contains('409') ||
        lower.contains('conflict') ||
        lower.contains('duplicate')) {
      return 'Cette information existe déjà sur le cloud ou entre en conflit.';
    }
    if (lower.contains('422') || lower.contains('unprocessable')) {
      return 'Informations incorrectes. Vérifiez votre saisie.';
    }
    if (lower.contains('429') || lower.contains('too many requests')) {
      return 'Trop de tentatives rapprochées. Patientez un instant avant de réessayer.';
    }
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('bad gateway') ||
        lower.contains('internal server')) {
      return 'Le service en ligne rencontre une indisponibilité momentanée. Vos données locales restent en sécurité.';
    }
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('time out')) {
      return 'Le service met trop de temps à répondre. Vérifiez votre connexion internet.';
    }
    if (lower.contains('socket') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection error') ||
        lower.contains('network') ||
        lower.contains('os error') ||
        lower.contains('errno')) {
      return 'Impossible de contacter le service en ligne. Vérifiez votre connexion internet.';
    }
    return 'Une anomalie temporaire est survenue. Vos données locales restent en sécurité.';
  }

  /// Retire URL, hôtes, jargon technique (DioException, codes HTTP bruts, stack trace)
  /// et garantit un message propre, rassurant et compréhensible pour l'utilisateur en production.
  static String sanitize(String message) {
    if (message.trim().isEmpty) {
      return 'Une anomalie temporaire est survenue. Veuillez réessayer.';
    }

    final lowerOriginal = message.toLowerCase();

    // 1. Chercher d'abord s'il y a une explication métier intelligible avant DioException ou une trace technique
    final dioIdx = lowerOriginal.indexOf('dioexception');
    if (dioIdx > 0) {
      final prefix = message
          .substring(0, dioIdx)
          .trim()
          .replaceAll(RegExp(r'[\.\:\;\,\-]+$'), '')
          .trim();
      if (!isTechnicalMessage(prefix) && prefix.length >= 10) {
        if (prefix.length >= 30) {
          return '$prefix.';
        }
        return '$prefix : ${humanizeTechnicalError(message)}';
      }
    }

    var text = message;

    // 2. Suppression des URLs, hôtes, IPs et traces de navigation internes
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

    // 3. Suppression des stack traces (#0 ... .dart) et packages
    text = text.replaceAll(RegExp(r'#\d+\s+[^\n]*'), '');
    text = text.replaceAll(RegExp(r'package:\S+'), '');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // 4. Nettoyage des exceptions techniques Dart / Dio / SQL résiduelles
    for (final pattern in _technicalExceptionPatterns) {
      text = text.replaceAll(pattern, '');
    }

    // 5. Nettoyage des parenthèses/crochets vides et espaces multiples
    text = text.replaceAll(RegExp(r'\[\s*\]'), '');
    text = text.replaceAll(RegExp(r'\(\s*\)'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.replaceAll(RegExp(r'\.\s*\.'), '.');
    text = text.replaceAll(RegExp(r'[\:\,\-]\s*$'), '');
    text = text.trim();

    // 6. Si le texte résultant est vide ou n'est que de la ponctuation résiduelle
    if (text.isEmpty || RegExp(r'^[\s\.\:\,\;\-\_\[\]\(\)]+$').hasMatch(text)) {
      return humanizeTechnicalError(message);
    }

    // 7. Si le texte restant est encore un message d'erreur purement technique
    if (isTechnicalMessage(text)) {
      final colonIdx = text.indexOf(':');
      if (colonIdx > 0) {
        final prefix = text.substring(0, colonIdx).trim();
        if (!isTechnicalMessage(prefix) && prefix.length >= 5 && prefix.length < 80) {
          return '$prefix : ${humanizeTechnicalError(text)}';
        }
      }
      return humanizeTechnicalError(text);
    }

    return text;
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
      'Connexion cloud requise. Cliquez sur la bannière cloud '
      'pour rétablir la synchronisation.';

  static String onlineRequiredMessage() =>
      'Connexion au service en ligne requise.';
}
