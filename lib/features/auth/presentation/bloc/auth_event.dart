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

class AuthLockScreenRequested extends AuthEvent {
  const AuthLockScreenRequested({this.shopId});

  final int? shopId;

  @override
  List<Object?> get props => [shopId];
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
    this.shopAddress,
    this.shopPhone,
  });

  final String ownerName;
  final String shopName;
  final String pin;
  final String? shopAddress;
  final String? shopPhone;

  @override
  List<Object?> get props =>
      [ownerName, shopName, pin, shopAddress, shopPhone];
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

class AuthEntryResetRequested extends AuthEvent {
  const AuthEntryResetRequested();
}

class AuthLockScreenBackRequested extends AuthEvent {
  const AuthLockScreenBackRequested();
}
