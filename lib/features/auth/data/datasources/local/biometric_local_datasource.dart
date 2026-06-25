import 'package:local_auth/local_auth.dart';

class BiometricLocalDatasource {
  BiometricLocalDatasource(this._localAuth);

  final LocalAuthentication _localAuth;

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Déverrouillez VenteApp avec votre empreinte',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
