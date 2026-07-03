import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/app_lock_controller.dart';
import '../../../../core/errors/auth_error_humanizer.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/last_shop_storage.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../domain/entities/auth_entities.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required IsSetupComplete isSetupComplete,
    required WasLoggedOut wasLoggedOut,
    required GetLockScreen getLockScreen,
    required LoginWithPin loginWithPin,
    required LoginWithBiometric loginWithBiometric,
    required SetupOwner setupOwner,
    required EmergencyUnlock emergencyUnlock,
    required Logout logout,
    required ListOwnedShops listOwnedShops,
    required SwitchShop switchShop,
    required RequestWhatsappOtp requestWhatsappOtp,
    required VerifyWhatsappOtp verifyWhatsappOtp,
    required CompleteWhatsappLogin completeWhatsappLogin,
    required LastShopStorage lastShopStorage,
    required SyncService syncService,
    required AppLockController appLockController,
  })  : _isSetupComplete = isSetupComplete,
        _wasLoggedOut = wasLoggedOut,
        _getLockScreen = getLockScreen,
        _loginWithPin = loginWithPin,
        _loginWithBiometric = loginWithBiometric,
        _setupOwner = setupOwner,
        _emergencyUnlock = emergencyUnlock,
        _logout = logout,
        _listOwnedShops = listOwnedShops,
        _switchShop = switchShop,
        _requestWhatsappOtp = requestWhatsappOtp,
        _verifyWhatsappOtp = verifyWhatsappOtp,
        _completeWhatsappLogin = completeWhatsappLogin,
        _lastShopStorage = lastShopStorage,
        _syncService = syncService,
        _appLockController = appLockController,
        super(const AuthInitial()) {
    on<AuthBootstrapRequested>(_onBootstrap);
    on<AuthProceedToLoginRequested>(_onProceedToLogin);
    on<AuthProceedToPinLoginRequested>(_onProceedToPinLogin);
    on<AuthWhatsappOtpRequested>(_onWhatsappOtpRequested);
    on<AuthWhatsappOtpVerifyRequested>(_onWhatsappOtpVerifyRequested);
    on<AuthWhatsappOtpResendRequested>(_onWhatsappOtpResendRequested);
    on<AuthWhatsappLoginCancelled>(_onWhatsappLoginCancelled);
    on<AuthWhatsappPhoneEditRequested>(_onWhatsappPhoneEditRequested);
    on<AuthMembershipSelected>(_onMembershipSelected);
    on<AuthLockScreenRequested>(_onLockScreenRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthBiometricLoginRequested>(_onBiometricLoginRequested);
    on<AuthShopSelected>(_onShopSelected);
    on<AuthSessionRefreshed>(_onSessionRefreshed);
    on<AuthSetupRequested>(_onSetupRequested);
    on<AuthEmergencyUnlockRequested>(_onEmergencyUnlock);
    on<AuthAppLockedRequested>(_onAppLocked);
    on<AuthCloudReconnectRequested>(_onCloudReconnect);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthEntryResetRequested>(_onEntryResetRequested);
    on<AuthLockScreenBackRequested>(_onLockScreenBackRequested);
  }

  final IsSetupComplete _isSetupComplete;
  final WasLoggedOut _wasLoggedOut;
  final GetLockScreen _getLockScreen;
  final LoginWithPin _loginWithPin;
  final LoginWithBiometric _loginWithBiometric;
  final SetupOwner _setupOwner;
  final EmergencyUnlock _emergencyUnlock;
  final Logout _logout;
  final ListOwnedShops _listOwnedShops;
  final SwitchShop _switchShop;
  final RequestWhatsappOtp _requestWhatsappOtp;
  final VerifyWhatsappOtp _verifyWhatsappOtp;
  final CompleteWhatsappLogin _completeWhatsappLogin;
  final LastShopStorage _lastShopStorage;
  final SyncService _syncService;
  final AppLockController _appLockController;

  int get _defaultShopId => _lastShopStorage.lastShopId;

  void _scheduleBackgroundSync(AuthSession session) {
    _syncService.scheduleSync(shopId: session.shop.id);
  }

  Future<void> _emitEntryScreen(Emitter<AuthState> emit) async {
    final localSetupAvailable = await _isSetupComplete();
    emit(AuthNeedsSetup(localSetupAvailable: localSetupAvailable));
  }

  Future<void> _onBootstrap(
    AuthBootstrapRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final setupDone = await _isSetupComplete();
      if (!setupDone) {
        emit(const AuthNeedsSetup());
        return;
      }

      if (await _wasLoggedOut()) {
        emit(AuthNeedsSetup(localSetupAvailable: true));
        return;
      }

      // Session locale présente → PIN obligatoire (cold start).
      final lockScreen = await _getLockScreen(shopId: _defaultShopId);
      emit(AuthLocked(lockScreen, canGoBack: false));
    } on NotFoundFailure {
      emit(const AuthNeedsSetup());
    } catch (error) {
      emit(AuthFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onProceedToPinLogin(
    AuthProceedToPinLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      if (!await _isSetupComplete()) {
        await _emitEntryScreen(emit);
        return;
      }
      final lockScreen = await _getLockScreen(shopId: _defaultShopId);
      emit(AuthLocked(lockScreen, canGoBack: true));
    } on NotFoundFailure {
      emit(const AuthNeedsSetup());
    } catch (error) {
      emit(AuthFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onProceedToLogin(
    AuthProceedToLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthWhatsappLogin());
  }

  Future<void> _onWhatsappOtpRequested(
    AuthWhatsappOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthWhatsappLogin(phone: event.phone, isSubmitting: true));

    try {
      final result = await _requestWhatsappOtp(phone: event.phone);
      emit(
        AuthWhatsappLogin(
          phone: event.phone,
          step: WhatsappLoginStep.code,
          infoMessage: result.message,
          maskedPhone: result.maskedPhone,
        ),
      );
    } on Failure catch (failure) {
      emit(
        AuthWhatsappLogin(
          phone: event.phone,
          errorMessage: humanizeAuthErrorMessage(failure.message),
        ),
      );
    } catch (error) {
      emit(
        AuthWhatsappLogin(
          phone: event.phone,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onWhatsappOtpResendRequested(
    AuthWhatsappOtpResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthWhatsappLogin) return;

    emit(
      AuthWhatsappLogin(
        phone: event.phone,
        step: WhatsappLoginStep.code,
        isSubmitting: true,
        maskedPhone: current.maskedPhone,
      ),
    );

    try {
      final result = await _requestWhatsappOtp(phone: event.phone);
      emit(
        AuthWhatsappLogin(
          phone: event.phone,
          step: WhatsappLoginStep.code,
          infoMessage: result.message,
          maskedPhone: result.maskedPhone,
        ),
      );
    } on Failure catch (failure) {
      emit(
        AuthWhatsappLogin(
          phone: event.phone,
          step: WhatsappLoginStep.code,
          maskedPhone: current.maskedPhone,
          errorMessage: humanizeAuthErrorMessage(failure.message),
        ),
      );
    } catch (error) {
      emit(
        AuthWhatsappLogin(
          phone: event.phone,
          step: WhatsappLoginStep.code,
          maskedPhone: current.maskedPhone,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onWhatsappOtpVerifyRequested(
    AuthWhatsappOtpVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      AuthWhatsappLogin(
        phone: event.phone,
        step: WhatsappLoginStep.code,
        isSubmitting: true,
      ),
    );

    try {
      final result = await _verifyWhatsappOtp(
        phone: event.phone,
        code: event.code,
      );

      if (result.memberships.isEmpty) {
        emit(
          AuthWhatsappLogin(
            phone: event.phone,
            step: WhatsappLoginStep.code,
            errorMessage:
                'Aucun accès boutique pour ce numéro. Contactez votre patron.',
          ),
        );
        return;
      }

      if (result.memberships.length == 1) {
        final membership = result.memberships.first;
        await _finalizeWhatsappLogin(
          verificationToken: result.verificationToken,
          shopId: membership.shopId,
          userId: membership.userId,
          emit: emit,
        );
        return;
      }

      emit(
        AuthMembershipSelection(
          phone: event.phone,
          verificationToken: result.verificationToken,
          memberships: result.memberships,
        ),
      );
    } on Failure catch (failure) {
      emit(
        AuthWhatsappLogin(
          phone: event.phone,
          step: WhatsappLoginStep.code,
          errorMessage: humanizeAuthErrorMessage(failure.message),
        ),
      );
    } catch (error) {
      emit(
        AuthWhatsappLogin(
          phone: event.phone,
          step: WhatsappLoginStep.code,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onMembershipSelected(
    AuthMembershipSelected event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthMembershipSelection) return;

    emit(
      AuthMembershipSelection(
        phone: current.phone,
        verificationToken: current.verificationToken,
        memberships: current.memberships,
        isSubmitting: true,
      ),
    );

    try {
      await _finalizeWhatsappLogin(
        verificationToken: current.verificationToken,
        shopId: event.shopId,
        userId: event.userId,
        emit: emit,
      );
    } on Failure catch (failure) {
      emit(
        AuthMembershipSelection(
          phone: current.phone,
          verificationToken: current.verificationToken,
          memberships: current.memberships,
          errorMessage: humanizeAuthErrorMessage(failure.message),
        ),
      );
    } catch (error) {
      emit(
        AuthMembershipSelection(
          phone: current.phone,
          verificationToken: current.verificationToken,
          memberships: current.memberships,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _finalizeWhatsappLogin({
    required String verificationToken,
    required int shopId,
    required int userId,
    required Emitter<AuthState> emit,
  }) async {
    final session = await _completeWhatsappLogin(
      verificationToken: verificationToken,
      shopId: shopId,
      userId: userId,
    );
    await _completeLogin(session, emit);
  }

  Future<void> _onWhatsappLoginCancelled(
    AuthWhatsappLoginCancelled event,
    Emitter<AuthState> emit,
  ) async {
    await _emitEntryScreen(emit);
  }

  void _onWhatsappPhoneEditRequested(
    AuthWhatsappPhoneEditRequested event,
    Emitter<AuthState> emit,
  ) {
    final current = state;
    if (current is! AuthWhatsappLogin) return;
    emit(
      AuthWhatsappLogin(
        phone: current.phone,
        step: WhatsappLoginStep.phone,
      ),
    );
  }

  Future<void> _onLockScreenRequested(
    AuthLockScreenRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthLocked) {
      emit(const AuthLoading());
    }
    try {
      final shopId = event.shopId ?? _defaultShopId;
      final lockScreen = await _getLockScreen(shopId: shopId);
      emit(AuthLocked(lockScreen, canGoBack: event.canGoBack));
    } on NotFoundFailure {
      emit(const AuthNeedsSetup());
    } catch (error) {
      emit(AuthFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is AuthLocked) {
      emit(AuthLocked(
        current.lockScreen,
        isSubmitting: true,
        canGoBack: current.canGoBack,
      ));
    } else {
      emit(const AuthLoading());
    }

    try {
      final session = await _loginWithPin(
        pin: event.pin,
        shopId: event.shopId,
        userId: event.userId,
      );
      await _completeLogin(session, emit);
    } on Failure catch (failure) {
      if (current is AuthLocked) {
        emit(
          AuthLocked(
            current.lockScreen,
            errorMessage: humanizeAuthErrorMessage(failure.message),
            requiresEmergencyRecovery: failure is EmergencyRecoveryRequiredFailure,
            canGoBack: current.canGoBack,
          ),
        );
      } else {
      emit(AuthFailure(humanizeAuthErrorMessage(failure.message)));
      }
    } catch (error) {
      final message = friendlyErrorMessage(error);
      if (current is AuthLocked) {
        emit(AuthLocked(
          current.lockScreen,
          errorMessage: message,
          canGoBack: current.canGoBack,
        ));
      } else {
        emit(AuthFailure(message));
      }
    }
  }

  Future<void> _onBiometricLoginRequested(
    AuthBiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is AuthLocked) {
      emit(AuthLocked(
        current.lockScreen,
        isSubmitting: true,
        canGoBack: current.canGoBack,
      ));
    }

    try {
      final session = await _loginWithBiometric(
        shopId: event.shopId,
        userId: event.userId,
      );
      await _completeLogin(session, emit);
    } on Failure catch (failure) {
      if (current is AuthLocked) {
        emit(AuthLocked(
          current.lockScreen,
          errorMessage: humanizeAuthErrorMessage(failure.message),
          canGoBack: current.canGoBack,
        ));
      } else {
      emit(AuthFailure(humanizeAuthErrorMessage(failure.message)));
      }
    } catch (error) {
      final message = friendlyErrorMessage(error);
      if (current is AuthLocked) {
        emit(AuthLocked(
          current.lockScreen,
          errorMessage: message,
          canGoBack: current.canGoBack,
        ));
      } else {
        emit(AuthFailure(message));
      }
    }
  }

  Future<void> _completeLogin(
    AuthSession session,
    Emitter<AuthState> emit,
  ) async {
    _appLockController.markUnlocked();

    if (session.user.role == UserRole.owner) {
      try {
        final shops = await _listOwnedShops().timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw const NetworkFailure('Délai dépassé'),
        );
        if (shops.activeShops.length > 1) {
          emit(AuthShopSelection(
            provisionalSession: session,
            shops: shops,
          ));
          return;
        }
      } on Object {
        // Réseau lent ou indisponible : ouvrir l'app avec la boutique courante.
      }
    }

    await _lastShopStorage.save(session.shop.id);
    _scheduleBackgroundSync(session);
    emit(AuthAuthenticated(session));
  }

  Future<void> _onShopSelected(
    AuthShopSelected event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthShopSelection) return;

    emit(AuthShopSelection(
      provisionalSession: current.provisionalSession,
      shops: current.shops,
      isSubmitting: true,
    ));

    try {
      final session = event.shopId == current.shops.activeShopId
          ? current.provisionalSession
          : await _switchShop(shopId: event.shopId).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw const NetworkFailure(
                'Le serveur met trop de temps à répondre. Réessayez.',
              ),
            );

      await _lastShopStorage.save(session.shop.id);
      _scheduleBackgroundSync(session);
      emit(AuthAuthenticated(session));
    } on Failure catch (failure) {
      emit(AuthShopSelection(
        provisionalSession: current.provisionalSession,
        shops: current.shops,
        errorMessage: humanizeAuthErrorMessage(failure.message),
      ));
    } catch (error) {
      emit(AuthShopSelection(
        provisionalSession: current.provisionalSession,
        shops: current.shops,
        errorMessage: friendlyErrorMessage(error),
      ));
    }
  }

  Future<void> _onSessionRefreshed(
    AuthSessionRefreshed event,
    Emitter<AuthState> emit,
  ) async {
    await _lastShopStorage.save(event.session.shop.id);
    _scheduleBackgroundSync(event.session);
    emit(AuthAuthenticated(event.session));
  }

  Future<void> _onSetupRequested(
    AuthSetupRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthSetupInProgress());
    try {
      final result = await _setupOwner(
        ownerName: event.ownerName,
        shopName: event.shopName,
        pin: event.pin,
        ownerPhone: event.ownerPhone,
        shopAddress: event.shopAddress,
        shopPhone: event.shopPhone,
      );
      await _lastShopStorage.save(result.shopId);
      emit(AuthSetupCompleted(result));
    } on SetupFieldConflictFailure catch (failure) {
      emit(
        AuthSetupFailure(
          failure.message,
          fieldErrors: failure.fieldErrors,
        ),
      );
    } on Failure catch (failure) {
      emit(AuthSetupFailure(humanizeAuthErrorMessage(failure.message)));
    } catch (error) {
      emit(AuthSetupFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onEmergencyUnlock(
    AuthEmergencyUnlockRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final session = await _emergencyUnlock(
        recoveryToken: event.recoveryToken,
        shopId: event.shopId,
        userId: event.userId,
      );
      await _completeLogin(session, emit);
    } on Failure catch (failure) {
      emit(AuthFailure(humanizeAuthErrorMessage(failure.message)));
    } catch (error) {
      emit(AuthFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onAppLocked(
    AuthAppLockedRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthLocked || state is AuthLoading) return;

    final shopId = switch (state) {
      AuthAuthenticated(:final session) => session.shop.id,
      AuthLocked(:final lockScreen) => lockScreen.shopId,
      _ => _defaultShopId,
    };

    try {
      final lockScreen = await _getLockScreen(shopId: shopId);
      emit(AuthLocked(lockScreen, canGoBack: false));
    } on NotFoundFailure {
      emit(const AuthNeedsSetup());
    } catch (error) {
      emit(AuthFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onCloudReconnect(
    AuthCloudReconnectRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthWhatsappLogin());
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _logout();
    _syncService.clearShop();
    await _emitEntryScreen(emit);
  }

  Future<void> _onEntryResetRequested(
    AuthEntryResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _emitEntryScreen(emit);
  }

  Future<void> _onLockScreenBackRequested(
    AuthLockScreenBackRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthLocked || !current.canGoBack) return;
    await _emitEntryScreen(emit);
  }
}
