import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Implémentation sécurisée et concurrente de [FlutterSecureStorage].
///
/// Sous Windows, le plugin sous-jacent enregistre les données dans un unique fichier
/// DPAPI (`flutter_secure_storage.dat`). Lorsque plusieurs opérations asynchrones
/// de lecture/écriture ont lieu en même temps (ex: démarrage, timers périodiques,
/// rafraîchissement de session), des collisions de verrouillage de fichier surviennent
/// (OS Error 32: Sharing violation, ou échec CryptUnprotectData sur fichier tronqué).
///
/// [SafeSecureStorage] résout définitivement ce problème en :
/// 1. Sérialisant strictement toutes les opérations d'E/S via un verrou séquentiel.
/// 2. Maintenant un cache en mémoire réactif pour des lectures ultra-rapides sans accès disque inutile.
/// 3. Retentant automatiquement en cas de verrou temporaire sur le fichier Windows.
class SafeSecureStorage extends FlutterSecureStorage {
  SafeSecureStorage({
    super.iOptions,
    super.aOptions,
    super.lOptions,
    super.wOptions,
    super.webOptions,
    super.mOptions,
  });

  Future<void> _lock = Future<void>.value();
  final Map<String, String> _cache = {};
  bool _isCacheLoaded = false;
  Completer<void>? _preloadCompleter;

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lock = _lock.whenComplete(() async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<T> _retry<T>(Future<T> Function() action, {int maxAttempts = 3}) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 50 * attempt));
      }
    }
    return action();
  }

  Future<void> _ensureCacheLoaded() async {
    if (_isCacheLoaded) return;
    if (_preloadCompleter != null) {
      await _preloadCompleter!.future;
      return;
    }

    _preloadCompleter = Completer<void>();
    try {
      final all = await _retry(() => super.readAll());
      _cache.addAll(all);
      _isCacheLoaded = true;
      _preloadCompleter!.complete();
    } catch (e) {
      debugPrint('SafeSecureStorage preload warning: $e');
      _isCacheLoaded = true; // Fallback pour ne pas bloquer
      _preloadCompleter!.complete();
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _synchronized(() async {
      await _ensureCacheLoaded();
      if (_cache.containsKey(key)) {
        return _cache[key];
      }
      try {
        final value = await _retry(() => super.read(
              key: key,
              iOptions: iOptions,
              aOptions: aOptions,
              lOptions: lOptions,
              webOptions: webOptions,
              mOptions: mOptions,
              wOptions: wOptions,
            ));
        if (value != null) {
          _cache[key] = value;
        } else {
          _cache.remove(key);
        }
        return value;
      } catch (e) {
        debugPrint('SafeSecureStorage read fallback for $key: $e');
        return _cache[key];
      }
    });
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _synchronized(() async {
      await _ensureCacheLoaded();
      if (value == null) {
        _cache.remove(key);
      } else {
        _cache[key] = value;
      }

      try {
        await _retry(() => super.write(
              key: key,
              value: value,
              iOptions: iOptions,
              aOptions: aOptions,
              lOptions: lOptions,
              webOptions: webOptions,
              mOptions: mOptions,
              wOptions: wOptions,
            ));
      } catch (e) {
        debugPrint('SafeSecureStorage write error for $key: $e');
      }
    });
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _synchronized(() async {
      await _ensureCacheLoaded();
      _cache.remove(key);
      try {
        await _retry(() => super.delete(
              key: key,
              iOptions: iOptions,
              aOptions: aOptions,
              lOptions: lOptions,
              webOptions: webOptions,
              mOptions: mOptions,
              wOptions: wOptions,
            ));
      } catch (e) {
        debugPrint('SafeSecureStorage delete error for $key: $e');
      }
    });
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _synchronized(() async {
      _cache.clear();
      _isCacheLoaded = true;
      try {
        await _retry(() => super.deleteAll(
              iOptions: iOptions,
              aOptions: aOptions,
              lOptions: lOptions,
              webOptions: webOptions,
              mOptions: mOptions,
              wOptions: wOptions,
            ));
      } catch (e) {
        debugPrint('SafeSecureStorage deleteAll error: $e');
      }
    });
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _synchronized(() async {
      await _ensureCacheLoaded();
      return Map<String, String>.from(_cache);
    });
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _synchronized(() async {
      await _ensureCacheLoaded();
      if (_cache.containsKey(key)) {
        return true;
      }
      try {
        return await _retry(() => super.containsKey(
              key: key,
              iOptions: iOptions,
              aOptions: aOptions,
              lOptions: lOptions,
              webOptions: webOptions,
              mOptions: mOptions,
              wOptions: wOptions,
            ));
      } catch (e) {
        return _cache.containsKey(key);
      }
    });
  }
}
