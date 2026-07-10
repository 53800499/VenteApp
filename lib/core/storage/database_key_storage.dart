import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Clé de chiffrement SQLite (une par appareil, indépendante du PIN).
class DatabaseKeyStorage {
  DatabaseKeyStorage(this._storage);

  static const storageKey = 'sqlite_encryption_key';

  final FlutterSecureStorage _storage;

  Future<String> getOrCreatePassphrase() async {
    final existing = await _storage.read(key: storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final passphrase = base64UrlEncode(bytes);
    await _storage.write(key: storageKey, value: passphrase);
    return passphrase;
  }

  Future<void> clear() async {
    await _storage.delete(key: storageKey);
  }
}
