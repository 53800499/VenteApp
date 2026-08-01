class PublicKeyRegistry {
  /// Registry of active Ed25519 public keys mapped by keyId.
  /// Allows seamless key rotation without breaking existing Flutter app installations.
  static const Map<String, String> _keys = {
    'ed25519-2026-v1': 'MCowBQYDK2VwAyEA...MOCK_PUBLIC_KEY_2026...',
    'ed25519-2027-v1': 'MCowBQYDK2VwAyEC...MOCK_PUBLIC_KEY_2027...',
    'dev-hmac-v1': 'arike_dev_key_2026_ed25519',
  };

  /// Returns the public key associated with the given keyId, or null if unknown.
  static String? getPublicKey(String keyId) {
    return _keys[keyId];
  }

  /// Checks whether a keyId is known in the current app version.
  static bool isKeySupported(String keyId) {
    return _keys.containsKey(keyId);
  }
}
