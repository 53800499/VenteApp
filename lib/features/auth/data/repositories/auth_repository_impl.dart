import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/cloud_session_repair_service.dart';
import '../../../../core/auth/recent_pin_proof.dart';
import '../../../../core/database/app_database.dart' hide AuthSession;
import '../../../../core/errors/auth_error_humanizer.dart';
import '../../../../core/constants/api_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/active_shop_context.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/security/lockout_policy.dart';
import '../../../../core/security/pin_hasher.dart';
import '../../../../core/security/production_message_policy.dart';
import '../../../../core/security/recovery_token_service.dart';
import '../../../../core/storage/auth_credentials_storage.dart';
import '../../../../core/storage/auth_flow_storage.dart';
import '../../../../core/storage/device_id_storage.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/sync/cloud_sync_enabler.dart';
import '../../../../core/utils/phone_util.dart';
import '../../../../core/shop/shop_hierarchy.dart';
import '../../../../core/utils/time.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/entities/setup_field.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/setup_validation_service.dart';
import '../../domain/value_objects/pin.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/auth_api_models.dart';

typedef OnlineSessionReadyCallback = void Function(int shopId);
typedef CloudSessionRestoredCallback = void Function();
typedef SessionEndedCallback = Future<void> Function();

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AppDatabase database,
    required PinHasher pinHasher,
    required LockoutPolicy lockoutPolicy,
    required RecoveryTokenService recoveryTokenService,
    required SessionStorage sessionStorage,
    required AuthCredentialsStorage credentialsStorage,
    AuthFlowStorage? authFlowStorage,
    DeviceIdStorage? deviceIdStorage,
    ActiveShopContext? activeShopContext,
    AuthRemoteDatasource? remote,
    NetworkInfo? networkInfo,
    ApiClient? apiClient,
    CloudSyncEnabler? cloudSyncEnabler,
    CloudSessionRepairService? cloudSessionRepair,
    RecentPinProof? recentPinProof,
    OnlineSessionReadyCallback? onOnlineSessionReady,
    CloudSessionRestoredCallback? onCloudSessionRestored,
    SessionEndedCallback? onSessionEnded,
    Uuid? uuid,
    SetupValidationService? setupValidation,
  })  : _db = database,
        _pinHasher = pinHasher,
        _lockoutPolicy = lockoutPolicy,
        _recoveryTokenService = recoveryTokenService,
        _sessionStorage = sessionStorage,
        _credentials = credentialsStorage,
        _authFlow = authFlowStorage,
        _deviceIds = deviceIdStorage ?? DeviceIdStorage.inMemory(),
        _activeShop = activeShopContext ?? ActiveShopContext(),
        _remote = remote,
        _networkInfo = networkInfo ?? const NetworkInfo.alwaysOffline(),
        _apiClient = apiClient,
        _cloudSyncEnabler = cloudSyncEnabler,
        _cloudSessionRepair = cloudSessionRepair,
        _recentPinProof = recentPinProof ?? RecentPinProof(),
        _onOnlineSessionReady = onOnlineSessionReady,
        _onCloudSessionRestored = onCloudSessionRestored,
        _onSessionEnded = onSessionEnded,
        _uuid = uuid ?? const Uuid(),
        _setupValidation = setupValidation ?? const SetupValidationService();

  final AppDatabase _db;
  final PinHasher _pinHasher;
  final LockoutPolicy _lockoutPolicy;
  final RecoveryTokenService _recoveryTokenService;
  final SessionStorage _sessionStorage;
  final AuthCredentialsStorage _credentials;
  final AuthFlowStorage? _authFlow;
  final DeviceIdStorage _deviceIds;
  final ActiveShopContext _activeShop;
  final AuthRemoteDatasource? _remote;
  final NetworkInfo _networkInfo;
  final ApiClient? _apiClient;
  final CloudSyncEnabler? _cloudSyncEnabler;
  final CloudSessionRepairService? _cloudSessionRepair;
  final RecentPinProof _recentPinProof;
  final OnlineSessionReadyCallback? _onOnlineSessionReady;
  final CloudSessionRestoredCallback? _onCloudSessionRestored;
  final SessionEndedCallback? _onSessionEnded;
  final Uuid _uuid;
  final SetupValidationService _setupValidation;

  bool get _isOnlineMode => _remote != null;

  static const _onlinePinRefreshTimeout = Duration(seconds: 10);
  String get _onlinePinTimeoutMessage =>
      ProductionMessagePolicy.onlinePinTimeoutMessage();

  @override
  Future<bool> isSetupComplete() async {
    if (await _credentials.hasCredentials()) return true;
    return _hasLocalOwnerInstallation();
  }

  @override
  Future<bool> wasLoggedOut() async => _authFlow?.wasLoggedOut() ?? false;

  Future<bool> _hasLocalOwnerInstallation() async {
    final owners = await (_db.select(_db.users)
          ..where((u) => u.role.equals('owner')))
        .get();
    return owners.isNotEmpty;
  }

  @override
  Future<LockScreenData> getLockScreen({required int shopId}) async {
    final serverShopId = await _resolveServerShopId(shopId);
    final localShopId = await _resolveLocalShopId(serverShopId);

    final localUsers = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(localShopId) & u.isActive.equals(true)))
        .get();

    if (localUsers.isNotEmpty) {
      final local = await _lockScreenFromLocal(localShopId);
      if (_remote != null && await _networkInfo.isConnected) {
        unawaited(_syncLockScreenFromApiInBackground(serverShopId));
      }
      return local;
    }

    // Pas d'utilisateurs locaux : ne jamais bloquer l'ouverture sur le réseau.
    final fromStored = await _lockScreenFromStoredProfile(localShopId);
    if (fromStored != null) {
      if (_remote != null && await _networkInfo.isConnected) {
        unawaited(_syncLockScreenFromApiInBackground(serverShopId));
      }
      return fromStored;
    }

    if (_remote != null && await _networkInfo.isConnected) {
      unawaited(_syncLockScreenFromApiInBackground(serverShopId));
    }

    final shop = await (_db.select(_db.shops)..where((s) => s.id.equals(localShopId)))
        .getSingleOrNull();
    if (shop == null) {
      throw const NotFoundFailure('Boutique introuvable.');
    }
    final settings = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(localShopId)))
        .getSingleOrNull();

    return LockScreenData(
      shopId: localShopId,
      shopName: settings?.shopName ?? shop.name,
      shopLogoPath: settings?.shopLogoPath,
      users: const [],
    );
  }

  Future<void> _syncLockScreenFromApiInBackground(int serverShopId) async {
    try {
      final remote = await _remote!.getLockScreen(serverShopId);
      await _syncLockScreenFromApi(remote);
    } on Object {
      // L'écran PIN local reste utilisable sans le réseau.
    }
  }

  @override
  Future<AuthSession> loginWithPin({
    required String pin,
    required int shopId,
    int? userId,
  }) async {
    final serverShopId = await _resolveServerShopId(shopId);
    final localShopId = await _resolveLocalShopId(serverShopId);

    final localUsers = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(localShopId) & u.isActive.equals(true)))
        .get();

    if (localUsers.isNotEmpty) {
      try {
        final session = await _loginWithPinLocal(
          pin: pin,
          shopId: localShopId,
          userId: userId,
        );
        if (_remote != null && await _networkInfo.isConnected) {
          unawaited(
            _refreshOnlineCredentialsAfterLocalPin(
              pin: pin,
              shopId: serverShopId,
              localShopId: localShopId,
              userId: userId,
            ),
          );
        }
        return session;
      } on InvalidPinFailure {
        // Le cloud ne tranche que pour un PIN local provisoire (nouvel appareil
        // post-WhatsApp). Un PIN erroné d'un utilisateur établi reste une erreur
        // locale : on ne contacte pas le serveur.
        if (await _isPinProvisional(localShopId: localShopId, userId: userId)) {
          if (_remote != null && await _networkInfo.isConnected) {
            return _loginWithPinOnline(
              pin: pin,
              serverShopId: serverShopId,
              userId: userId,
            );
          }
          throw const NetworkFailure(
            'Connexion internet requise pour valider ce PIN la première fois '
            'sur cet appareil.',
          );
        }
        rethrow;
      }
    }

    if (_remote != null && await _networkInfo.isConnected) {
      return _loginWithPinOnline(
        pin: pin,
        serverShopId: serverShopId,
        userId: userId,
      );
    }

    if (_isOnlineMode && !await _networkInfo.isConnected && localUsers.isEmpty) {
      throw const NetworkFailure(
        'Connexion internet requise pour la première connexion.',
      );
    }

    throw const NotFoundFailure(
      'Aucun utilisateur local. Connectez-vous ou réinstallez l\'application.',
    );
  }

  Future<AuthSession> _loginWithPinOnline({
    required String pin,
    required int serverShopId,
    int? userId,
  }) async {
    final localShopId = await _resolveLocalShopId(serverShopId);
    final serverUserId = await _resolveServerUserId(
      localShopId: localShopId,
      userId: userId,
    );
    final device = await _deviceIds.getAuthDevice();
    final result = await _remote!.loginWithPin(
      pin: pin,
      shopId: serverShopId,
      userId: serverUserId,
      deviceId: device.deviceId,
      deviceLabel: device.deviceLabel,
    ).timeout(
      _onlinePinRefreshTimeout,
      onTimeout: () => throw NetworkFailure(_onlinePinTimeoutMessage),
    );
    return _finalizeOnlineLogin(result, pin: pin);
  }

  Future<void> _refreshOnlineCredentialsAfterLocalPin({
    required String pin,
    required int shopId,
    required int localShopId,
    int? userId,
  }) async {
    final repair = _cloudSessionRepair;
    if (repair == null) {
      await _legacyRefreshOnlineCredentialsAfterLocalPin(
        pin: pin,
        shopId: shopId,
        localShopId: localShopId,
        userId: userId,
      );
      return;
    }

    try {
      final serverUserId = userId != null
          ? await _resolveServerUserId(
              localShopId: localShopId,
              userId: userId,
            )
          : null;

      _recentPinProof.record(
        pin: pin,
        serverShopId: shopId,
        localShopId: localShopId,
        serverUserId: serverUserId,
      );

      final outcome = await repair.repairAfterPinUnlock();
      if (outcome == CloudRepairOutcome.alreadyValid ||
          outcome == CloudRepairOutcome.refreshed ||
          outcome == CloudRepairOutcome.pinLogin) {
        _onOnlineSessionReady?.call(localShopId);
        _recentPinProof.clear();
      } else if (outcome == CloudRepairOutcome.failed) {
        _recentPinProof.clear();
        await repair.onRepairExhausted?.call();
      }
    } on Object {
      // La session locale est déjà ouverte ; la synchro API peut attendre.
    }
  }

  Future<void> _legacyRefreshOnlineCredentialsAfterLocalPin({
    required String pin,
    required int shopId,
    required int localShopId,
    int? userId,
  }) async {
    try {
      final serverUserId = userId != null
          ? await _resolveServerUserId(
              localShopId: localShopId,
              userId: userId,
            )
          : null;
      await _attemptOnlinePinLoginForCredentials(
        pin: pin,
        serverShopId: shopId,
        localShopId: localShopId,
        serverUserId: serverUserId,
      );
      if (await _credentials.hasCredentials()) {
        _onOnlineSessionReady?.call(localShopId);
      }
    } on Object {
      // La session locale est déjà ouverte ; la synchro API peut attendre.
    }
  }

  /// Connexion API par PIN pour obtenir JWT sans recréer de session locale.
  Future<bool> _attemptOnlinePinLoginForCredentials({
    required String pin,
    required int serverShopId,
    required int localShopId,
    int? serverUserId,
    bool retryWithoutUserId = true,
  }) async {
    if (_remote == null || !await _networkInfo.isConnected) return false;

    await _syncActiveShopFromLocal(localShopId);
    _activeShop.setServerShopId(serverShopId);

    Future<LoginSuccessData?> tryLogin(int? userId) async {
      try {
        final device = await _deviceIds.getAuthDevice();
        return await _remote!.loginWithPin(
          pin: pin,
          shopId: serverShopId,
          userId: userId,
          deviceId: device.deviceId,
          deviceLabel: device.deviceLabel,
        ).timeout(_onlinePinRefreshTimeout);
      } on Object {
        return null;
      }
    }

    var result = await tryLogin(serverUserId);
    if (result == null && retryWithoutUserId && serverUserId != null) {
      result = await tryLogin(null);
    }
    if (result == null) return false;

    await _persistOnlineLoginResult(result, pin: pin);
    return true;
  }

  @override
  Future<bool> repairCloudSessionWithPin({
    required String pin,
    required int serverShopId,
    required int localShopId,
    int? serverUserId,
  }) {
    return _attemptOnlinePinLoginForCredentials(
      pin: pin,
      serverShopId: serverShopId,
      localShopId: localShopId,
      serverUserId: serverUserId,
    );
  }

  Future<User> _persistOnlineLoginResult(
    LoginSuccessData result, {
    String? pin,
  }) async {
    await _credentials.saveOnlineAuth(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      profile: {
        'id': result.user.id,
        'name': result.user.name,
        'role': result.user.role,
        'roleLabel': result.user.roleLabel,
        'shopId': result.user.shopId,
        'biometricEnabled': result.user.biometricEnabled,
        'lastLoginAt': result.user.lastLoginAt,
      },
      permissions: result.user.permissions,
      accessExpiresAt: result.accessExpiresAt,
      refreshExpiresAt: result.refreshExpiresAt,
    );
    _onCloudSessionRestored?.call();
    _activeShop.setServerShopId(result.shop.id);
    final user = await _upsertLocalUserFromApi(
      result.user,
      pin: pin,
      shopName: result.shop.name,
    );
    await _cloudSyncEnabler?.activateForShop(user.shopId);
    return user;
  }

  @override
  Future<AuthSession> loginWithBiometric({
    required int shopId,
    int? userId,
  }) async {
    final localShopId =
        await _resolveLocalShopId(await _resolveServerShopId(shopId));
    final localUsers = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(localShopId) & u.isActive.equals(true)))
        .get();

    if (localUsers.isEmpty && _isOnlineMode && !await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Connexion internet requise pour la première connexion biométrique.',
      );
    }

    final session =
        await _loginWithBiometricLocal(shopId: localShopId, userId: userId);
    // Non bloquant : la session locale est ouverte immédiatement, la session
    // en ligne s'établit en arrière-plan (évite tout loader infini).
    unawaited(_ensureOnlineSessionAfterUnlock(localShopId));
    return session;
  }

  @override
  Future<SetupOwnerResult> setupOwner({
    required String ownerName,
    required String shopName,
    required String pin,
    required String ownerPhone,
    String? shopAddress,
    String? shopPhone,
  }) async {
    if (!isValidPhone(ownerPhone)) {
      throw const ValidationFailure(
        'Numéro WhatsApp patron invalide. Utilisez le format 01XXXXXXXX ou +229…',
      );
    }

    if (_remote != null) {
      if (!await _networkInfo.isConnected) {
        throw const NetworkFailure(
          'Connexion internet requise pour l\'installation initiale.',
        );
      }

      final serverConflicts = await _remote!.validateSetupOwner(
        ownerName: ownerName,
        shopName: shopName,
        pin: pin,
        ownerPhone: ownerPhone,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
      );
      _throwSetupFieldConflicts(
        SetupField.fromStringMap(serverConflicts),
      );

      await _prepareForOwnerSetup();

      SetupOwnerData? apiResult;
      try {
        apiResult = await _remote!.setupOwner(
          ownerName: ownerName,
          shopName: shopName,
          pin: pin,
          ownerPhone: ownerPhone,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
        );

        await _persistSetupLocally(
          apiResult: apiResult,
          ownerName: ownerName,
          shopName: shopName,
          pin: pin,
          ownerPhone: ownerPhone,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
        );

        final localShopId = await _resolveLocalShopId(apiResult.shopId);
        await _attemptOnlinePinLoginForCredentials(
          pin: pin,
          serverShopId: apiResult.shopId,
          localShopId: localShopId,
          serverUserId: apiResult.userId,
          retryWithoutUserId: false,
        );

        await _authFlow?.clearLoggedOut();

        return SetupOwnerResult(
          shopId: apiResult.shopId,
          userId: apiResult.userId,
          recoveryToken: apiResult.recoveryToken,
          message: apiResult.message,
        );
      } on Failure {
        rethrow;
      } on SqliteException catch (error) {
        throw _setupPersistFailure(error.message, serverCreated: apiResult != null);
      } catch (error) {
        if (error is Failure) rethrow;
        throw _setupPersistFailure(
          error.toString(),
          serverCreated: apiResult != null,
        );
      }
    }

    try {
      return await _setupOwnerLocal(
        ownerName: ownerName,
        shopName: shopName,
        pin: pin,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
      );
    } on SqliteException catch (error) {
      throw _setupPersistFailure(error.message);
    }
  }

  void _throwSetupFieldConflicts(Map<SetupField, String> fieldErrors) {
    if (fieldErrors.isEmpty) return;
    throw SetupFieldConflictFailure(
      message: _setupValidation.summaryFor(fieldErrors) ??
          'Corrigez les champs signalés avant de continuer.',
      fieldErrors: SetupField.toStringMap(fieldErrors),
    );
  }

  Failure _setupPersistFailure(String raw, {bool serverCreated = false}) {
    final classified = classifySetupDuplicateMessage(raw);
    var message = classified.summary;
    if (serverCreated) {
      message =
          '$message\n\nLa boutique a peut-être déjà été créée sur le serveur : '
          'fermez l\'installation et utilisez « Se connecter avec WhatsApp ».';
    }
    if (classified.fieldErrors.isNotEmpty) {
      return SetupFieldConflictFailure(
        message: message,
        fieldErrors: classified.fieldErrors,
      );
    }
    return ConflictFailure(message);
  }

  @override
  Future<AuthSession> emergencyUnlock({
    required String recoveryToken,
    required int shopId,
    int? userId,
  }) async {
    if (_remote != null && await _networkInfo.isConnected) {
      final serverShopId = await _resolveServerShopId(shopId);
      final device = await _deviceIds.getAuthDevice();
      final result = await _remote!.emergencyUnlock(
        recoveryToken: recoveryToken,
        shopId: serverShopId,
        userId: userId,
        deviceId: device.deviceId,
        deviceLabel: device.deviceLabel,
      );
      return _finalizeOnlineLogin(result);
    }

    return _emergencyUnlockLocal(
      recoveryToken: recoveryToken,
      shopId: shopId,
      userId: userId,
    );
  }

  @override
  Future<AuthSession> emergencyUnlockWithWhatsappOtp({
    required String phone,
    required String code,
    required int shopId,
    int? userId,
  }) async {
    final verifyResult = await verifyWhatsappOtp(phone: phone, code: code);
    if (verifyResult.memberships.isEmpty) {
      throw const UnauthorizedFailure(
        'Aucun accès boutique pour ce numéro.',
      );
    }

    final serverShopId = await _resolveServerShopId(shopId);
    AuthMembership? membership;
    for (final candidate in verifyResult.memberships) {
      if (candidate.shopId == serverShopId &&
          (userId == null || candidate.userId == userId)) {
        membership = candidate;
        break;
      }
    }

    membership ??= verifyResult.memberships.length == 1
        ? verifyResult.memberships.first
        : null;

    if (membership == null) {
      throw const UnauthorizedFailure(
        'Ce numéro n\'a pas accès à cette boutique.',
      );
    }

    final localShopId = await _resolveLocalShopId(membership.shopId);
    final localUser = await (_db.select(_db.users)
          ..where(
            (u) =>
                u.shopId.equals(localShopId) &
                u.serverId.equals('${membership!.userId}'),
          ))
        .getSingleOrNull();
    if (localUser != null) {
      await _resetUserLockout(
        localUser,
        reason: 'Déblocage via OTP WhatsApp',
      );
    }

    return completeWhatsappLogin(
      verificationToken: verifyResult.verificationToken,
      shopId: membership.shopId,
      userId: membership.userId,
    );
  }

  @override
  Future<AuthSession> resetPinWithWhatsappOtp({
    required String verificationToken,
    required int serverShopId,
    required int serverUserId,
    required String newPin,
  }) async {
    final pinVo = Pin.create(newPin);
    final localShopId = await _resolveLocalShopId(serverShopId);

    if (_remote != null && await _networkInfo.isConnected) {
      try {
        await _remote!.resetPinWithWhatsappOtp(
          verificationToken: verificationToken,
          shopId: serverShopId,
          userId: serverUserId,
          newPin: newPin,
        );
      } on Object {
        // Poursuivre la mise à jour locale si le serveur est indisponible.
      }
    }

    final localUser = await (_db.select(_db.users)
          ..where(
            (u) =>
                u.shopId.equals(localShopId) &
                u.serverId.equals('$serverUserId'),
          ))
        .getSingleOrNull();

    if (localUser == null) {
      throw const NotFoundFailure(
        'Utilisateur local introuvable. Reconnectez-vous avec WhatsApp.',
      );
    }

    final timestamp = nowMs();
    final newHash = _pinHasher.hash(pinVo.value);
    await (_db.update(_db.users)..where((u) => u.id.equals(localUser.id))).write(
      UsersCompanion(
        pinHash: Value(newHash),
        pinProvisional: const Value(false),
        failedAttempts: const Value(0),
        lockedUntil: Value<int?>(null),
        lockoutCount: const Value(0),
        updatedAt: Value(timestamp),
        version: Value(localUser.version + 1),
      ),
    );

    await _db.into(_db.auditLogs).insert(
          AuditLogsCompanion.insert(
            shopId: localShopId,
            userId: localUser.id,
            action: 'pin_changed',
            module: 'auth',
            entityId: localUser.id,
            entityTable: 'users',
            createdAt: timestamp,
          ),
        );

    final updatedUser = await (_db.select(_db.users)
          ..where((u) => u.id.equals(localUser.id)))
        .getSingle();

    final settings = await _getSettings(localShopId);
    final permissions =
        await _resolvePermissions(UserRole.fromCode(updatedUser.role));

    final session = await _createSession(
      user: updatedUser,
      settings: settings,
      shopId: localShopId,
      permissions: permissions,
      serverUserId: serverUserId,
      serverShopId: serverShopId,
    );

    if (_remote != null && await _networkInfo.isConnected) {
      unawaited(
        _refreshOnlineCredentialsAfterLocalPin(
          pin: newPin,
          shopId: serverShopId,
          localShopId: localShopId,
          userId: localUser.id,
        ),
      );
    }

    return session;
  }

  @override
  Future<bool> enableBiometric({
    required int userId,
    required String sessionToken,
    required String pin,
  }) async {
    final session = await (_db.select(_db.authSessions)
          ..where((s) => s.id.equals(sessionToken)))
        .getSingleOrNull();

    if (session == null ||
        session.userId != userId ||
        session.expiresAt <= nowMs()) {
      throw const UnauthorizedFailure('Session invalide ou expirée.');
    }

    final user = await (_db.select(_db.users)
          ..where(
            (u) => u.id.equals(userId) & u.shopId.equals(session.shopId),
          ))
        .getSingleOrNull();

    if (user == null) {
      throw const UnauthorizedFailure('Utilisateur introuvable.');
    }

    final pinVo = Pin.create(pin);
    if (!_pinHasher.compare(pinVo.value, user.pinHash)) {
      throw const UnauthorizedFailure('PIN incorrect.');
    }

    if (_remote != null &&
        await _networkInfo.isConnected &&
        await _credentials.hasValidAccessToken()) {
      try {
        await _remote!.enableBiometric(pin: pin);
      } on Failure {
        rethrow;
      } catch (_) {
        // Session cloud absente : activation locale uniquement.
      }
    }

    final timestamp = nowMs();
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(
        biometricEnabled: const Value(true),
        updatedAt: Value(timestamp),
        version: Value(user.version + 1),
      ),
    );

    await _patchStoredUserBiometric(sessionToken, enabled: true);
    return true;
  }

  @override
  Future<bool> disableBiometric({
    required int userId,
    required String sessionToken,
    required String pin,
  }) async {
    final session = await (_db.select(_db.authSessions)
          ..where((s) => s.id.equals(sessionToken)))
        .getSingleOrNull();

    if (session == null ||
        session.userId != userId ||
        session.expiresAt <= nowMs()) {
      throw const UnauthorizedFailure('Session invalide ou expirée.');
    }

    final user = await (_db.select(_db.users)
          ..where(
            (u) => u.id.equals(userId) & u.shopId.equals(session.shopId),
          ))
        .getSingleOrNull();

    if (user == null) {
      throw const UnauthorizedFailure('Utilisateur introuvable.');
    }

    final pinVo = Pin.create(pin);
    if (!_pinHasher.compare(pinVo.value, user.pinHash)) {
      throw const UnauthorizedFailure('PIN incorrect.');
    }

    final timestamp = nowMs();
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(
        biometricEnabled: const Value(false),
        updatedAt: Value(timestamp),
        version: Value(user.version + 1),
      ),
    );

    await _patchStoredUserBiometric(sessionToken, enabled: false);
    return true;
  }

  @override
  Future<void> changePin({
    required int userId,
    required int shopId,
    required String currentPin,
    required String newPin,
  }) async {
    if (currentPin == newPin) {
      throw const ValidationFailure(
        'Le nouveau PIN doit être différent de l\'actuel.',
      );
    }

    final current = Pin.create(currentPin);
    final next = Pin.create(newPin);

    final user = await (_db.select(_db.users)
          ..where(
            (u) => u.id.equals(userId) & u.shopId.equals(shopId),
          ))
        .getSingleOrNull();
    if (user == null) {
      throw const NotFoundFailure('Utilisateur introuvable.');
    }
    if (!_pinHasher.compare(current.value, user.pinHash)) {
      throw const UnauthorizedFailure('PIN actuel incorrect.');
    }

    final timestamp = nowMs();
    final newHash = _pinHasher.hash(next.value);
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        pinHash: Value(newHash),
        pinProvisional: const Value(false),
        updatedAt: Value(timestamp),
        version: Value(user.version + 1),
      ),
    );

    await _db.into(_db.auditLogs).insert(
          AuditLogsCompanion.insert(
      shopId: shopId,
            userId: userId,
            action: 'pin_changed',
            module: 'auth',
            entityId: userId,
            entityTable: 'users',
            createdAt: timestamp,
          ),
    );
  }

  @override
  Future<void> touchSession({
    required String sessionToken,
    required int shopId,
  }) async {
    final session = await (_db.select(_db.authSessions)
          ..where(
            (s) => s.id.equals(sessionToken) & s.shopId.equals(shopId),
          ))
        .getSingleOrNull();

    if (session == null) {
      throw const UnauthorizedFailure('Session invalide.');
    }
    if (session.expiresAt <= nowMs()) {
      throw const UnauthorizedFailure('Session expirée.');
    }

    final timestamp = nowMs();
    final newExpiry = timestamp + ApiConfig.localSessionMaxMs;

    await (_db.update(_db.authSessions)..where((s) => s.id.equals(sessionToken)))
        .write(
      AuthSessionsCompanion(
        lastActivityAt: Value(timestamp),
        expiresAt: Value(newExpiry),
      ),
    );

    await _sessionStorage.saveSession(
      sessionToken: sessionToken,
      expiresAt: newExpiry,
      user: (await _sessionStorage.getUser()) ?? {},
    );

    if (_remote != null && await _networkInfo.isConnected) {
      try {
        await _remote!.touchSession();
      } on Object {
        // Prolongation locale conservée hors ligne.
      }
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final token = await _sessionStorage.getSessionToken();
    final userJson = await _sessionStorage.getUser();

    if (token == null || userJson == null) {
      return null;
    }

    var dbSession = await (_db.select(_db.authSessions)
          ..where((s) => s.id.equals(token)))
        .getSingleOrNull();

    if (dbSession == null) {
      return null;
    }

    var expiresAt = await _sessionStorage.getSessionExpiresAt();
    final sessionExpired =
        expiresAt == null ||
        expiresAt <= nowMs() ||
        dbSession.expiresAt <= nowMs();

    if (sessionExpired) {
      await _renewLocalSession(token: token, shopId: dbSession.shopId);
      expiresAt = await _sessionStorage.getSessionExpiresAt();
      dbSession = await (_db.select(_db.authSessions)
            ..where((s) => s.id.equals(token)))
          .getSingle();
    }

    final shopId = dbSession.shopId;

    final shop = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(shopId)))
        .getSingleOrNull();

    if (shop == null) {
      await logout();
      return null;
    }

    if (_isOnlineMode && await _networkInfo.isConnected) {
      // Déverrouillage/restauration instantané : le rafraîchissement de la
      // session en ligne s'exécute en arrière-plan pour ne JAMAIS bloquer l'UI.
      // Le PIN ne fait que valider ; la session locale est déjà ouverte et la
      // synchro cloud peut se faire ensuite sans laisser l'écran sur un loader
      // (serveur lent, refresh token rejeté, dialogue de reconnexion…).
      unawaited(_refreshOnlineSessionAfterRestore(shopId));
    }

    final settings = await _getSettings(shopId);
    final role = UserRole.fromCode(userJson['role'] as String? ?? 'owner');
    final permissions = await _resolvePermissions(role);

    final profile = await _credentials.getProfile();
    final profileShopId = profile?['shopId'];
    if (profileShopId is int) {
      _activeShop.setServerShopId(profileShopId);
    } else {
      await _syncActiveShopFromLocal(shopId);
    }

    final serverUserId = profile?['id'] as int?;
    final localShop = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(shopId)))
        .getSingle();
    final serverShopId = _parseServerId(localShop.serverId) ?? profileShopId as int?;

    return AuthSession(
      token: token,
      expiresAt: dbSession.expiresAt,
      autoLockMinutes: settings.autoLockMinutes,
      shop: AuthShop(
        id: localShop.id,
        name: localShop.name,
        serverShopId: serverShopId,
      ),
      user: AuthUser(
        id: userJson['id'] as int,
        name: userJson['name'] as String,
        role: role,
        roleLabel: role.label,
        shopId: shopId,
        biometricEnabled: userJson['biometricEnabled'] as bool? ?? false,
        lastLoginAt: userJson['lastLoginAt'] as int?,
        permissions: permissions,
        serverUserId: serverUserId,
      ),
    );
  }

  @override
  Future<bool> hasRestorableSession() async {
    final token = await _sessionStorage.getSessionToken();
    if (token == null) return false;

    final dbSession = await (_db.select(_db.authSessions)
          ..where((s) => s.id.equals(token)))
        .getSingleOrNull();
    return dbSession != null;
  }

  @override
  Future<AuthSession> unlockWithPin({
    required String pin,
    required int shopId,
    int? userId,
  }) async {
    final serverShopId = await _resolveServerShopId(shopId);
    final localShopId = await _resolveLocalShopId(serverShopId);

    final localUsers = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(localShopId) & u.isActive.equals(true)))
        .get();

    if (localUsers.isNotEmpty) {
      try {
        final user = await _verifyPinForUser(
          pin: pin,
          shopId: localShopId,
          userId: userId,
        );
        if (await hasRestorableSession()) {
          return _openSessionAfterLocalUnlock(
            user: user,
            localShopId: localShopId,
            serverShopId: serverShopId,
            pin: pin,
          );
        }
        final session = await _loginWithPinLocal(
          pin: pin,
          shopId: localShopId,
          userId: user.id,
        );
        if (_remote != null && await _networkInfo.isConnected) {
          unawaited(
            _refreshOnlineCredentialsAfterLocalPin(
              pin: pin,
              shopId: serverShopId,
              localShopId: localShopId,
              userId: user.id,
            ),
          );
        }
        return session;
      } on InvalidPinFailure {
        // Idem : bascule serveur uniquement pour un PIN provisoire.
        if (await _isPinProvisional(localShopId: localShopId, userId: userId)) {
          if (_remote != null && await _networkInfo.isConnected) {
            return _loginWithPinOnline(
              pin: pin,
              serverShopId: serverShopId,
              userId: userId,
            );
          }
          throw const NetworkFailure(
            'Connexion internet requise pour valider ce PIN la première fois '
            'sur cet appareil.',
          );
        }
        rethrow;
      }
    }

    return loginWithPin(pin: pin, shopId: shopId, userId: userId);
  }

  @override
  Future<AuthSession> unlockWithBiometric({
    required int shopId,
    int? userId,
  }) async {
    final serverShopId = await _resolveServerShopId(shopId);
    final localShopId = await _resolveLocalShopId(serverShopId);

    if (await hasRestorableSession()) {
      final user = await _resolveUser(shopId: localShopId, userId: userId);
      if (!user.biometricEnabled) {
        throw const UnauthorizedFailure(
          'Biométrie non activée pour cet utilisateur.',
        );
      }

    final lockState = _lockoutPolicy.evaluate(
      lockedUntil: user.lockedUntil,
      lockoutCount: user.lockoutCount,
    );
    if (lockState.isLocked) {
      throw AccountLockedFailure(
        lockedUntil: lockState.lockedUntil!,
        remainingSeconds: lockState.remainingSeconds,
      );
    }
    if (lockState.requiresEmergencyRecovery) {
      throw const EmergencyRecoveryRequiredFailure();
    }

      final session = await _openSessionAfterLocalUnlock(
        user: user,
        localShopId: localShopId,
        serverShopId: serverShopId,
      );
      return session;
    }

    return loginWithBiometric(shopId: shopId, userId: userId);
  }

  /// Rouvre la session locale après PIN/biométrie. Recrée la session SQLite si
  /// elle a été effacée au verrouillage, sans repasser par le serveur.
  Future<AuthSession> _openSessionAfterLocalUnlock({
    required User user,
    required int localShopId,
    required int serverShopId,
    String? pin,
  }) async {
    final session = await restoreSession();
    if (session != null && session.user.id == user.id) {
      if (pin != null && _remote != null && await _networkInfo.isConnected) {
        unawaited(
          _refreshOnlineCredentialsAfterLocalPin(
            pin: pin,
            shopId: serverShopId,
            localShopId: localShopId,
            userId: user.id,
          ),
        );
      } else if (_remote != null && await _networkInfo.isConnected) {
        unawaited(_ensureOnlineSessionAfterUnlock(localShopId));
      }
      return session;
    }

    final settings = await _getSettings(localShopId);
    final permissions =
        await _resolvePermissions(UserRole.fromCode(user.role));
    final recreated = await _createSession(
      user: user,
      settings: settings,
      shopId: localShopId,
      permissions: permissions,
    );
    if (pin != null && _remote != null && await _networkInfo.isConnected) {
      unawaited(
        _refreshOnlineCredentialsAfterLocalPin(
          pin: pin,
          shopId: serverShopId,
          localShopId: localShopId,
          userId: user.id,
        ),
      );
    }
    return recreated;
  }

  int? _parseServerId(String? serverId) {
    if (serverId == null || serverId.isEmpty) return null;
    return int.tryParse(serverId);
  }

  Future<void> _syncActiveShopFromLocal(int localShopId) async {
    final shop = await (_db.select(_db.shops)..where((s) => s.id.equals(localShopId)))
        .getSingleOrNull();
    final serverId = _parseServerId(shop?.serverId);
    if (serverId != null) {
      _activeShop.setServerShopId(serverId);
    }
  }

  Future<void> _patchStoredUserBiometric(
    String sessionToken, {
    required bool enabled,
  }) async {
    final userJson = await _sessionStorage.getUser();
    final expiresAt = await _sessionStorage.getSessionExpiresAt();
    if (userJson == null || expiresAt == null) return;
    userJson['biometricEnabled'] = enabled;
    await _sessionStorage.saveSession(
      sessionToken: sessionToken,
      expiresAt: expiresAt,
      user: userJson,
    );
  }

  Future<void> _ensureOnlineSessionAfterUnlock(int localShopId) async {
    if (_remote == null || !await _networkInfo.isConnected) return;

    await _syncActiveShopFromLocal(localShopId);
    await _cloudSyncEnabler?.activateForShop(localShopId);

    if (!await _credentials.hasCredentials()) return;

    final repair = _cloudSessionRepair;
    if (repair != null) {
      final outcome = await repair.repair(attemptRefresh: true);
      if (outcome == CloudRepairOutcome.alreadyValid ||
          outcome == CloudRepairOutcome.refreshed ||
          outcome == CloudRepairOutcome.pinLogin) {
        _onOnlineSessionReady?.call(localShopId);
      }
      return;
    }

    if (!await _credentials.hasValidAccessToken() &&
        await _credentials.hasValidRefreshToken()) {
      try {
        await _apiClient?.refreshTokensIfNeeded();
      } on Object {
        // Refresh transitoire — prochain cycle sync retentera.
      }
    }

    if (await _credentials.hasValidAccessToken()) {
      _onOnlineSessionReady?.call(localShopId);
    }
  }

  /// Rafraîchit la session en ligne après une restauration/déverrouillage
  /// **sans bloquer** le retour de [restoreSession]. Toute erreur réseau est
  /// avalée : la session locale reste ouverte et la synchro retentera plus tard.
  Future<void> _refreshOnlineSessionAfterRestore(int shopId) async {
    try {
      if (await _credentials.hasCredentials()) {
        if (!await _credentials.hasValidAccessToken() &&
            await _credentials.hasValidRefreshToken()) {
          try {
            await _apiClient?.refreshTokensIfNeeded();
          } on Object {
            // Refresh transitoire — travail offline conservé.
          }
        }

        if (!await _credentials.hasValidAccessToken() &&
            !await _credentials.hasValidRefreshToken()) {
          await _credentials.clear();
        }
      }

      await _ensureOnlineSessionAfterUnlock(shopId);
    } on Object {
      // Session locale déjà ouverte ; la synchro API peut attendre.
    }
  }

  Future<void> _renewLocalSession({
    required String token,
    required int shopId,
  }) async {
    final settings = await _getSettings(shopId);
    final userJson = await _sessionStorage.getUser();
    if (userJson == null) return;

    final newExpiry = nowMs() + ApiConfig.localSessionMaxMs;
    await (_db.update(_db.authSessions)..where((s) => s.id.equals(token))).write(
      AuthSessionsCompanion(expiresAt: Value(newExpiry)),
    );
    await _sessionStorage.saveSession(
      sessionToken: token,
      expiresAt: newExpiry,
      user: userJson,
    );
  }

  @override
  Future<void> lockActiveSession() async {
    _recentPinProof.clear();
    _cloudSessionRepair?.clearAwaitingState();
    final token = await _sessionStorage.getSessionToken();
    if (token != null) {
      await (_db.delete(_db.authSessions)..where((s) => s.id.equals(token)))
          .go();
    }
    await _sessionStorage.clear();
  }

  @override
  Future<void> logout() async {
    if (_remote != null && await _networkInfo.isConnected) {
      try {
        await _remote!.logout().timeout(const Duration(seconds: 5));
      } on Object {
        // Déconnexion locale même si l'API est injoignable.
      }
    }
    await lockActiveSession();
    await _credentials.clear();
    _activeShop.clear();
    _recentPinProof.clear();
    _cloudSessionRepair?.clearAwaitingState();
    await _authFlow?.markLoggedOut();
    await _onSessionEnded?.call();
  }

  @override
  Future<OwnedShopList> listOwnedShops() async {
    try {
      if (_remote == null) {
        return _listOwnedShopsLocally();
      }
      if (!await _networkInfo.isConnected) {
        return _listOwnedShopsLocally();
      }

      final dto = await _remote!.listOwnedShops().timeout(
        ApiConfig.ownedShopsRemoteTimeout,
      );
      await _syncOwnedShopsFromApi(dto.shops);
      return OwnedShopList(
        activeShopId: dto.activeShopId,
        shops: dto.shops
            .map(
              (shop) => OwnedShop(
                id: shop.id,
                name: shop.name,
                address: shop.address,
                phone: shop.phone,
                isActive: shop.isActive,
                isDefault: shop.isDefault,
                isCurrent: shop.isCurrent,
              ),
            )
            .toList(),
      );
    } on Failure {
      return _listOwnedShopsLocally();
    } catch (_) {
      return _listOwnedShopsLocally();
    }
  }

  Future<OwnedShopList> _listOwnedShopsLocally() async {
    final rows = await (_db.select(_db.shops)
          ..orderBy([(s) => OrderingTerm.desc(s.isDefault)]))
        .get();

    if (rows.isEmpty) {
      throw const NetworkFailure(
        'Aucune boutique locale. Connectez-vous au cloud ou créez une boutique.',
      );
    }

    final contextShopId = await _resolveContextLocalShopId();
    final groupIds = ShopHierarchy.groupShopIds(rows, contextShopId).toSet();
    final filtered = rows.where((row) => groupIds.contains(row.id)).toList();

    final shops = filtered.map((row) {
      final serverId = int.tryParse(row.serverId ?? '') ?? row.id;
      return OwnedShop(
        id: serverId,
        name: row.name,
        address: row.address,
        phone: row.phone,
        isActive: row.isActive,
        isDefault: row.isDefault,
        isCurrent: row.id == contextShopId,
      );
    }).toList();

    Shop activeRow;
    try {
      activeRow = filtered.firstWhere((row) => row.id == contextShopId);
    } on StateError {
      activeRow = filtered.first;
    }
    final activeId =
        int.tryParse(activeRow.serverId ?? '') ?? activeRow.id;
    return OwnedShopList(activeShopId: activeId, shops: shops);
  }

  Future<int> _resolveContextLocalShopId() async {
    final token = await _sessionStorage.getSessionToken();
    if (token != null) {
      final session = await (_db.select(_db.authSessions)
            ..where((s) => s.id.equals(token)))
          .getSingleOrNull();
      if (session != null) return session.shopId;
    }

    final defaultShop = await (_db.select(_db.shops)
          ..where((s) => s.isDefault.equals(true)))
        .getSingleOrNull();
    return defaultShop?.id ?? 1;
  }

  Future<void> _syncOwnedShopsFromApi(List<OwnedShopItemDto> shops) async {
    final ownerUserId = await (_db.select(_db.users)
          ..where((u) => u.role.equals('owner')))
        .getSingleOrNull()
        .then((user) => user?.id);

    for (final shop in shops) {
      final localParentId = await _resolveLocalParentShopId(shop.parentShopId);
      final existing = await (_db.select(_db.shops)
            ..where((s) => s.serverId.equals('${shop.id}')))
          .getSingleOrNull();
      final timestamp = nowMs();

      if (existing == null) {
        await _db.into(_db.shops).insert(
              ShopsCompanion.insert(
                name: Value(shop.name),
                address: Value(shop.address),
                phone: Value(shop.phone),
                isActive: Value(shop.isActive),
                isDefault: Value(shop.isDefault),
                parentShopId: localParentId == null
                    ? const Value.absent()
                    : Value(localParentId),
                createdAt: timestamp,
                ownerUserId: ownerUserId == null
                    ? const Value.absent()
                    : Value(ownerUserId),
                serverId: Value('${shop.id}'),
                syncedAt: Value(timestamp),
              ),
            );
        continue;
      }

      await (_db.update(_db.shops)..where((s) => s.id.equals(existing.id))).write(
        ShopsCompanion(
          name: Value(shop.name),
          address: Value(shop.address),
          phone: Value(shop.phone),
          isActive: Value(shop.isActive),
          isDefault: Value(shop.isDefault),
          parentShopId: localParentId == null
              ? const Value.absent()
              : Value(localParentId),
          ownerUserId: existing.ownerUserId == null && ownerUserId != null
              ? Value(ownerUserId)
              : const Value.absent(),
          syncedAt: Value(timestamp),
        ),
      );
    }
  }

  Future<int?> _resolveLocalParentShopId(int? serverParentShopId) async {
    if (serverParentShopId == null) return null;

    final byServer = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('$serverParentShopId')))
        .getSingleOrNull();
    if (byServer != null) return byServer.id;

    final byId = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(serverParentShopId)))
        .getSingleOrNull();
    return byId?.id;
  }

  @override
  Future<AuthSession> switchShop({required int shopId}) async {
    if (_remote == null || !await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Connexion internet requise pour changer de boutique.',
      );
    }

    final token = await _sessionStorage.getSessionToken();
    if (token == null) {
      throw const UnauthorizedFailure('Session introuvable.');
    }

    final dbSession = await (_db.select(_db.authSessions)
          ..where((s) => s.id.equals(token)))
        .getSingleOrNull();
    if (dbSession == null) {
      throw const UnauthorizedFailure('Session expirée.');
    }

    final result = await _remote!.switchShop(shopId: shopId);
    return _applyShopSwitch(
      sessionToken: token,
      userId: dbSession.userId,
      expiresAt: dbSession.expiresAt,
      result: result,
    );
  }

  @override
  Future<WhatsappOtpRequestResult> requestWhatsappOtp({
    required String phone,
  }) async {
    if (_remote == null || !await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Connexion internet requise pour recevoir le code WhatsApp.',
      );
    }
    if (!isValidPhone(phone)) {
      throw const ValidationFailure(
        'Numéro WhatsApp invalide. Utilisez le format 01XXXXXXXX (10 chiffres) ou +229…',
      );
    }
    final normalized = normalizePhone(phone);
    final dto = await _remote!.requestWhatsappOtp(phone: normalized);
    return WhatsappOtpRequestResult(
      maskedPhone: dto.maskedPhone,
      expiresInSeconds: dto.expiresInSeconds,
      message: dto.message,
      deliveryChannel: dto.deliveryChannel,
      deliveryWarning: dto.deliveryWarning,
      devCode: dto.devCode,
    );
  }

  @override
  Future<WhatsappOtpVerifyResult> verifyWhatsappOtp({
    required String phone,
    required String code,
  }) async {
    if (_remote == null || !await _networkInfo.isConnected) {
      throw const NetworkFailure('Connexion internet requise.');
    }
    if (!isValidPhone(phone)) {
      throw const ValidationFailure(
        'Numéro WhatsApp invalide. Vérifiez le numéro saisi.',
      );
    }
    final trimmedCode = code.trim();
    if (trimmedCode.length < 4) {
      throw const ValidationFailure('Le code doit contenir au moins 4 chiffres.');
    }
    final normalized = normalizePhone(phone);
    final dto = await _remote!.verifyWhatsappOtp(phone: normalized, code: trimmedCode);
    return WhatsappOtpVerifyResult(
      verificationToken: dto.verificationToken,
      memberships: dto.memberships
          .map(
            (m) => AuthMembership(
              userId: m.userId,
              shopId: m.shopId,
              shopName: m.shopName,
              role: UserRole.fromCode(m.role),
              roleLabel: m.roleLabel,
              isDefault: m.isDefault,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<AuthSession> completeWhatsappLogin({
    required String verificationToken,
    required int shopId,
    required int userId,
  }) async {
    if (_remote == null || !await _networkInfo.isConnected) {
      throw const NetworkFailure('Connexion internet requise.');
    }
    final device = await _deviceIds.getAuthDevice();
    final result = await _remote!.completeWhatsappLogin(
      verificationToken: verificationToken,
      shopId: shopId,
      userId: userId,
      deviceId: device.deviceId,
      deviceLabel: device.deviceLabel,
    );
    return _finalizeOnlineLogin(result);
  }

  @override
  Future<List<DeviceSession>> listDeviceSessions({bool shopScope = false}) async {
    if (_remote == null) {
      throw NetworkFailure(ProductionMessagePolicy.onlineRequiredMessage());
    }
    if (!await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Hors ligne — impossible de lister les appareils connectés.',
      );
    }
    if (!await _credentials.hasValidAccessToken() &&
        await _credentials.hasValidRefreshToken()) {
      try {
        await _apiClient?.refreshTokensIfNeeded();
      } on Object {
        // Refresh transitoire.
      }
    }
    final sessions = await _remote!.listDevices(shopScope: shopScope);
    return sessions
        .map(
          (s) => DeviceSession(
            id: s.id,
            userId: s.userId,
            userName: s.userName,
            deviceId: s.deviceId,
            deviceLabel: s.deviceLabel,
            lastSeenAt: s.lastSeenAt,
            sessionExpiresAt: s.sessionExpiresAt,
            refreshExpiresAt: s.refreshExpiresAt,
            isCurrent: s.isCurrent,
          ),
        )
        .toList();
  }

  @override
  Future<void> revokeDeviceSession(String sessionId) async {
    if (_remote == null) {
      throw NetworkFailure(ProductionMessagePolicy.onlineRequiredMessage());
    }
    if (!await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Hors ligne — impossible de révoquer cet appareil.',
      );
    }
    if (!await _credentials.hasValidAccessToken() &&
        await _credentials.hasValidRefreshToken()) {
      try {
        await _apiClient?.refreshTokensIfNeeded();
      } on Object {
        // Refresh transitoire.
      }
    }
    await _remote!.revokeDevice(sessionId);
  }

  Future<AuthSession> _applyShopSwitch({
    required String sessionToken,
    required int userId,
    required int expiresAt,
    required SwitchShopDataDto result,
  }) async {
    final localShopId = await _resolveLocalShopId(
      result.shop.id,
      shopName: result.shop.name,
    );

    await (_db.update(_db.shops)..where((s) => s.id.equals(localShopId))).write(
      ShopsCompanion(
        name: Value(result.shop.name),
        syncedAt: Value(nowMs()),
      ),
    );

    final settings = await _getSettings(localShopId);
    await (_db.update(_db.settings)..where((s) => s.shopId.equals(localShopId)))
        .write(
      SettingsCompanion(
        shopName: Value(result.shop.name),
        updatedAt: Value(nowMs()),
      ),
    );

    await (_db.update(_db.authSessions)..where((s) => s.id.equals(sessionToken)))
        .write(AuthSessionsCompanion(shopId: Value(localShopId)));

    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(shopId: Value(localShopId)),
    );

    final user = await (_db.select(_db.users)..where((u) => u.id.equals(userId)))
        .getSingle();

    final userJson = await _sessionStorage.getUser();
    if (userJson != null) {
      userJson['shopId'] = localShopId;
      await _sessionStorage.saveSession(
        sessionToken: sessionToken,
        expiresAt: expiresAt,
        user: userJson,
      );
    }

    if (_isOnlineMode) {
      await _credentials.updateProfileShopId(result.activeShopId);
      _activeShop.setServerShopId(result.activeShopId);
    }

    final permissions = await _resolvePermissions(UserRole.fromCode(user.role));
    final profile = await _credentials.getProfile();

    return AuthSession(
      token: sessionToken,
      expiresAt: expiresAt,
      autoLockMinutes: settings.autoLockMinutes,
      shop: AuthShop(
        id: localShopId,
        name: result.shop.name,
        serverShopId: result.activeShopId,
      ),
      user: AuthUser(
        id: user.id,
        name: user.name,
        role: UserRole.fromCode(user.role),
        roleLabel: UserRole.fromCode(user.role).label,
        shopId: localShopId,
        biometricEnabled: user.biometricEnabled,
        lastLoginAt: user.lastLoginAt,
        permissions: permissions,
        serverUserId: profile?['id'] as int? ?? _parseServerId(user.serverId),
      ),
    );
  }

  Future<AuthSession> _finalizeOnlineLogin(
    LoginSuccessData result, {
    String? pin,
  }) async {
    await _ensureCleanSlateForUserChange(result.user.id);

    final localUser = await _persistOnlineLoginResult(result, pin: pin);

    final localShopId = await _resolveLocalShopId(
      result.shop.id,
      shopName: result.shop.name,
    );
    final settings = await _getSettings(localShopId);
    await (_db.update(_db.settings)..where((s) => s.shopId.equals(localShopId)))
        .write(
      SettingsCompanion(
        shopName: Value(result.shop.name),
        updatedAt: Value(nowMs()),
      ),
    );
    final permissions = resolveSessionPermissions(
      apiCodes: result.user.permissions,
      role: UserRole.fromCode(result.user.role),
    );

    return _createSession(
      user: localUser,
      settings: settings,
      shopId: localShopId,
      shopName: result.shop.name,
      permissions: permissions,
      roleLabel: result.user.roleLabel,
      serverUserId: result.user.id,
      serverShopId: result.shop.id,
    );
  }

  Future<void> _persistSetupLocally({
    required SetupOwnerData apiResult,
    required String ownerName,
    required String shopName,
    required String pin,
    required String ownerPhone,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final serverUserId = '${apiResult.userId}';
    final serverShopId = '${apiResult.shopId}';

    final existingUser = await (_db.select(_db.users)
          ..where((u) => u.serverId.equals(serverUserId)))
        .getSingleOrNull();
    if (existingUser != null) {
      return;
    }

    final existingOwners = await (_db.select(_db.users)
          ..where((u) => u.role.equals('owner')))
        .get();
    if (existingOwners.isNotEmpty) {
      await _clearOrphanLocalAuthData();
    }

    final pinHash = _pinHasher.hash(Pin.create(pin).value);
    final recoveryHash = _pinHasher.hash(apiResult.recoveryToken);
    final timestamp = nowMs();

    await _db.transaction(() async {
      final existingShop = await (_db.select(_db.shops)
            ..where((s) => s.serverId.equals(serverShopId)))
          .getSingleOrNull();

      final shopId = existingShop?.id ??
          await _db.into(_db.shops).insert(
                ShopsCompanion.insert(
                  name: Value(shopName),
                  address: Value(shopAddress),
                  phone: Value(shopPhone),
                  createdAt: timestamp,
                  serverId: Value(serverShopId),
                  syncedAt: Value(timestamp),
                ),
              );

      final userId = await _db.into(_db.users).insert(
            UsersCompanion.insert(
              shopId: shopId,
              name: ownerName,
              pinHash: pinHash,
              role: const Value('owner'),
              emergencyRecoveryHash: Value(recoveryHash),
              createdAt: timestamp,
              updatedAt: timestamp,
              serverId: Value(serverUserId),
              syncedAt: Value(timestamp),
            ),
          );

      await (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
        ShopsCompanion(ownerUserId: Value(userId)),
      );

      final settings = await (_db.select(_db.settings)
            ..where((s) => s.shopId.equals(shopId)))
          .getSingleOrNull();

      if (settings == null) {
        await _db.into(_db.settings).insert(
              SettingsCompanion.insert(
                shopId: shopId,
                shopName: Value(shopName),
                shopPhone: Value(shopPhone),
                shopAddress: Value(shopAddress),
                autoLockMinutes: const Value(5),
                updatedAt: timestamp,
              ),
            );
      } else {
        await (_db.update(_db.settings)..where((s) => s.shopId.equals(shopId)))
            .write(
          SettingsCompanion(
            shopName: Value(shopName),
            shopPhone: Value(shopPhone),
            shopAddress: Value(shopAddress),
            updatedAt: Value(timestamp),
          ),
        );
      }
    });
  }

  Future<SetupOwnerResult> _setupOwnerLocal({
    required String ownerName,
    required String shopName,
    required String pin,
    String? shopAddress,
    String? shopPhone,
  }) async {
    await _prepareForOwnerSetup();

    final pinVo = Pin.create(pin);
    final pinHash = _pinHasher.hash(pinVo.value);
    final recovery = _recoveryTokenService.generate();
    final timestamp = nowMs();

    return _db.transaction(() async {
      final shopId = await _db.into(_db.shops).insert(
            ShopsCompanion.insert(
              name: Value(shopName),
              address: Value(shopAddress),
              phone: Value(shopPhone),
              createdAt: timestamp,
            ),
          );

      final userId = await _db.into(_db.users).insert(
            UsersCompanion.insert(
              shopId: shopId,
              name: ownerName,
              pinHash: pinHash,
              role: const Value('owner'),
              emergencyRecoveryHash: Value(recovery.hash),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );

      await (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
        ShopsCompanion(ownerUserId: Value(userId)),
      );

      await _db.into(_db.settings).insert(
            SettingsCompanion.insert(
              shopId: shopId,
              shopName: Value(shopName),
              shopPhone: Value(shopPhone),
              shopAddress: Value(shopAddress),
              autoLockMinutes: const Value(5),
              updatedAt: timestamp,
            ),
          );

      return SetupOwnerResult(
        shopId: shopId,
        userId: userId,
        recoveryToken: recovery.token,
        message:
            'Installation réussie. Sauvegardez le fichier de récupération d\'urgence en lieu sûr.',
      );
    }).then((result) async {
      await _authFlow?.clearLoggedOut();
      return result;
    });
  }

  Future<AuthSession> _loginWithPinLocal({
    required String pin,
    required int shopId,
    int? userId,
  }) async {
    final updatedUser = await _verifyPinForUser(
      pin: pin,
      shopId: shopId,
      userId: userId,
    );
    final settings = await _getSettings(shopId);
    final permissions =
        await _resolvePermissions(UserRole.fromCode(updatedUser.role));

    return _createSession(
      user: updatedUser,
      settings: settings,
      shopId: shopId,
      permissions: permissions,
    );
  }

  Future<User> _verifyPinForUser({
    required String pin,
    required int shopId,
    int? userId,
  }) async {
    final pinVo = Pin.create(pin);
    final user = await _resolveUser(shopId: shopId, userId: userId);

    final lockState = _lockoutPolicy.evaluate(
      lockedUntil: user.lockedUntil,
      lockoutCount: user.lockoutCount,
    );

    if (lockState.isLocked) {
      throw AccountLockedFailure(
        lockedUntil: lockState.lockedUntil!,
        remainingSeconds: lockState.remainingSeconds,
      );
    }

    if (lockState.requiresEmergencyRecovery) {
      throw const EmergencyRecoveryRequiredFailure();
    }

    if (!_pinHasher.compare(pinVo.value, user.pinHash)) {
      if (user.pinProvisional) {
        // Hash local encore provisoire (post-WhatsApp sur nouvel appareil) :
        // ne pas pénaliser localement, le serveur reste l'autorité du PIN.
        throw const InvalidPinFailure(0);
      }
      await _handleFailedAttempt(user);
    }

    final loginAt = nowMs();
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(
        failedAttempts: const Value(0),
        lockedUntil: Value<int?>(null),
        lockoutCount: const Value(0),
        lastLoginAt: Value(loginAt),
        updatedAt: Value(loginAt),
        version: Value(user.version + 1),
      ),
    );

    return user.copyWith(
      failedAttempts: 0,
      lockedUntil: const Value(null),
      lockoutCount: 0,
      lastLoginAt: Value(loginAt),
      version: user.version + 1,
    );
  }

  Future<void> _resetUserLockout(
    User user, {
    String reason = 'Déblocage d\'urgence',
  }) async {
    final timestamp = nowMs();
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(
        failedAttempts: const Value(0),
        lockedUntil: Value<int?>(null),
        lockoutCount: const Value(0),
        updatedAt: Value(timestamp),
        version: Value(user.version + 1),
      ),
    );

    await _db.into(_db.auditLogs).insert(
          AuditLogsCompanion.insert(
            shopId: user.shopId,
            userId: user.id,
            action: 'emergency_unlock',
            module: 'settings',
            entityId: user.id,
            entityTable: 'users',
            oldValue: Value(
              jsonEncode({
                'failed_attempts': user.failedAttempts,
                'locked_until': user.lockedUntil,
                'lockout_count': user.lockoutCount,
              }),
            ),
            newValue: const Value(
              '{"failed_attempts":0,"locked_until":null,"lockout_count":0}',
            ),
            reason: Value(reason),
            createdAt: timestamp,
          ),
        );
  }

  Future<AuthSession> _loginWithBiometricLocal({
    required int shopId,
    int? userId,
  }) async {
    final user = await _resolveUser(shopId: shopId, userId: userId);
    if (!user.biometricEnabled) {
      throw const UnauthorizedFailure('Biométrie non activée pour cet utilisateur.');
    }

    final settings = await _getSettings(shopId);
    final lockState = _lockoutPolicy.evaluate(
      lockedUntil: user.lockedUntil,
      lockoutCount: user.lockoutCount,
    );

    if (lockState.isLocked) {
      throw AccountLockedFailure(
        lockedUntil: lockState.lockedUntil!,
        remainingSeconds: lockState.remainingSeconds,
      );
    }

    if (lockState.requiresEmergencyRecovery) {
      throw const EmergencyRecoveryRequiredFailure();
    }

    final loginAt = nowMs();
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(
        lastLoginAt: Value(loginAt),
        updatedAt: Value(loginAt),
        version: Value(user.version + 1),
          ),
        );

    final updatedUser = user.copyWith(
      lastLoginAt: Value(loginAt),
      version: user.version + 1,
    );

    final permissions = await _resolvePermissions(UserRole.fromCode(user.role));

    return _createSession(
      user: updatedUser,
      settings: settings,
      shopId: shopId,
      permissions: permissions,
    );
  }

  Future<AuthSession> _emergencyUnlockLocal({
    required String recoveryToken,
    required int shopId,
    int? userId,
  }) async {
    final user = await _resolveUser(shopId: shopId, userId: userId);
    final settings = await _getSettings(shopId);

    if (user.emergencyRecoveryHash == null) {
      throw const UnauthorizedFailure(
        'Aucun fichier de récupération configuré.',
      );
    }

    if (!_pinHasher.compare(recoveryToken, user.emergencyRecoveryHash!)) {
      throw const UnauthorizedFailure('Fichier de récupération invalide.');
    }

    await _resetUserLockout(
      user,
      reason: 'Déblocage via fichier de récupération d\'urgence',
    );

    final updatedUser = user.copyWith(
      failedAttempts: 0,
      lockedUntil: const Value(null),
      lockoutCount: 0,
      version: user.version + 1,
    );

    final permissions = await _resolvePermissions(UserRole.fromCode(user.role));

    return _createSession(
      user: updatedUser,
      settings: settings,
      shopId: shopId,
      permissions: permissions,
    );
  }

  Future<User> _upsertLocalUserFromApi(
    AuthUserData apiUser, {
    String? pin,
    String? shopName,
  }) async {
    final localShopId =
        await _resolveLocalShopId(apiUser.shopId, shopName: shopName);

    final existing = await (_db.select(_db.users)
          ..where(
            (u) =>
                u.shopId.equals(localShopId) &
                (u.serverId.equals('${apiUser.id}') |
                    u.name.equals(apiUser.name)),
          ))
        .getSingleOrNull();

    final timestamp = nowMs();

    if (existing != null) {
      await (_db.update(_db.users)..where((u) => u.id.equals(existing.id))).write(
        UsersCompanion(
          name: Value(apiUser.name),
          role: Value(apiUser.role),
          biometricEnabled: Value(apiUser.biometricEnabled),
          lastLoginAt: Value(apiUser.lastLoginAt),
          pinHash: pin != null
              ? Value(_pinHasher.hash(Pin.create(pin).value))
              : const Value.absent(),
          // Un vrai PIN vient d'être enregistré → le hash n'est plus provisoire.
          pinProvisional:
              pin != null ? const Value(false) : const Value.absent(),
          updatedAt: Value(timestamp),
          version: Value(existing.version + 1),
          serverId: Value('${apiUser.id}'),
          syncedAt: Value(timestamp),
        ),
      );
      return (await (_db.select(_db.users)..where((u) => u.id.equals(existing.id)))
          .getSingle());
    }

    // Connexion WhatsApp sur nouvel appareil : hash provisoire jusqu'au premier
    // login PIN réussi (local échoue → validation serveur → hash mis à jour).
    final pinHash = pin != null
        ? _pinHasher.hash(Pin.create(pin).value)
        : _pinHasher.hash(_uuid.v4());

    final userId = await _db.into(_db.users).insert(
          UsersCompanion.insert(
            shopId: localShopId,
            name: apiUser.name,
            pinHash: pinHash,
            // Sans PIN fourni, le hash est aléatoire → provisoire.
            pinProvisional: Value(pin == null),
            role: Value(apiUser.role),
            biometricEnabled: Value(apiUser.biometricEnabled),
            lastLoginAt: Value(apiUser.lastLoginAt),
            createdAt: timestamp,
            updatedAt: timestamp,
            serverId: Value('${apiUser.id}'),
            syncedAt: Value(timestamp),
          ),
        );

    return (await (_db.select(_db.users)..where((u) => u.id.equals(userId)))
        .getSingle());
  }

  Future<void> _prepareForOwnerSetup() async {
    await _credentials.clear();
    _activeShop.clear();
    await _clearOrphanLocalAuthData();
  }

  Future<void> _clearOrphanLocalAuthData() async {
    await _sessionStorage.clear();
    await _db.transaction(() async {
      await _db.delete(_db.syncQueue).go();
      await _db.delete(_db.syncEntityCache).go();
      await _db.delete(_db.saleItems).go();
      await _db.delete(_db.sales).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.stockMovements).go();
      await _db.delete(_db.customerProductPrices).go();
      await _db.delete(_db.products).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.customers).go();
      await _db.delete(_db.expenseAttachments).go();
      await _db.delete(_db.expenseHistoryEntries).go();
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.expenseCategories).go();
      await _db.delete(_db.categoryBudgets).go();
      await _db.delete(_db.cashMovements).go();
      await _db.delete(_db.cashSessions).go();
      await _db.delete(_db.calculatorHistory).go();
      await _db.delete(_db.calculatorProductData).go();
      await _db.delete(_db.tenantModules).go();
      await _db.delete(_db.auditLogs).go();
      await _db.delete(_db.authSessions).go();
      await _db.delete(_db.users).go();
      await _db.delete(_db.settings).go();
      await _db.delete(_db.shops).go();
    });
  }

  /// Changement d'utilisateur sur l'appareil : efface les données locales de
  /// l'ancien compte avant d'importer le nouveau (flow §9).
  Future<void> _ensureCleanSlateForUserChange(int newServerUserId) async {
    final profile = await _credentials.getProfile();
    if (profile != null) {
      final previousId = profile['id'];
      if (previousId is int && previousId != newServerUserId) {
        await _wipeLocalDataForUserChange();
        return;
      }
    }

    final localUsers = await _db.select(_db.users).get();
    if (localUsers.isEmpty) return;

    final matchesNewUser = localUsers.any(
      (user) => user.serverId == '$newServerUserId',
    );
    if (!matchesNewUser) {
      await _wipeLocalDataForUserChange();
    }
  }

  Future<void> _wipeLocalDataForUserChange() async {
    await lockActiveSession();
    await _credentials.clear();
    _activeShop.clear();
    _recentPinProof.clear();
    await _clearOrphanLocalAuthData();
  }

  Future<LockScreenData?> _lockScreenFromStoredProfile(int localShopId) async {
    final sessionUser = await _sessionStorage.getUser();
    final profile = await _credentials.getProfile();
    final userData = sessionUser ?? profile;
    if (userData == null) return null;

    final shop = await (_db.select(_db.shops)..where((s) => s.id.equals(localShopId)))
        .getSingleOrNull();
    if (shop == null) return null;

    final settings = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(localShopId)))
        .getSingleOrNull();

    final localUsers = await _activeUsersForShop(localShopId);
    if (localUsers.isNotEmpty) {
      return _lockScreenFromLocal(localShopId);
    }

    final name = userData['name'] as String? ?? 'Utilisateur';
    final roleCode = userData['role'] as String? ?? UserRole.owner.code;
    final biometric = userData['biometricEnabled'] as bool? ?? false;

    return LockScreenData(
      shopId: localShopId,
      shopName: settings?.shopName ?? shop.name,
      shopLogoPath: settings?.shopLogoPath,
      users: [
        LockScreenUser(
          id: userData['localUserId'] as int? ?? 1,
          name: name,
          role: UserRole.fromCode(roleCode),
          biometricEnabled: biometric,
        ),
      ],
    );
  }

  Future<int> _resolveServerShopId(int shopId) async {
    final byLocalId = await (_db.select(_db.shops)..where((s) => s.id.equals(shopId)))
        .getSingleOrNull();
    if (byLocalId?.serverId != null) {
      return int.parse(byLocalId!.serverId!);
    }

    final byServerId = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('$shopId')))
        .getSingleOrNull();
    if (byServerId != null) return shopId;

    return shopId;
    }

  Future<int> _resolveLocalShopId(int serverShopId, {String? shopName}) async {
    final byServer = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('$serverShopId')))
        .getSingleOrNull();
    if (byServer != null) return byServer.id;

    final byId = await (_db.select(_db.shops)..where((s) => s.id.equals(serverShopId)))
        .getSingleOrNull();
    if (byId != null) return byId.id;

    await _db.into(_db.shops).insert(
          ShopsCompanion.insert(
            name: Value(shopName ?? 'Ma Boutique'),
            createdAt: nowMs(),
            serverId: Value('$serverShopId'),
            syncedAt: Value(nowMs()),
          ),
        );

    final created = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('$serverShopId')))
        .getSingle();
    return created.id;
  }

  Future<void> _syncLockScreenFromApi(LockScreenDataDto remote) async {
    final localShopId =
        await _resolveLocalShopId(remote.shopId, shopName: remote.shopName);
    final timestamp = nowMs();

    final settings = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(localShopId)))
        .getSingleOrNull();

    if (settings == null) {
      await _db.into(_db.settings).insert(
            SettingsCompanion.insert(
              shopId: localShopId,
              shopName: Value(remote.shopName),
              shopLogoPath: Value(remote.shopLogoPath),
              updatedAt: timestamp,
            ),
          );
    } else {
      await (_db.update(_db.settings)..where((s) => s.shopId.equals(localShopId)))
          .write(
        SettingsCompanion(
          shopName: Value(remote.shopName),
          shopLogoPath: Value(remote.shopLogoPath),
          updatedAt: Value(timestamp),
        ),
      );
    }
  }

  Future<LockScreenData> _lockScreenFromLocal(int shopId) async {
    final shop = await (_db.select(_db.shops)..where((s) => s.id.equals(shopId)))
        .getSingleOrNull();
    if (shop == null) {
      throw const NotFoundFailure('Boutique introuvable.');
    }

    final settings = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(shopId)))
        .getSingleOrNull();

    final users = await _activeUsersForShop(shopId);

    return LockScreenData(
      shopId: shop.id,
      shopName: settings?.shopName ?? shop.name,
      shopLogoPath: settings?.shopLogoPath,
      users: users
          .map(
            (user) => LockScreenUser(
              id: user.id,
              name: user.name,
              role: UserRole.fromCode(user.role),
              biometricEnabled: user.biometricEnabled,
            ),
          )
          .toList(),
    );
  }

  LockScreenData _mapLockScreenDto(
    LockScreenDataDto remote, {
    required int localShopId,
  }) {
    return LockScreenData(
      shopId: localShopId,
      shopName: remote.shopName,
      shopLogoPath: remote.shopLogoPath,
      users: remote.users
          .map(
            (user) => LockScreenUser(
              id: user.id,
              name: user.name,
              role: roleFromApi(user.role),
              biometricEnabled: user.biometricEnabled,
            ),
          )
          .toList(),
    );
  }

  Future<Set<Permission>> _resolvePermissions(UserRole fallbackRole) async {
    final stored = await _credentials.getPermissions();
    if (stored.isNotEmpty) {
      return resolveSessionPermissions(apiCodes: stored, role: fallbackRole);
    }
    return permissionsForRole(fallbackRole);
  }

  /// Utilisateurs actifs d'une boutique ; le patron reste accessible sur toutes ses boutiques.
  Future<List<User>> _activeUsersForShop(int localShopId) async {
    final shopUsers = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(localShopId) & u.isActive.equals(true)))
        .get();
    if (shopUsers.isNotEmpty) return shopUsers;

    return (_db.select(_db.users)
          ..where((u) => u.role.equals('owner') & u.isActive.equals(true)))
        .get();
  }

  Future<User> _resolveUser({required int shopId, int? userId}) async {
    if (userId != null) {
      final user = await (_db.select(_db.users)
            ..where((u) => u.id.equals(userId) & u.shopId.equals(shopId)))
          .getSingleOrNull();
      if (user == null) {
        throw const NotFoundFailure('Utilisateur introuvable.');
      }
      return user;
    }

    final users = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(shopId) & u.isActive.equals(true)))
        .get();

    if (users.isEmpty) {
      throw const NotFoundFailure('Aucun utilisateur actif.');
    }

    return users.first;
  }

  /// Vrai si le PIN local de l'utilisateur ciblé est encore provisoire
  /// (hash aléatoire post-WhatsApp), seul cas où le serveur valide le PIN.
  Future<bool> _isPinProvisional({
    required int localShopId,
    int? userId,
  }) async {
    try {
      final user = await _resolveUser(shopId: localShopId, userId: userId);
      return user.pinProvisional;
    } on Object {
      return false;
    }
  }

  /// Convertit un id utilisateur local (écran PIN) en id serveur pour l'API.
  Future<int?> _resolveServerUserId({
    required int localShopId,
    int? userId,
  }) async {
    if (userId == null) return null;

    final user = await (_db.select(_db.users)
          ..where((u) => u.id.equals(userId) & u.shopId.equals(localShopId)))
        .getSingleOrNull();
    if (user == null) return null;

    return _parseServerId(user.serverId);
  }

  Future<Setting> _getSettings(int shopId) async {
    final settings = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(shopId)))
        .getSingleOrNull();

    if (settings != null) return settings;

    final timestamp = nowMs();
    final id = await _db.into(_db.settings).insert(
          SettingsCompanion.insert(
            shopId: shopId,
            updatedAt: timestamp,
          ),
        );

    return (await (_db.select(_db.settings)..where((s) => s.id.equals(id)))
        .getSingle());
  }

  Future<void> _handleFailedAttempt(User user) async {
    final result = _lockoutPolicy.onFailedAttempt(
      failedAttempts: user.failedAttempts,
      lockoutCount: user.lockoutCount,
      version: user.version,
    );

    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(
        failedAttempts: Value(result.update['failed_attempts'] as int),
        lockedUntil: Value(result.update['locked_until'] as int?),
        lockoutCount: Value(result.update['lockout_count'] as int? ?? user.lockoutCount),
        updatedAt: Value(result.update['updated_at'] as int),
        version: Value(result.update['version'] as int),
      ),
    );

    if (result.lockoutTriggered) {
      if (result.requiresEmergencyRecovery == true) {
        throw const EmergencyRecoveryRequiredFailure();
      }
      throw AccountLockedFailure(
        lockedUntil: result.lockedUntil!,
        remainingSeconds: _lockoutPolicy.lockoutDurationMs ~/ 1000,
      );
    }

    throw InvalidPinFailure(result.remainingAttempts!);
  }

  Future<AuthSession> _createSession({
    required User user,
    required Setting settings,
    required int shopId,
    required Set<Permission> permissions,
    String? shopName,
    String? roleLabel,
    int? serverUserId,
    int? serverShopId,
  }) async {
    await _authFlow?.clearLoggedOut();
    final timestamp = nowMs();
    final expiresAt = timestamp + ApiConfig.localSessionMaxMs;
    final token = _uuid.v4();

    await _db.into(_db.authSessions).insert(
          AuthSessionsCompanion.insert(
            id: token,
            userId: user.id,
            shopId: shopId,
            pinVerifiedAt: timestamp,
            expiresAt: expiresAt,
            lastActivityAt: timestamp,
            createdAt: timestamp,
          ),
        );

    final shop = await (_db.select(_db.shops)..where((s) => s.id.equals(shopId)))
        .getSingle();
    final role = UserRole.fromCode(user.role);
    final resolvedServerUserId =
        serverUserId ?? _parseServerId(user.serverId);
    final resolvedServerShopId =
        serverShopId ?? _parseServerId(shop.serverId);
    if (resolvedServerShopId != null) {
      _activeShop.setServerShopId(resolvedServerShopId);
    }

    final authUser = AuthUser(
      id: user.id,
      name: user.name,
      role: role,
      roleLabel: roleLabel ?? role.label,
      shopId: user.shopId,
      biometricEnabled: user.biometricEnabled,
      lastLoginAt: user.lastLoginAt,
      permissions: permissions,
      serverUserId: resolvedServerUserId,
    );

    await _sessionStorage.saveSession(
      sessionToken: token,
      expiresAt: expiresAt,
      user: {
        'id': authUser.id,
        'name': authUser.name,
        'role': authUser.role.code,
        'shopId': authUser.shopId,
        'biometricEnabled': authUser.biometricEnabled,
        'lastLoginAt': authUser.lastLoginAt,
      },
    );

    return AuthSession(
      token: token,
      expiresAt: expiresAt,
      autoLockMinutes: settings.autoLockMinutes,
      shop: AuthShop(
        id: shop.id,
        name: shopName ?? settings.shopName,
        serverShopId: resolvedServerShopId,
      ),
      user: authUser,
    );
  }

  @override
  Future<void> verifyShopOwnerPin({
    required int shopId,
    required String pin,
  }) async {
    final pinVo = Pin.create(pin);
    final shop = await (_db.select(_db.shops)..where((s) => s.id.equals(shopId)))
        .getSingleOrNull();

    User? owner;
    final ownerId = shop?.ownerUserId;
    if (ownerId != null) {
      owner = await (_db.select(_db.users)..where((u) => u.id.equals(ownerId)))
          .getSingleOrNull();
    }
    owner ??= await (_db.select(_db.users)
          ..where(
            (u) =>
                u.shopId.equals(shopId) &
                u.role.equals('owner') &
                u.isActive.equals(true),
          ))
        .getSingleOrNull();

    if (owner == null) {
      throw const NotFoundFailure('Patron introuvable pour cette boutique.');
    }
    if (!_pinHasher.compare(pinVo.value, owner.pinHash)) {
      throw const UnauthorizedFailure('PIN du patron incorrect.');
    }
  }
}
