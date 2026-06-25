import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/local/biometric_local_datasource.dart';
import '../../../../core/errors/failures.dart';

class IsSetupComplete {
  const IsSetupComplete(this._repository);

  final AuthRepository _repository;

  Future<bool> call() => _repository.isSetupComplete();
}

class GetLockScreen {
  const GetLockScreen(this._repository);

  final AuthRepository _repository;

  Future<LockScreenData> call({int shopId = 1}) =>
      _repository.getLockScreen(shopId: shopId);
}

class LoginWithBiometric {
  const LoginWithBiometric(this._repository, this._biometricDatasource);

  final AuthRepository _repository;
  final BiometricLocalDatasource _biometricDatasource;

  Future<AuthSession> call({
    int shopId = 1,
    int? userId,
  }) async {
    final canUse = await _biometricDatasource.canCheckBiometrics();
    if (!canUse) {
      throw const UnauthorizedFailure('Biométrie indisponible sur cet appareil.');
    }

    final authenticated = await _biometricDatasource.authenticate();
    if (!authenticated) {
      throw const UnauthorizedFailure(
        'Échec biométrique. Utilisez votre code PIN.',
      );
    }

    return _repository.loginWithBiometric(shopId: shopId, userId: userId);
  }
}

class LoginWithPin {
  const LoginWithPin(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String pin,
    int shopId = 1,
    int? userId,
  }) =>
      _repository.loginWithPin(pin: pin, shopId: shopId, userId: userId);
}

class SetupOwner {
  const SetupOwner(this._repository);

  final AuthRepository _repository;

  Future<SetupOwnerResult> call({
    required String ownerName,
    required String shopName,
    required String pin,
    String? shopAddress,
    String? shopPhone,
  }) =>
      _repository.setupOwner(
        ownerName: ownerName,
        shopName: shopName,
        pin: pin,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
      );
}

class EmergencyUnlock {
  const EmergencyUnlock(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String recoveryToken,
    int shopId = 1,
    int? userId,
  }) =>
      _repository.emergencyUnlock(
        recoveryToken: recoveryToken,
        shopId: shopId,
        userId: userId,
      );
}

class EnableBiometric {
  const EnableBiometric(this._repository);

  final AuthRepository _repository;

  Future<bool> call({
    required int userId,
    required String sessionToken,
    required String pin,
  }) =>
      _repository.enableBiometric(
        userId: userId,
        sessionToken: sessionToken,
        pin: pin,
      );
}

class TouchSession {
  const TouchSession(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String sessionToken,
    required int shopId,
  }) =>
      _repository.touchSession(sessionToken: sessionToken, shopId: shopId);
}

class RestoreSession {
  const RestoreSession(this._repository);

  final AuthRepository _repository;

  Future<AuthSession?> call() => _repository.restoreSession();
}

class Logout {
  const Logout(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}

class LockActiveSession {
  const LockActiveSession(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.lockActiveSession();
}

class ListOwnedShops {
  const ListOwnedShops(this._repository);

  final AuthRepository _repository;

  Future<OwnedShopList> call() => _repository.listOwnedShops();
}

class SwitchShop {
  const SwitchShop(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({required int shopId}) =>
      _repository.switchShop(shopId: shopId);
}
