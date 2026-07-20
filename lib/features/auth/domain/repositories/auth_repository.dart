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

  Future<AuthSession> emergencyUnlockWithWhatsappOtp({
    required String phone,
    required String code,
    required int shopId,
    int? userId,
  });

  /// Réinitialise le PIN après OTP WhatsApp et ouvre une session locale.
  Future<AuthSession> resetPinWithWhatsappOtp({
    required String verificationToken,
    required int serverShopId,
    required int serverUserId,
    required String newPin,
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

  /// Session locale persistée (≠ déconnexion).
  Future<bool> hasRestorableSession();

  /// Boutique locale liée à la session persistée (après changement de boutique).
  Future<int?> getRestorableSessionShopId();

  /// Déverrouille l'app en conservant la session locale existante.
  Future<AuthSession> unlockWithPin({
    required String pin,
    required int shopId,
    int? userId,
  });

  Future<AuthSession> unlockWithBiometric({
    required int shopId,
    int? userId,
  });

  /// Efface la session locale (déconnexion uniquement — pas le verrouillage PIN).
  Future<void> lockActiveSession();

  Future<void> logout();

  /// `true` après une déconnexion explicite (≠ verrouillage PIN).
  Future<bool> wasLoggedOut();

  Future<OwnedShopList> listOwnedShops();

  Future<AuthSession> switchShop({required int shopId});

  Future<AuthIdentityContext> getIdentityContext();

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

  /// Résout l'ID boutique serveur à partir d'un ID local (ou serveur).
  Future<int?> tryResolveServerShopId(int shopId);

  Future<List<DeviceSession>> listDeviceSessions({bool shopScope = false});

  Future<void> revokeDeviceSession(String sessionId);

  /// Vérifie le PIN du patron de la boutique (sans connexion session).
  Future<void> verifyShopOwnerPin({
    required int shopId,
    required String pin,
  });

  /// Répare la session cloud avec un PIN récemment validé (preuve en mémoire).
  Future<bool> repairCloudSessionWithPin({
    required String pin,
    required int serverShopId,
    required int localShopId,
    int? serverUserId,
  });
}
