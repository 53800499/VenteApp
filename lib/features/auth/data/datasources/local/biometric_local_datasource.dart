import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import '../../../../../core/errors/failures.dart';

class BiometricLocalDatasource {
  BiometricLocalDatasource(this._localAuth);

  final LocalAuthentication _localAuth;

  Future<bool> canCheckBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final types = await _localAuth.getAvailableBiometrics();
      return types.isNotEmpty || await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final canUse = await canCheckBiometrics();
      if (!canUse) {
        throw const UnauthorizedFailure(
          'Aucune empreinte enregistrée sur cet appareil. '
          'Ajoutez-en une dans les réglages du téléphone.',
        );
      }

      return await _localAuth.authenticate(
        localizedReason: 'Déverrouillez VenteApp avec votre empreinte',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'VenteApp',
            biometricHint: 'Posez votre doigt sur le capteur',
            biometricNotRecognized: 'Empreinte non reconnue',
            biometricRequiredTitle: 'Empreinte requise',
            cancelButton: 'Annuler',
          ),
          IOSAuthMessages(
            cancelButton: 'Annuler',
            goToSettingsButton: 'Réglages',
            goToSettingsDescription:
                'Configurez une empreinte dans les réglages du téléphone.',
            lockOut: 'Biométrie verrouillée. Réessayez plus tard.',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on UnauthorizedFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw UnauthorizedFailure(_platformErrorMessage(error));
    } catch (_) {
      return false;
    }
  }

  String _platformErrorMessage(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code.contains('notenrolled') || code.contains('not_enrolled')) {
      return 'Aucune empreinte enregistrée sur cet appareil. '
          'Ajoutez-en une dans les réglages du téléphone.';
    }
    if (code.contains('no_fragment_activity')) {
      return 'Configuration biométrique incorrecte. '
          'Réinstallez ou mettez à jour l\'application.';
    }
    if (code.contains('lockedout') || code.contains('locked_out')) {
      return 'Trop de tentatives biométriques. '
          'Réessayez plus tard ou utilisez votre code PIN.';
    }
    if (code.contains('passcodenotset') || code.contains('passcode_not_set')) {
      return 'Aucun code de verrouillage sur le téléphone. '
          'Configurez un verrouillage d\'écran dans les réglages.';
    }
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'Empreinte non reconnue. Utilisez votre code PIN.';
  }
}
