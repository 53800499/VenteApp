part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthNeedsSetup extends AuthState {
  const AuthNeedsSetup();
}

class AuthSetupInProgress extends AuthState {
  const AuthSetupInProgress();
}

class AuthSetupCompleted extends AuthState {
  const AuthSetupCompleted(this.result);

  final SetupOwnerResult result;

  @override
  List<Object?> get props => [result];
}

class AuthSetupFailure extends AuthState {
  const AuthSetupFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthLocked extends AuthState {
  const AuthLocked(
    this.lockScreen, {
    this.isSubmitting = false,
    this.errorMessage,
    this.requiresEmergencyRecovery = false,
    this.canGoBack = false,
  });

  final LockScreenData lockScreen;
  final bool isSubmitting;
  final String? errorMessage;
  final bool requiresEmergencyRecovery;
  final bool canGoBack;

  @override
  List<Object?> get props => [
        lockScreen,
        isSubmitting,
        errorMessage,
        requiresEmergencyRecovery,
        canGoBack,
      ];
}

/// Sélection de boutique après connexion (patron multi-boutiques).
class AuthShopSelection extends AuthState {
  const AuthShopSelection({
    required this.provisionalSession,
    required this.shops,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthSession provisionalSession;
  final OwnedShopList shops;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  List<Object?> get props =>
      [provisionalSession, shops, isSubmitting, errorMessage];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
