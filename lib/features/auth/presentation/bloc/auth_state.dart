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
  const AuthNeedsSetup({this.localSetupAvailable = false});

  /// Une boutique est déjà installée localement (connexion PIN possible).
  final bool localSetupAvailable;

  @override
  List<Object?> get props => [localSetupAvailable];
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
  const AuthSetupFailure(
    this.message, {
    this.fieldErrors = const {},
  });

  final String message;
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
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

/// Connexion WhatsApp : saisie numéro puis code OTP.
class AuthWhatsappLogin extends AuthState {
  const AuthWhatsappLogin({
    this.phone,
    this.step = WhatsappLoginStep.phone,
    this.isSubmitting = false,
    this.errorMessage,
    this.infoMessage,
    this.maskedPhone,
    this.deliveryWarning,
    this.devCode,
  });

  final String? phone;
  final WhatsappLoginStep step;
  final bool isSubmitting;
  final String? errorMessage;
  final String? infoMessage;
  final String? maskedPhone;
  final String? deliveryWarning;
  final String? devCode;

  @override
  List<Object?> get props => [
        phone,
        step,
        isSubmitting,
        errorMessage,
        infoMessage,
        maskedPhone,
        deliveryWarning,
        devCode,
      ];
}

enum WhatsappLoginStep { phone, code }

/// Sélection du contexte boutique après OTP (tous rôles).
class AuthMembershipSelection extends AuthState {
  const AuthMembershipSelection({
    required this.phone,
    required this.verificationToken,
    required this.memberships,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String phone;
  final String verificationToken;
  final List<AuthMembership> memberships;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  List<Object?> get props =>
      [phone, verificationToken, memberships, isSubmitting, errorMessage];
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
