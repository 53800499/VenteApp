import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/licensing/security/license_verifier.dart';

void main() {
  group('LicenseVerifier (v2 anti-replay & signature checks)', () {
    const activeTenant = 'tenant_arike_001';

    SignedLicensePayload buildPayload({
      required int sequence,
      required String tenantId,
      String? signature,
    }) {
      final payloadWithoutSig = SignedLicensePayload(
        header: const LicensePayloadHeader(
          schemaVersion: 1,
          keyId: 'ed25519-2026-v1',
          algorithm: 'HMAC-SHA256',
        ),
        licenseId: 'lic_123',
        licenseSequence: sequence,
        licenseVersion: 1,
        tenantId: tenantId,
        planCode: 'PREMIUM',
        status: 'ACTIVE',
        maxUsers: 5,
        maxShops: 2,
        grantedModules: ['sales', 'inventory'],
        issuedAt: DateTime(2026, 7, 30),
        validFrom: DateTime(2026, 7, 30),
        validUntil: DateTime(2027, 7, 30),
        graceUntil: DateTime(2027, 8, 6),
        signature: '',
      );

      final computedSig = signature ?? (() {
        final signableData = jsonEncode(payloadWithoutSig.toPayloadMap());
        final hmac = Hmac(sha256, utf8.encode('arike_dev_key_2026_ed25519'));
        final digest = hmac.convert(utf8.encode(signableData));
        return base64Encode(digest.bytes);
      })();

      return SignedLicensePayload(
        header: payloadWithoutSig.header,
        licenseId: payloadWithoutSig.licenseId,
        licenseSequence: payloadWithoutSig.licenseSequence,
        licenseVersion: payloadWithoutSig.licenseVersion,
        tenantId: payloadWithoutSig.tenantId,
        planCode: payloadWithoutSig.planCode,
        status: payloadWithoutSig.status,
        maxUsers: payloadWithoutSig.maxUsers,
        maxShops: payloadWithoutSig.maxShops,
        grantedModules: payloadWithoutSig.grantedModules,
        issuedAt: payloadWithoutSig.issuedAt,
        validFrom: payloadWithoutSig.validFrom,
        validUntil: payloadWithoutSig.validUntil,
        graceUntil: payloadWithoutSig.graceUntil,
        signature: computedSig,
      );
    }

    test('rejects license with sequence <= active license sequence (anti-replay)', () {
      final activeLicense = buildPayload(sequence: 5, tenantId: activeTenant);
      final replayedLicense = buildPayload(sequence: 3, tenantId: activeTenant);

      final isValid = LicenseVerifier.verifyLicense(
        newLicense: replayedLicense,
        activeTenantId: activeTenant,
        activeLicense: activeLicense,
      );

      expect(isValid, false);
    });

    test('accepts license with sequence > active license sequence', () {
      final activeLicense = buildPayload(sequence: 5, tenantId: activeTenant);
      final newLicense = buildPayload(sequence: 6, tenantId: activeTenant);

      final isValid = LicenseVerifier.verifyLicense(
        newLicense: newLicense,
        activeTenantId: activeTenant,
        activeLicense: activeLicense,
      );

      expect(isValid, true);
    });

    test('rejects license with tenant mismatch', () {
      final newLicense = buildPayload(sequence: 1, tenantId: 'other_tenant_99');

      final isValid = LicenseVerifier.verifyLicense(
        newLicense: newLicense,
        activeTenantId: activeTenant,
      );

      expect(isValid, false);
    });
  });
}
