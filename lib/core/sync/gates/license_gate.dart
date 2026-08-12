import '../../database/app_database.dart';

/// Statuts de politique d'abonnement / licence marchand.
enum MerchantLicenseStatus {
  active,
  grace,
  expired,
  suspended,
}

/// Décision rendue par la LicenseGate pour un élément de synchronisation.
enum LicenseGateDecision {
  /// Synchronisation autorisée.
  allow,

  /// Synchronisation suspendue/bloquée par la politique serveur (Licence expirée/suspendue).
  /// L'élément passera au statut `blocked` dans la file `sync_queue`.
  blockPolicy,

  /// PULL uniquement autorisé (lecture seule).
  readOnly,
}

/// Porte de contrôle de licence et d'abonnement pour le moteur de synchronisation ARIKE.
class LicenseGate {
  const LicenseGate();

  /// Évalue si la synchronisation d'un élément est autorisée selon le statut de l'abonnement.
  LicenseGateDecision evaluate({
    required String statusString,
    required String domain,
    required bool isPushOperation,
  }) {
    final status = _parseStatus(statusString);

    switch (status) {
      case MerchantLicenseStatus.active:
        return LicenseGateDecision.allow;

      case MerchantLicenseStatus.grace:
        // Pendant la période de grâce, le Push reste autorisé pour les ventes et la caisse
        if (domain == 'SALES' || domain == 'CASH') {
          return LicenseGateDecision.allow;
        }
        return isPushOperation ? LicenseGateDecision.blockPolicy : LicenseGateDecision.readOnly;

      case MerchantLicenseStatus.expired:
        // En cas d'expiration, les Push sont bloqués mais les Pulls/lectures restent permises
        return isPushOperation ? LicenseGateDecision.blockPolicy : LicenseGateDecision.readOnly;

      case MerchantLicenseStatus.suspended:
        // Abonnement suspendu ou révoqué : Bloquer tout Push cloud
        return isPushOperation ? LicenseGateDecision.blockPolicy : LicenseGateDecision.readOnly;
    }
  }

  MerchantLicenseStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'TRIAL':
        return MerchantLicenseStatus.active;
      case 'GRACE':
      case 'PENDING_ACTIVATION':
        return MerchantLicenseStatus.grace;
      case 'EXPIRED':
        return MerchantLicenseStatus.expired;
      case 'SUSPENDED':
      case 'REVOKED':
      default:
        return MerchantLicenseStatus.suspended;
    }
  }
}
