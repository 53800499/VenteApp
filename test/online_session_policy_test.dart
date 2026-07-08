import 'package:flutter_test/flutter_test.dart';

import 'package:venteapp/core/errors/failures.dart';
import 'package:venteapp/core/network/online_session_policy.dart';

void main() {
  group('OnlineSessionPolicy', () {
    late OnlineSessionPolicy policy;

    setUp(() {
      policy = OnlineSessionPolicy();
    });

    test('requiresLogout ne déclenche plus de déconnexion automatique', () {
      expect(
        OnlineSessionPolicy.requiresLogout(const UnauthorizedFailure('expiré')),
        isFalse,
      );
      expect(
        OnlineSessionPolicy.requiresLogout(const OfflineGraceExpiredFailure()),
        isFalse,
      );
      expect(
        OnlineSessionPolicy.requiresLogout(const NetworkFailure('hors ligne')),
        isFalse,
      );
    });

    test('isNetworkUnavailable détecte NetworkFailure', () {
      expect(
        OnlineSessionPolicy.isNetworkUnavailable(
          const NetworkFailure('serveur injoignable'),
        ),
        isTrue,
      );
      expect(
        OnlineSessionPolicy.isNetworkUnavailable(
          const UnauthorizedFailure('x'),
        ),
        isFalse,
      );
    });

    test('handleFailure ignore CloudReconnectRequiredFailure', () async {
      var count = 0;
      policy.onCloudSessionExpired = () => count++;

      policy.handleFailure(const CloudReconnectRequiredFailure());
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(count, 0);
    });

    test('handleFailure déclenche onCloudSessionExpired une seule fois', () async {
      var count = 0;
      policy.onCloudSessionExpired = () => count++;

      policy.handleFailure(const NetworkFailure('offline'));
      expect(count, 0);

      policy.handleFailure(const UnauthorizedFailure('session'));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(count, 1);

      policy.handleFailure(const UnauthorizedFailure('encore'));
      expect(count, 1);
    });

    test('reset permet une nouvelle notification cloud', () async {
      var count = 0;
      policy.onCloudSessionExpired = () => count++;

      policy.handleFailure(const OfflineGraceExpiredFailure());
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(count, 1);

      policy.reset();
      policy.handleFailure(const UnauthorizedFailure('x'));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(count, 2);
    });
  });
}
