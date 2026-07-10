import '../security/production_message_policy.dart';

/// Traduit les messages techniques API (class-validator, NestJS…) en français clair.
String humanizeApiErrorMessage(String raw) {
  final message = raw.trim();
  if (message.isEmpty) {
    return 'Une erreur est survenue. Réessayez.';
  }

  final lower = message.toLowerCase();

  final limitLess = RegExp(
    r'^limit must not be less than (\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (limitLess != null) {
    return 'Nombre d\'éléments invalide (minimum ${limitLess.group(1)}).';
  }

  final propertyRejected = RegExp(
    r'property\s+(\w+)\s+should not exist',
    caseSensitive: false,
  ).firstMatch(message);
  if (propertyRejected != null) {
    return 'Paramètre « ${propertyRejected.group(1)} » non accepté par le serveur.';
  }

  final limitGreater = RegExp(
    r'^limit must not be greater than (\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (limitGreater != null) {
    return 'Trop d\'éléments demandés (maximum ${limitGreater.group(1)}).';
  }

  if (lower.contains('limit') && lower.contains('must not')) {
    if (lower.contains('less')) {
      return 'Nombre d\'éléments demandé trop petit.';
    }
    if (lower.contains('greater')) {
      return 'Trop d\'éléments demandés au serveur.';
    }
  }

  final pageLess = RegExp(
    r'^page must not be less than (\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (pageLess != null) {
    return 'Numéro de page invalide (minimum ${pageLess.group(1)}).';
  }

  final countLess = RegExp(
    r'^count must not be less than (\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (countLess != null) {
    return 'Quantité invalide (minimum ${countLess.group(1)}).';
  }

  final countGreater = RegExp(
    r'^count must not be greater than (\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (countGreater != null) {
    return 'Quantité trop élevée (maximum ${countGreater.group(1)}).';
  }

  if (lower == 'données invalides.' || lower == 'donnees invalides.') {
    return 'Données invalides. Vérifiez votre saisie.';
  }

  if (lower.contains('bad request') || lower == 'bad_request') {
    return 'Requête refusée par le serveur. Vérifiez les informations saisies.';
  }

  if (lower.contains('forbidden') && !lower.contains(' ')) {
    return 'Action non autorisée.';
  }

  if (lower.contains('unauthorized') && !lower.contains(' ')) {
    return 'Session expirée. Reconnectez-vous avec votre PIN.';
  }

  if (lower.contains('not found') && message.length < 40) {
    return 'Élément introuvable sur le serveur.';
  }

  if (lower.startsWith('must be') || lower.contains(' must be ')) {
    return 'Certaines informations saisies ne sont pas valides.';
  }

  if (lower.contains('should not be empty') ||
      lower.contains('must not be empty')) {
    return 'Un champ obligatoire est vide.';
  }

  if (lower.contains('must be a number') ||
      lower.contains('must be an integer')) {
    return 'Un nombre est attendu à la place du texte saisi.';
  }

  if (RegExp(r'must not be longer than \d+', caseSensitive: false)
      .hasMatch(lower)) {
    return 'Texte trop long. Raccourcissez la saisie.';
  }

  if (RegExp(r'must be longer than or equal to \d+', caseSensitive: false)
          .hasMatch(lower) ||
      RegExp(r'must not be shorter than \d+', caseSensitive: false)
          .hasMatch(lower)) {
    return 'Texte trop court. Complétez la saisie.';
  }

  if (RegExp(r'^[a-z_]+ must ', caseSensitive: false).hasMatch(lower) &&
      !message.contains(' ')) {
    return 'Données invalides. Vérifiez votre saisie.';
  }

  return ProductionMessagePolicy.sanitize(message);
}
