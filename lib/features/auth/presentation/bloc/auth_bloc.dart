import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/last_shop_storage.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../domain/entities/auth_entities.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required IsSetupComplete isSetupComplete,
    required RestoreSession restoreSession,
    required GetLockScreen getLockScreen,
    required LoginWithPin loginWithPin,
    required LoginWithBiometric loginWithBiometric,
    required SetupOwner setupOwner,
    required EmergencyUnlock emergencyUnlock,
    required LockActiveSession lockActiveSession,
    required Logout logout,
    required ListOwnedShops listOwnedShops,
    required SwitchShop switchShop,
    required LastShopStorage lastShopStorage,
  })  : _isSetupComplete = isSetupComplete,
        _restoreSession = restoreSession,
        _getLockScreen = getLockScreen,
        _loginWithPin = loginWithPin,
        _loginWithBiometric = loginWithBiometric,
        _setupOwner = setupOwner,
        _emergencyUnlock = emergencyUnlock,
        _lockActiveSession = lockActiveSession,
        _logout = logout,
        _listOwnedShops = listOwnedShops,
        _switchShop = switchShop,
        _lastShopStorage = lastShopStorage,
        super(const AuthInitial()) {
    on<AuthBootstrapRequested>(_onBootstrap);
    on<AuthProceedToLoginRequested>(_onProceedToLogin);
    on<AuthLockScreenRequested>(_onLockScreenRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthBiometricLoginRequested>(_onBiometricLoginRequested);
    on<AuthShopSelected>(_onShopSelected);
    on<AuthSessionRefreshed>(_onSessionRefreshed);
    on<AuthSetupRequested>(_onSetupRequested);
    on<AuthEmergencyUnlockRequested>(_onEmergencyUnlock);
    on<AuthAppLockedRequested>(_onAppLocked);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthEntryResetRequested>(_onEntryResetRequested);
    on<AuthLockScreenBackRequested>(_onLockScreenBackRequested);
  }

  final IsSetupComplete _isSetupComplete;
  final RestoreSession _restoreSession;
  final GetLockScreen _getLockScreen;
  final LoginWithPin _loginWithPin;
  final LoginWithBiometric _loginWithBiometric;
  final SetupOwner _setupOwner;
  final EmergencyUnlock _emergencyUnlock;
  final LockActiveSession _lockActiveSession;
  final Logout _logout;
  final ListOwnedShops _listOwnedShops;
  final SwitchShop _switchShop;
  final LastShopStorage _lastShopStorage;

  int get _defaultShopId => _lastShopStorage.lastShopId;

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

      final session = await _restoreSession();
      if (session != null) {
        await _lastShopStorage.save(session.shop.id);
        emit(AuthAuthenticated(session));
        return;
      }

      final lockScreen = await _getLockScreen(shopId: _defaultShopId);
      emit(AuthLocked(lockScreen));
    } catch (error) {
      emit(AuthFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onProceedToLogin(
    AuthProceedToLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final lockScreen = await _getLockScreen(shopId: _defaultShopId);
      emit(AuthLocked(lockScreen, canGoBack: true));
    } catch (error) {
      emit(AuthFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onLockScreenRequested(
    AuthLockScreenRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final shopId = event.shopId ?? _defaultShopId;
      final lockScreen = await _getLockScreen(shopId: shopId);
      emit(AuthLocked(lockScreen));
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
            errorMessage: failure.message,
            requiresEmergencyRecovery: failure is EmergencyRecoveryRequiredFailure,
            canGoBack: current.canGoBack,
          ),
        );
      } else {
        emit(AuthFailure(failure.message));
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
          errorMessage: failure.message,
          canGoBack: current.canGoBack,
        ));
      } else {
        emit(AuthFailure(failure.message));
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
    if (session.user.role == UserRole.owner) {
      try {
        final shops = await _listOwnedShops();
        if (shops.activeShops.length > 1) {
          emit(AuthShopSelection(
            provisionalSession: session,
            shops: shops,
          ));
          return;
        }
      } on Failure {
        // Une seule boutique ou hors ligne : continuer directement.
      }
    }

    await _lastShopStorage.save(session.shop.id);
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
          : await _switchShop(shopId: event.shopId);

      await _lastShopStorage.save(session.shop.id);
      emit(AuthAuthenticated(session));
    } on Failure catch (failure) {
      emit(AuthShopSelection(
        provisionalSession: current.provisionalSession,
        shops: current.shops,
        errorMessage: failure.message,
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
        shopAddress: event.shopAddress,
        shopPhone: event.shopPhone,
      );
      await _lastShopStorage.save(result.shopId);
      emit(AuthSetupCompleted(result));
    } on Failure catch (failure) {
      emit(AuthSetupFailure(failure.message));
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
      emit(AuthFailure(failure.message));
    } catch (error) {
      emit(AuthFailure(friendlyErrorMessage(error)));
    }
  }

  Future<void> _onAppLocked(
    AuthAppLockedRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _lockActiveSession();
    add(const AuthLockScreenRequested());
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _logout();
    add(const AuthLockScreenRequested());
  }

  void _onEntryResetRequested(
    AuthEntryResetRequested event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthNeedsSetup());
  }

  void _onLockScreenBackRequested(
    AuthLockScreenBackRequested event,
    Emitter<AuthState> emit,
  ) {
    final current = state;
    if (current is! AuthLocked || !current.canGoBack) return;
    emit(const AuthNeedsSetup());
  }
}
