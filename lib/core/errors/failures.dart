import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

class CashSessionRequiredFailure extends Failure {
  const CashSessionRequiredFailure([
    super.message = 'Ouvrez la caisse avant d\'enregistrer une vente.',
  ]);
}

/// Conflit d'installation avec erreurs par champ (doublons formulaire ou serveur).
class SetupFieldConflictFailure extends ConflictFailure {
  const SetupFieldConflictFailure({
    required String message,
    required this.fieldErrors,
  }) : super(message);

  /// Clés : ownerName, ownerPhone, shopName, shopPhone, …
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
}

class InvalidPinFailure extends Failure {
  const InvalidPinFailure(this.remainingAttempts)
      : super('Code incorrect. $remainingAttempts tentatives restantes.');

  final int remainingAttempts;
}

class AccountLockedFailure extends Failure {
  AccountLockedFailure({
    required this.lockedUntil,
    required this.remainingSeconds,
  }) : super(_formatMessage(remainingSeconds));

  final int lockedUntil;
  final int remainingSeconds;

  static String _formatMessage(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return 'Compte verrouillé. Réessayez dans ${minutes}min ${secs}s.';
    }
    return 'Compte verrouillé. Réessayez dans ${secs}s.';
  }
}

class EmergencyRecoveryRequiredFailure extends Failure {
  const EmergencyRecoveryRequiredFailure()
      : super('Déblocage impossible. Utilisez le fichier de récupération d\'urgence.');
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class OfflineGraceExpiredFailure extends Failure {
  const OfflineGraceExpiredFailure()
      : super(
          'Votre accès hors ligne a expiré. Connectez-vous à internet pour vous reconnecter.',
        );
}

/// Session cloud expirée sans preuve PIN récente en mémoire.
class CloudReconnectRequiredFailure extends Failure {
  const CloudReconnectRequiredFailure([
    super.message =
        'Connexion au serveur requise. Saisissez votre PIN via la bannière '
        'pour rétablir la synchronisation.',
  ]);
}
