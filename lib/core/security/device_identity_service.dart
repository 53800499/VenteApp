import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../storage/device_id_storage.dart';
import '../utils/time.dart';

class DeviceChallengeProof {
  const DeviceChallengeProof({
    required this.deviceId,
    required this.timestamp,
    required this.signature,
  });

  final String deviceId;
  final int timestamp;
  final String signature;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'timestamp': timestamp,
        'signature': signature,
      };
}

/// Service d'identité cryptographique d'appareil.
///
/// Génère et stocke de façon isolée un secret d'appareil dans `FlutterSecureStorage`
/// et produit des preuves de possession d'appareil signées pour la restauration
/// transparente de session cloud sans saisir de PIN.
class DeviceIdentityService {
  DeviceIdentityService({
    required DeviceIdStorage deviceIdStorage,
    FlutterSecureStorage? storage,
  })  : _deviceIds = deviceIdStorage,
        _storage = storage ?? const FlutterSecureStorage(),
        _memory = null;

  DeviceIdentityService.inMemory({
    required DeviceIdStorage deviceIdStorage,
  })  : _deviceIds = deviceIdStorage,
        _storage = null,
        _memory = {};

  static const _deviceSecretKey = 'device_crypto_secret';
  final DeviceIdStorage _deviceIds;
  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;
  final _uuid = const Uuid();

  /// Récupère ou génère le secret unique cryptographique de cet appareil.
  Future<String> getOrCreateDeviceSecret() async {
    final existing = await _read(_deviceSecretKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final newSecret = 'devsec_${_uuid.v4()}_${nowMs()}';
    await _write(_deviceSecretKey, newSecret);
    return newSecret;
  }

  /// Génère une preuve d'identité signée pour l'appareil courant.
  Future<DeviceChallengeProof> createProof() async {
    final device = await _deviceIds.getAuthDevice();
    final secret = await getOrCreateDeviceSecret();
    final timestamp = nowMs();
    final payload = '${device.deviceId}:$timestamp';

    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(payload));
    final signature = base64Encode(digest.bytes);

    return DeviceChallengeProof(
      deviceId: device.deviceId,
      timestamp: timestamp,
      signature: signature,
    );
  }

  Future<String?> _read(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key];
    return _storage!.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    await _storage!.write(key: key, value: value);
  }
}
