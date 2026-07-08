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

  /// Fenêtre glissante (25 min) pendant laquelle le serveur reste visé en
  /// permanence : ouverte à la connexion, renouvelée à chaque contact réussi.
  static const serverAccessWindowUntilKey = 'server_access_window_until';

  /// Horodatage (ms) du dernier contact serveur réussi (login, refresh, pull).
  /// Source de vérité de la politique de session cloud graduée (3 niveaux).
  static const lastServerContactAtKey = 'last_server_contact_at';

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
    await renewServerAccessWindow();
    await recordServerContact();
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
    await renewServerAccessWindow();
    await recordServerContact();
  }

  /// (Ré)ouvre la fenêtre d'accès serveur pour [ApiConfig.serverAccessibleGraceMs].
  Future<void> renewServerAccessWindow() async {
    final until = nowMs() + ApiConfig.serverAccessibleGraceMs;
    await _write(serverAccessWindowUntilKey, until.toString());
  }

  /// Enregistre un contact serveur réussi (login, refresh, pull/sync abouti).
  /// Réinitialise l'ancienneté qui pilote la politique de session cloud.
  Future<void> recordServerContact() async {
    await _write(lastServerContactAtKey, nowMs().toString());
  }

  /// Dernier contact serveur réussi (ms). À défaut d'enregistrement explicite,
  /// se rabat sur l'ancien octroi hors ligne (`offlineValidUntil - 7 j`) pour
  /// rester cohérent avec les sessions ouvertes avant cette fonctionnalité.
  Future<int?> getLastServerContactAt() async {
    final value = await _read(lastServerContactAtKey);
    final parsed = value == null ? null : int.tryParse(value);
    if (parsed != null) return parsed;

    final offlineUntil = await getOfflineValidUntil();
    if (offlineUntil == null) return null;
    return offlineUntil - ApiConfig.offlineGraceMs;
  }

  Future<int?> getServerAccessWindowUntil() async {
    final value = await _read(serverAccessWindowUntilKey);
    return value == null ? null : int.tryParse(value);
  }

  /// Vrai tant qu'on est dans la fenêtre glissante : le serveur reste visé.
  Future<bool> isWithinServerAccessWindow() async {
    final until = await getServerAccessWindowUntil();
    return until != null && until > nowMs();
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
      serverAccessWindowUntilKey,
      lastServerContactAtKey,
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
