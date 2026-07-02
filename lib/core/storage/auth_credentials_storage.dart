import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_config.dart';
import '../utils/time.dart';

/// Stockage sécurisé JWT (access + refresh) + profil pour l'usage hors ligne.
class AuthCredentialsStorage {
  AuthCredentialsStorage(FlutterSecureStorage storage)
      : _storage = storage,
        _memory = null;

  AuthCredentialsStorage.inMemory() : _storage = null, _memory = {};

  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const profileKey = 'auth_profile';
  static const permissionsKey = 'auth_permissions';
  static const offlineValidUntilKey = 'offline_valid_until';
  static const accessExpiresAtKey = 'access_expires_at';
  static const refreshExpiresAtKey = 'refresh_expires_at';

  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;

  Future<void> saveOnlineAuth({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> profile,
    required List<String> permissions,
    required int accessExpiresAt,
    required int refreshExpiresAt,
  }) async {
    final offlineUntil = nowMs() + ApiConfig.offlineGraceMs;
    await _write(accessTokenKey, accessToken);
    await _write(refreshTokenKey, refreshToken);
    await _write(profileKey, jsonEncode(profile));
    await _write(permissionsKey, jsonEncode(permissions));
    await _write(offlineValidUntilKey, offlineUntil.toString());
    await _write(accessExpiresAtKey, accessExpiresAt.toString());
    await _write(refreshExpiresAtKey, refreshExpiresAt.toString());
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
    required int accessExpiresAt,
    required int refreshExpiresAt,
  }) async {
    final offlineUntil = nowMs() + ApiConfig.offlineGraceMs;
    await _write(accessTokenKey, accessToken);
    await _write(refreshTokenKey, refreshToken);
    await _write(accessExpiresAtKey, accessExpiresAt.toString());
    await _write(refreshExpiresAtKey, refreshExpiresAt.toString());
    await _write(offlineValidUntilKey, offlineUntil.toString());
  }

  Future<void> updateProfileShopId(int shopId) async {
    final profile = await getProfile();
    if (profile == null) return;
    profile['shopId'] = shopId;
    await _write(profileKey, jsonEncode(profile));
  }

  Future<String?> getAccessToken() => _read(accessTokenKey);

  Future<String?> getRefreshToken() => _read(refreshTokenKey);

  Future<int?> getAccessExpiresAt() async {
    final value = await _read(accessExpiresAtKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final raw = await _read(profileKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> updatePermissions(List<String> permissions) async {
    await _write(permissionsKey, jsonEncode(permissions));
  }

  Future<List<String>> getPermissions() async {
    final raw = await _read(permissionsKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.cast<String>();
  }

  Future<int?> getOfflineValidUntil() async {
    final value = await _read(offlineValidUntilKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<bool> hasValidOfflineGrant() async {
    final until = await getOfflineValidUntil();
    return until != null && until > nowMs();
  }

  Future<int?> getRefreshExpiresAt() async {
    final value = await _read(refreshExpiresAtKey);
    return value == null ? null : int.tryParse(value);
  }

  /// Jeton d'accès encore valide (marge 30 s avant expiration).
  Future<bool> hasValidAccessToken() async {
    final expiresAt = await getAccessExpiresAt();
    if (expiresAt == null) return false;
    return expiresAt > nowMs() + 30000;
  }

  Future<bool> hasValidRefreshToken() async {
    final expiresAt = await getRefreshExpiresAt();
    if (expiresAt == null) return false;
    return expiresAt > nowMs();
  }

  Future<bool> hasCredentials() async {
    final token = await getAccessToken();
    final refresh = await getRefreshToken();
    final profile = await getProfile();
    return token != null && refresh != null && profile != null;
  }

  Future<void> clear() async {
    for (final key in [
      accessTokenKey,
      refreshTokenKey,
      profileKey,
      permissionsKey,
      offlineValidUntilKey,
      accessExpiresAtKey,
      refreshExpiresAtKey,
    ]) {
      await _delete(key);
    }
  }

  Future<void> _write(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    await _storage!.write(key: key, value: value);
  }

  Future<String?> _read(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key];
    return _storage!.read(key: key);
  }

  Future<void> _delete(String key) async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(key);
      return;
    }
    await _storage!.delete(key: key);
  }
}
