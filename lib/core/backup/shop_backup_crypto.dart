import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';

import '../errors/failures.dart';

/// Chiffrement AES-256-CBC + PBKDF2 pour les fichiers `.venteapp` (RG-PARAM-06/07).
class ShopBackupCrypto {
  const ShopBackupCrypto._();

  static const iterations = 120000;
  static const format = 'venteapp';
  static const version = 1;

  static Map<String, dynamic> seal(String plaintext, String passphrase) {
    final trimmed = passphrase.trim();
    if (trimmed.length < 8) {
      throw const ValidationFailure(
        'La phrase secrète doit comporter au moins 8 caractères.',
      );
    }

    final salt = _randomBytes(16);
    final key = _deriveKey(trimmed, salt);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return {
      'format': format,
      'version': version,
      'algorithm': 'aes-256-cbc-pbkdf2-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'iv': base64Encode(iv.bytes),
      'ciphertext': encrypted.base64,
    };
  }

  static String open(Map<String, dynamic> envelope, String passphrase) {
    final trimmed = passphrase.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Phrase secrète requise.');
    }
    if (envelope['format'] != format) {
      throw const ValidationFailure('Fichier .venteapp invalide.');
    }
    if ((envelope['version'] as num?)?.toInt() != version) {
      throw const ValidationFailure(
        'Version de sauvegarde non supportée.',
      );
    }

    try {
      final salt = base64Decode(envelope['salt'] as String);
      final key = _deriveKey(trimmed, salt);
      final iv = IV(base64Decode(envelope['iv'] as String));
      final encrypter = Encrypter(AES(Key(key)));
      return encrypter.decrypt64(envelope['ciphertext'] as String, iv: iv);
    } catch (_) {
      throw const ValidationFailure(
        'Phrase secrète incorrecte ou fichier corrompu.',
      );
    }
  }

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }
}
