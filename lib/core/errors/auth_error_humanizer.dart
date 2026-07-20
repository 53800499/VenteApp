import '../security/production_message_policy.dart';
import 'api_error_humanizer.dart';

/// Messages d'erreur lisibles pour le module authentification (installation, PIN, WhatsApp).
String humanizeAuthErrorMessage(String raw) {
  return ProductionMessagePolicy.sanitize(_humanizeAuthErrorMessage(raw));
}

String _humanizeAuthErrorMessage(String raw) {
  final message = raw.trim();
  if (message.isEmpty) {
    return 'Une erreur est survenue. Réessayez.';
  }

  final lower = message.toLowerCase();

  if (_isDuplicateKeyError(lower)) {
    return _humanizeDuplicateKey(lower);
  }

  if (lower.contains('row-level security') ||
      lower.contains('violates row-level security')) {
    return 'Création refusée par le service en ligne. Réessayez plus tard.';
  }

  if (lower.contains('invalid phone') ||
      lower.contains('numéro invalide') ||
      lower.contains('phone must')) {
    return 'Numéro WhatsApp invalide. Utilisez le format 01XXXXXXXX (10 chiffres) ou +229…';
  }

  if (lower.contains('name') &&
      (lower.contains('short') ||
          lower.contains('longer than') ||
          lower.contains('minlength'))) {
    return 'Le nom doit contenir au moins 2 caractères.';
  }

  if (lower.contains('jwt') && lower.contains('expired')) {
    return 'Session expirée. Recommencez la connexion WhatsApp.';
  }

  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection refused')) {
    return ProductionMessagePolicy.networkUnreachableMessage();
  }

  return humanizeApiErrorMessage(message);
}

bool _isDuplicateKeyError(String lower) {
  return lower.contains('duplicate key') ||
      lower.contains('unique constraint') ||
      lower.contains('23505') ||
      lower.contains('unique constraint failed');
}

String _humanizeDuplicateKey(String lower) {
  return classifySetupDuplicateMessage(lower).summary;
}

/// Associe un message technique duplicate key aux champs du formulaire d'installation.
({String summary, Map<String, String> fieldErrors}) classifySetupDuplicateMessage(
  String raw,
) {
  final lower = raw.toLowerCase();
  final fields = <String, String>{};

  if (lower.contains('users_name') ||
      lower.contains('name_shop') ||
      (lower.contains('users') && lower.contains('name'))) {
    const message =
        'Ce nom de patron existe déjà pour cette boutique. Choisissez un autre nom.';
    fields['ownerName'] = message;
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('settings_shop_id') || lower.contains('settings.shop_id')) {
    const message =
        'Les paramètres de cette boutique existent déjà. Connectez-vous avec WhatsApp.';
    fields['shopName'] = message;
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('settings_pkey')) {
    const message =
        'Erreur lors de l\'enregistrement des paramètres. '
        'Si l\'installation a déjà réussi, utilisez « Se connecter avec WhatsApp ».';
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('phone')) {
    const message =
        'Ce numéro WhatsApp est déjà utilisé. Modifiez-le ou connectez-vous avec WhatsApp.';
    fields['ownerPhone'] = message;
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('shops') || lower.contains('server_id')) {
    const message =
        'Cette boutique existe déjà sur le cloud. Connectez-vous avec WhatsApp.';
    fields['shopName'] = message;
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('stock_transfers_reference') ||
      (lower.contains('stock_transfers') && lower.contains('reference'))) {
    const message =
        'Cette référence de transfert existe déjà sur le serveur. '
        'Synchronisez à nouveau ou créez le transfert avec une autre référence.';
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('supplier_invoices') ||
      lower.contains('invoice_number')) {
    const message =
        'Ce numéro de facture fournisseur existe déjà sur le serveur. '
        'Modifiez le numéro ou synchronisez à nouveau.';
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('purchase_receipts') ||
      lower.contains('receipt_number')) {
    const message =
        'Ce numéro de bon de réception existe déjà sur le serveur. '
        'Utilisez un autre numéro ou synchronisez à nouveau.';
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('supplier_payments')) {
    const message =
        'Ce paiement fournisseur existe déjà sur le serveur. '
        'Synchronisez à nouveau pour réconcilier les données.';
    return (summary: message, fieldErrors: fields);
  }

  if (lower.contains('purchase_orders') &&
      (lower.contains('number') || lower.contains('unique'))) {
    const message =
        'Ce numéro de commande existe déjà sur le serveur. '
        'Utilisez un autre numéro ou synchronisez à nouveau.';
    return (summary: message, fieldErrors: fields);
  }

  const summary =
      'Certaines informations existent déjà. Modifiez les champs signalés ou connectez-vous avec WhatsApp.';
  return (summary: summary, fieldErrors: fields);
}

/// Applique l'humanisation à toute erreur auth (Failure, Dio, SQLite, etc.).
String friendlyAuthErrorMessage(Object error) {
  if (error is Exception) {
    final text = error.toString();
    if (text.contains(':')) {
      return humanizeAuthErrorMessage(text.split(':').last.trim());
    }
  }
  return humanizeAuthErrorMessage(error.toString());
}
