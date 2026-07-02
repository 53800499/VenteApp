import '../entities/auth_entities.dart';

abstract class AuthRepository {
  Future<bool> isSetupComplete();

  Future<LockScreenData> getLockScreen({required int shopId});

  Future<AuthSession> loginWithPin({
    required String pin,
    required int shopId,
    int? userId,
  });

  Future<AuthSession> loginWithBiometric({
    required int shopId,
    int? userId,
  });

  Future<SetupOwnerResult> setupOwner({
    required String ownerName,
    required String shopName,
    required String pin,
    required String ownerPhone,
    String? shopAddress,
    String? shopPhone,
  });

  Future<AuthSession> emergencyUnlock({
    required String recoveryToken,
    required int shopId,
    int? userId,
  });

  Future<bool> enableBiometric({
    required int userId,
    required String sessionToken,
    required String pin,
  });

  Future<bool> disableBiometric({
    required int userId,
    required String sessionToken,
    required String pin,
  });

  Future<void> changePin({
    required int userId,
    required int shopId,
    required String currentPin,
    required String newPin,
  });

  Future<void> touchSession({
    required String sessionToken,
    required int shopId,
  });

  Future<AuthSession?> restoreSession();

  /// Verrouille l'app sans effacer les jetons hors ligne (7 jours).
  Future<void> lockActiveSession();

  Future<void> logout();

  /// `true` après une déconnexion explicite (≠ verrouillage PIN).
  Future<bool> wasLoggedOut();

  Future<OwnedShopList> listOwnedShops();

  Future<AuthSession> switchShop({required int shopId});

  Future<WhatsappOtpRequestResult> requestWhatsappOtp({required String phone});

  Future<WhatsappOtpVerifyResult> verifyWhatsappOtp({
    required String phone,
    required String code,
  });

  Future<AuthSession> completeWhatsappLogin({
    required String verificationToken,
    required int shopId,
    required int userId,
  });
}
