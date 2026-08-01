import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/security/device_identity_service.dart';
import 'package:venteapp/core/storage/device_id_storage.dart';

void main() {
  group('DeviceIdentityService', () {
    late DeviceIdStorage deviceIds;
    late DeviceIdentityService identityService;

    setUp(() {
      deviceIds = DeviceIdStorage.inMemory();
      identityService = DeviceIdentityService.inMemory(deviceIdStorage: deviceIds);
    });

    test('génère et persiste un secret d\'appareil cryptographique', () async {
      final secret1 = await identityService.getOrCreateDeviceSecret();
      final secret2 = await identityService.getOrCreateDeviceSecret();

      expect(secret1, isNotEmpty);
      expect(secret1.startsWith('devsec_'), isTrue);
      expect(secret2, equals(secret1));
    });

    test('crée une preuve de challenge d\'appareil valide', () async {
      final proof = await identityService.createProof();

      expect(proof.deviceId, isNotEmpty);
      expect(proof.timestamp, greaterThan(0));
      expect(proof.signature, isNotEmpty);
    });
  });
}
