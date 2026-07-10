import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/local/biometric_local_datasource.dart';
import '../../../../core/errors/failures.dart';

class IsSetupComplete {
  const IsSetupComplete(this._repository);

  final AuthRepository _repository;

  Future<bool> call() => _repository.isSetupComplete();
}

class WasLoggedOut {
  const WasLoggedOut(this._repository);

  final AuthRepository _repository;

  Future<bool> call() => _repository.wasLoggedOut();
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
      throw const UnauthorizedFailure(
        'Aucune empreinte enregistrée sur cet appareil. '
        'Ajoutez-en une dans les réglages du téléphone.',
      );
    }

    final authenticated = await _biometricDatasource.authenticate();
    if (!authenticated) {
      throw const UnauthorizedFailure(
        'Empreinte non reconnue. Utilisez votre code PIN.',
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
    required String ownerPhone,
    String? shopAddress,
    String? shopPhone,
  }) =>
      _repository.setupOwner(
        ownerName: ownerName,
        shopName: shopName,
        pin: pin,
        ownerPhone: ownerPhone,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
      );
}

class RequestWhatsappOtp {
  const RequestWhatsappOtp(this._repository);

  final AuthRepository _repository;

  Future<WhatsappOtpRequestResult> call({required String phone}) =>
      _repository.requestWhatsappOtp(phone: phone);
}

class VerifyWhatsappOtp {
  const VerifyWhatsappOtp(this._repository);

  final AuthRepository _repository;

  Future<WhatsappOtpVerifyResult> call({
    required String phone,
    required String code,
  }) =>
      _repository.verifyWhatsappOtp(phone: phone, code: code);
}

class CompleteWhatsappLogin {
  const CompleteWhatsappLogin(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String verificationToken,
    required int shopId,
    required int userId,
  }) =>
      _repository.completeWhatsappLogin(
        verificationToken: verificationToken,
        shopId: shopId,
        userId: userId,
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

class EmergencyUnlockWithWhatsappOtp {
  const EmergencyUnlockWithWhatsappOtp(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String phone,
    required String code,
    int shopId = 1,
    int? userId,
  }) =>
      _repository.emergencyUnlockWithWhatsappOtp(
        phone: phone,
        code: code,
        shopId: shopId,
        userId: userId,
      );
}

class ResetPinWithWhatsappOtp {
  const ResetPinWithWhatsappOtp(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String verificationToken,
    required int serverShopId,
    required int serverUserId,
    required String newPin,
  }) =>
      _repository.resetPinWithWhatsappOtp(
        verificationToken: verificationToken,
        serverShopId: serverShopId,
        serverUserId: serverUserId,
        newPin: newPin,
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

class DisableBiometric {
  const DisableBiometric(this._repository);

  final AuthRepository _repository;

  Future<bool> call({
    required int userId,
    required String sessionToken,
    required String pin,
  }) =>
      _repository.disableBiometric(
        userId: userId,
        sessionToken: sessionToken,
        pin: pin,
      );
}

class ChangeUserPin {
  const ChangeUserPin(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required AuthSession session,
    required String currentPin,
    required String newPin,
  }) {
    return _repository.changePin(
      userId: session.user.id,
      shopId: session.shop.id,
      currentPin: currentPin,
      newPin: newPin,
    );
  }
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

class HasRestorableSession {
  const HasRestorableSession(this._repository);

  final AuthRepository _repository;

  Future<bool> call() => _repository.hasRestorableSession();
}

class UnlockWithPin {
  const UnlockWithPin(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String pin,
    int shopId = 1,
    int? userId,
  }) =>
      _repository.unlockWithPin(pin: pin, shopId: shopId, userId: userId);
}

class UnlockWithBiometric {
  const UnlockWithBiometric(this._repository, this._biometricDatasource);

  final AuthRepository _repository;
  final BiometricLocalDatasource _biometricDatasource;

  Future<AuthSession> call({
    int shopId = 1,
    int? userId,
  }) async {
    final canUse = await _biometricDatasource.canCheckBiometrics();
    if (!canUse) {
      throw const UnauthorizedFailure(
        'Aucune empreinte enregistrée sur cet appareil. '
        'Ajoutez-en une dans les réglages du téléphone.',
      );
    }

    final authenticated = await _biometricDatasource.authenticate();
    if (!authenticated) {
      throw const UnauthorizedFailure(
        'Empreinte non reconnue. Utilisez votre code PIN.',
      );
    }

    return _repository.unlockWithBiometric(shopId: shopId, userId: userId);
  }
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

class ListDeviceSessions {
  const ListDeviceSessions(this._repository);

  final AuthRepository _repository;

  Future<List<DeviceSession>> call({bool shopScope = false}) =>
      _repository.listDeviceSessions(shopScope: shopScope);
}

class RevokeDeviceSession {
  const RevokeDeviceSession(this._repository);

  final AuthRepository _repository;

  Future<void> call(String sessionId) =>
      _repository.revokeDeviceSession(sessionId);
}

class VerifyShopOwnerPin {
  const VerifyShopOwnerPin(this._repository);

  final AuthRepository _repository;

  Future<void> call({required int shopId, required String pin}) =>
      _repository.verifyShopOwnerPin(shopId: shopId, pin: pin);
}
