part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthBootstrapRequested extends AuthEvent {
  const AuthBootstrapRequested();
}

class AuthProceedToLoginRequested extends AuthEvent {
  const AuthProceedToLoginRequested();
}

class AuthProceedToPinLoginRequested extends AuthEvent {
  const AuthProceedToPinLoginRequested();
}

class AuthWhatsappOtpRequested extends AuthEvent {
  const AuthWhatsappOtpRequested({required this.phone});

  final String phone;

  @override
  List<Object?> get props => [phone];
}

class AuthWhatsappOtpVerifyRequested extends AuthEvent {
  const AuthWhatsappOtpVerifyRequested({
    required this.phone,
    required this.code,
  });

  final String phone;
  final String code;

  @override
  List<Object?> get props => [phone, code];
}

class AuthWhatsappOtpResendRequested extends AuthEvent {
  const AuthWhatsappOtpResendRequested({required this.phone});

  final String phone;

  @override
  List<Object?> get props => [phone];
}

class AuthWhatsappLoginCancelled extends AuthEvent {
  const AuthWhatsappLoginCancelled();
}

class AuthWhatsappPhoneEditRequested extends AuthEvent {
  const AuthWhatsappPhoneEditRequested();
}

class AuthMembershipSelected extends AuthEvent {
  const AuthMembershipSelected({
    required this.shopId,
    required this.userId,
  });

  final int shopId;
  final int userId;

  @override
  List<Object?> get props => [shopId, userId];
}

class AuthLockScreenRequested extends AuthEvent {
  const AuthLockScreenRequested({this.shopId, this.canGoBack = true});

  final int? shopId;
  final bool canGoBack;

  @override
  List<Object?> get props => [shopId, canGoBack];
}

class AuthBiometricLoginRequested extends AuthEvent {
  const AuthBiometricLoginRequested({this.shopId = 1, this.userId});

  final int shopId;
  final int? userId;

  @override
  List<Object?> get props => [shopId, userId];
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.pin,
    this.shopId = 1,
    this.userId,
  });

  final String pin;
  final int shopId;
  final int? userId;

  @override
  List<Object?> get props => [pin, shopId, userId];
}

class AuthShopSelected extends AuthEvent {
  const AuthShopSelected({required this.shopId});

  final int shopId;

  @override
  List<Object?> get props => [shopId];
}

class AuthSessionRefreshed extends AuthEvent {
  const AuthSessionRefreshed(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

class AuthSetupRequested extends AuthEvent {
  const AuthSetupRequested({
    required this.ownerName,
    required this.shopName,
    required this.pin,
    required this.ownerPhone,
    this.shopAddress,
    this.shopPhone,
  });

  final String ownerName;
  final String shopName;
  final String pin;
  final String ownerPhone;
  final String? shopAddress;
  final String? shopPhone;

  @override
  List<Object?> get props =>
      [ownerName, shopName, pin, ownerPhone, shopAddress, shopPhone];
}

class AuthEmergencyUnlockRequested extends AuthEvent {
  const AuthEmergencyUnlockRequested({
    required this.recoveryToken,
    this.shopId = 1,
    this.userId,
  });

  final String recoveryToken;
  final int shopId;
  final int? userId;

  @override
  List<Object?> get props => [recoveryToken, shopId, userId];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthAppLockedRequested extends AuthEvent {
  const AuthAppLockedRequested();
}

/// Refresh token cloud invalide — reconnexion OTP (sans effacer la session locale).
class AuthCloudReconnectRequested extends AuthEvent {
  const AuthCloudReconnectRequested();
}

class AuthEntryResetRequested extends AuthEvent {
  const AuthEntryResetRequested();
}

class AuthLockScreenBackRequested extends AuthEvent {
  const AuthLockScreenBackRequested();
}
