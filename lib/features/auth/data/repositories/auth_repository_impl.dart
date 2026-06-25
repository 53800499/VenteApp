import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart' hide AuthSession;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/active_shop_context.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/security/lockout_policy.dart';
import '../../../../core/security/pin_hasher.dart';
import '../../../../core/security/recovery_token_service.dart';
import '../../../../core/storage/auth_credentials_storage.dart';
import '../../../../core/storage/device_id_storage.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/utils/time.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/pin.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/auth_api_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AppDatabase database,
    required PinHasher pinHasher,
    required LockoutPolicy lockoutPolicy,
    required RecoveryTokenService recoveryTokenService,
    required SessionStorage sessionStorage,
    required AuthCredentialsStorage credentialsStorage,
    DeviceIdStorage? deviceIdStorage,
    ActiveShopContext? activeShopContext,
    AuthRemoteDatasource? remote,
    NetworkInfo? networkInfo,
    Uuid? uuid,
  })  : _db = database,
        _pinHasher = pinHasher,
        _lockoutPolicy = lockoutPolicy,
        _recoveryTokenService = recoveryTokenService,
        _sessionStorage = sessionStorage,
        _credentials = credentialsStorage,
        _deviceIds = deviceIdStorage ?? DeviceIdStorage.inMemory(),
        _activeShop = activeShopContext ?? ActiveShopContext(),
        _remote = remote,
        _networkInfo = networkInfo ?? const NetworkInfo.alwaysOffline(),
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final PinHasher _pinHasher;
  final LockoutPolicy _lockoutPolicy;
  final RecoveryTokenService _recoveryTokenService;
  final SessionStorage _sessionStorage;
  final AuthCredentialsStorage _credentials;
  final DeviceIdStorage _deviceIds;
  final ActiveShopContext _activeShop;
  final AuthRemoteDatasource? _remote;
  final NetworkInfo _networkInfo;
  final Uuid _uuid;

  bool get _isOnlineMode => _remote != null;

  @override
  Future<bool> isSetupComplete() async {
    if (await _credentials.hasCredentials()) return true;
    return _hasLocalOwnerInstallation();
  }

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

    if (localUsers.isNotEmpty && await _credentials.hasValidOfflineGrant()) {
      return _lockScreenFromLocal(localShopId);
    }

    if (_remote != null && await _networkInfo.isConnected) {
      final remote = await _remote!.getLockScreen(serverShopId);
      await _syncLockScreenFromApi(remote);
      return _mapLockScreenDto(remote);
    }

    if (localUsers.isNotEmpty) {
      return _lockScreenFromLocal(localShopId);
    }

    throw const NotFoundFailure('Boutique introuvable.');
  }

  @override
  Future<AuthSession> loginWithPin({
    required String pin,
    required int shopId,
    int? userId,
  }) async {
    if (_remote != null && await _networkInfo.isConnected) {
      final serverShopId = await _resolveServerShopId(shopId);
      final device = await _deviceIds.getAuthDevice();
      final result = await _remote!.loginWithPin(
        pin: pin,
        shopId: serverShopId,
        userId: userId,
        deviceId: device.deviceId,
        deviceLabel: device.deviceLabel,
      );
      return _finalizeOnlineLogin(result, pin: pin);
    }

    if (_isOnlineMode && !await _credentials.hasValidOfflineGrant()) {
      if (!await _networkInfo.isConnected) {
        throw const OfflineGraceExpiredFailure();
      }
      throw const NetworkFailure(
        'Connexion internet requise pour la première connexion.',
      );
    }

    return _loginWithPinLocal(
      pin: pin,
      shopId: await _resolveLocalShopId(await _resolveServerShopId(shopId)),
      userId: userId,
    );
  }

  @override
  Future<AuthSession> loginWithBiometric({
    required int shopId,
    int? userId,
  }) async {
    if (_isOnlineMode && !await _credentials.hasValidOfflineGrant()) {
      throw const OfflineGraceExpiredFailure();
    }
    return _loginWithBiometricLocal(shopId: shopId, userId: userId);
  }

  @override
  Future<SetupOwnerResult> setupOwner({
    required String ownerName,
    required String shopName,
    required String pin,
    String? shopAddress,
    String? shopPhone,
  }) async {
    if (_remote != null) {
      if (!await _networkInfo.isConnected) {
        throw const NetworkFailure(
          'Connexion internet requise pour l\'installation initiale.',
        );
      }

      await _prepareForOwnerSetup();

      final apiResult = await _remote!.setupOwner(
        ownerName: ownerName,
        shopName: shopName,
        pin: pin,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
      );

      await _persistSetupLocally(
        apiResult: apiResult,
        ownerName: ownerName,
        shopName: shopName,
        pin: pin,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
      );

      return SetupOwnerResult(
        shopId: apiResult.shopId,
        userId: apiResult.userId,
        recoveryToken: apiResult.recoveryToken,
        message: apiResult.message,
      );
    }

    return _setupOwnerLocal(
      ownerName: ownerName,
      shopName: shopName,
      pin: pin,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
    );
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

    final timestamp = nowMs();
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(
        biometricEnabled: const Value(true),
        updatedAt: Value(timestamp),
        version: Value(user.version + 1),
      ),
    );

    return true;
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

    final settings = await _getSettings(session.shopId);
    final timestamp = nowMs();
    final newExpiry = timestamp + msFromMinutes(settings.autoLockMinutes);

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
    if (_isOnlineMode && !await _credentials.hasValidOfflineGrant()) {
      return null;
    }

    final token = await _sessionStorage.getSessionToken();
    final expiresAt = await _sessionStorage.getSessionExpiresAt();
    final userJson = await _sessionStorage.getUser();

    if (token == null || expiresAt == null || userJson == null) {
      return null;
    }

    if (expiresAt <= nowMs()) {
      await lockActiveSession();
      return null;
    }

    final session = await (_db.select(_db.authSessions)
          ..where((s) => s.id.equals(token)))
        .getSingleOrNull();

    if (session == null || session.expiresAt <= nowMs()) {
      await lockActiveSession();
      return null;
    }

    final shop = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(session.shopId)))
        .getSingleOrNull();

    if (shop == null) {
      await logout();
      return null;
    }

    final settings = await _getSettings(session.shopId);
    final role = UserRole.fromCode(userJson['role'] as String? ?? 'owner');
    final permissions = await _resolvePermissions(role);

    final profile = await _credentials.getProfile();
    final profileShopId = profile?['shopId'];
    if (profileShopId is int) {
      _activeShop.setServerShopId(profileShopId);
    } else {
      await _syncActiveShopFromLocal(session.shopId);
    }

    final serverUserId = profile?['id'] as int?;
    final localShop = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(session.shopId)))
        .getSingle();
    final serverShopId = _parseServerId(localShop.serverId) ?? profileShopId as int?;

    return AuthSession(
      token: token,
      expiresAt: session.expiresAt,
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
        shopId: userJson['shopId'] as int,
        biometricEnabled: userJson['biometricEnabled'] as bool? ?? false,
        lastLoginAt: userJson['lastLoginAt'] as int?,
        permissions: permissions,
        serverUserId: serverUserId,
      ),
    );
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

  @override
  Future<void> lockActiveSession() async {
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
        await _remote!.logout();
      } on Object {
        // Déconnexion locale même si l'API est injoignable.
      }
    }
    await lockActiveSession();
    await _credentials.clear();
    _activeShop.clear();
  }

  @override
  Future<OwnedShopList> listOwnedShops() async {
    if (_remote == null) {
      throw const NetworkFailure('Liste des boutiques indisponible hors ligne.');
    }
    if (!await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Connexion internet requise pour lister vos boutiques.',
      );
    }

    final dto = await _remote!.listOwnedShops();
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
    _activeShop.setServerShopId(result.shop.id);

    final localUser = await _upsertLocalUserFromApi(
      result.user,
      pin: pin,
      shopName: result.shop.name,
    );

    final localShopId = await _resolveLocalShopId(result.shop.id);
    final settings = await _getSettings(localShopId);
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
    String? shopAddress,
    String? shopPhone,
  }) async {
    final existing = await (_db.select(_db.users)
          ..where((u) => u.role.equals('owner')))
        .get();
    if (existing.isNotEmpty) {
      final owner = existing.first;
      if (owner.serverId == '${apiResult.userId}') {
        return;
      }
      throw const ConflictFailure(
        'L\'installation a déjà été effectuée sur cet appareil.',
      );
    }

    final pinHash = _pinHasher.hash(Pin.create(pin).value);
    final recoveryHash = _pinHasher.hash(apiResult.recoveryToken);
    final timestamp = nowMs();

    await _db.transaction(() async {
      final shopId = await _db.into(_db.shops).insert(
            ShopsCompanion.insert(
              name: Value(shopName),
              address: Value(shopAddress),
              phone: Value(shopPhone),
              createdAt: timestamp,
              serverId: Value('${apiResult.shopId}'),
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
              serverId: Value('${apiResult.userId}'),
              syncedAt: Value(timestamp),
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
    });
  }

  Future<AuthSession> _loginWithPinLocal({
    required String pin,
    required int shopId,
    int? userId,
  }) async {
    final pinVo = Pin.create(pin);
    final user = await _resolveUser(shopId: shopId, userId: userId);
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

    if (!_pinHasher.compare(pinVo.value, user.pinHash)) {
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

    final updatedUser = user.copyWith(
      failedAttempts: 0,
      lockedUntil: const Value(null),
      lockoutCount: 0,
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
            shopId: shopId,
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
            reason: const Value(
              'Déblocage via fichier de récupération d\'urgence',
            ),
            createdAt: timestamp,
          ),
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
          updatedAt: Value(timestamp),
          version: Value(existing.version + 1),
          serverId: Value('${apiUser.id}'),
          syncedAt: Value(timestamp),
        ),
      );
      return (await (_db.select(_db.users)..where((u) => u.id.equals(existing.id)))
          .getSingle());
    }

    if (pin == null) {
      throw const ValidationFailure('PIN requis pour la synchronisation locale.');
    }
    final pinHash = _pinHasher.hash(Pin.create(pin).value);

    final userId = await _db.into(_db.users).insert(
          UsersCompanion.insert(
            shopId: localShopId,
            name: apiUser.name,
            pinHash: pinHash,
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
    if (await _credentials.hasCredentials()) {
      throw const ConflictFailure(
        'L\'installation a déjà été effectuée sur cet appareil.',
      );
    }

    final owners = await (_db.select(_db.users)
          ..where((u) => u.role.equals('owner')))
        .get();
    if (owners.isNotEmpty) {
      throw const ConflictFailure(
        'L\'installation a déjà été effectuée sur cet appareil.',
      );
    }

    await _clearOrphanLocalAuthData();
  }

  Future<void> _clearOrphanLocalAuthData() async {
    await _sessionStorage.clear();
    await _db.transaction(() async {
      await _db.delete(_db.authSessions).go();
      await _db.delete(_db.users).go();
      await _db.delete(_db.settings).go();
      await _db.delete(_db.shops).go();
    });
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

  LockScreenData _mapLockScreenDto(LockScreenDataDto remote) {
    return LockScreenData(
      shopId: remote.shopId,
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
    final timestamp = nowMs();
    final expiresAt = timestamp + msFromMinutes(settings.autoLockMinutes);
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
}
