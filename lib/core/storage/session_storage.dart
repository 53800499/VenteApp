import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  SessionStorage(FlutterSecureStorage storage)
      : _storage = storage,
        _memory = null;

  SessionStorage.inMemory() : _storage = null, _memory = {};

  static const _sessionTokenKey = 'session_token';
  static const _sessionExpiresKey = 'session_expires_at';
  static const _userKey = 'auth_user';

  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;

  Future<void> saveSession({
    required String sessionToken,
    required int expiresAt,
    required Map<String, dynamic> user,
  }) async {
    await _write(_sessionTokenKey, sessionToken);
    await _write(_sessionExpiresKey, expiresAt.toString());
    await _write(_userKey, jsonEncode(user));
  }

  Future<String?> getSessionToken() => _read(_sessionTokenKey);

  Future<int?> getSessionExpiresAt() async {
    final value = await _read(_sessionExpiresKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _read(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clear() async {
    await _delete(_sessionTokenKey);
    await _delete(_sessionExpiresKey);
    await _delete(_userKey);
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
    if (memory != null) {
      return memory[key];
    }
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
