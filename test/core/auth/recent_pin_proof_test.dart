import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/auth/recent_pin_proof.dart';
import 'package:venteapp/core/constants/api_config.dart';

void main() {
  group('RecentPinProof', () {
    test('expose une preuve récente après enregistrement', () {
      final proof = RecentPinProof();
      proof.record(
        pin: '1234',
        serverShopId: 10,
        localShopId: 1,
        serverUserId: 5,
      );

      expect(proof.hasRecentProof, isTrue);
      expect(proof.current?.pin, '1234');
      expect(proof.current?.serverShopId, 10);
    });

    test('efface la preuve après clear', () {
      final proof = RecentPinProof();
      proof.record(
        pin: '1234',
        serverShopId: 10,
        localShopId: 1,
      );
      proof.clear();

      expect(proof.hasRecentProof, isFalse);
    });

    test('expire la preuve après la fenêtre TTL', () {
      final proof = RecentPinProof();
      proof.record(
        pin: '1234',
        serverShopId: 10,
        localShopId: 1,
      );

      final credential = proof.current!;
      expect(
        credential.isRecent(
          now: credential.validatedAtMs + ApiConfig.recentPinProofTtlMs + 1,
        ),
        isFalse,
      );
    });
  });
}
