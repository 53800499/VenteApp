import 'package:flutter/material.dart';
import '../../domain/module_access_guard.dart';

class LicenseStatusBanner extends StatelessWidget {
  final LicenseInfo licenseInfo;
  final VoidCallback? onRenewPressed;

  const LicenseStatusBanner({
    super.key,
    required this.licenseInfo,
    this.onRenewPressed,
  });

  @override
  Widget build(BuildContext me) {
    if (licenseInfo.state == LicenseState.active) {
      return const SizedBox.shrink();
    }

    final Color backgroundColor;
    final Color textColor;
    final IconData icon;
    final String message;

    switch (licenseInfo.state) {
      case LicenseState.inGracePeriod:
        backgroundColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        icon = Icons.warning_amber_rounded;
        message =
            'Période de grâce : Votre abonnement expiré. Il vous reste ${licenseInfo.remainingGraceDays} jour(s) pour le renouveler.';
        break;
      case LicenseState.restrictedReadOnly:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        icon = Icons.lock_clock_outlined;
        message =
            'Abonnement expiré (Mode Restreint) : Nouvelles ventes et modifications bloquées. Consultation & Export autorisés.';
        break;
      case LicenseState.clockTamperDetected:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.error_outline_rounded;
        message =
            'Erreur d\'horloge système détectée : Veuillez ajuster l\'heure de votre appareil ou vous connecter à Internet.';
        break;
      case LicenseState.suspended:
      case LicenseState.expired:
      default:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.block_rounded;
        message = 'Abonnement suspendu : Veuillez contacter le support ARIKE pour réactiver votre accès.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: textColor.withValues(alpha: 0.3), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRenewPressed != null &&
              (licenseInfo.state == LicenseState.inGracePeriod ||
                  licenseInfo.state == LicenseState.restrictedReadOnly)) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRenewPressed,
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: textColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Renouveler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
