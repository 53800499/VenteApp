import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'pin_hasher.dart';

class RecoveryTokenService {
  RecoveryTokenService(this._pinHasher);

  final PinHasher _pinHasher;
  final _random = Random.secure();

  ({String token, String hash}) generate() {
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    final token = sha256.convert(bytes).toString();
    final hash = _pinHasher.hash(token);
    return (token: token, hash: hash);
  }
}
