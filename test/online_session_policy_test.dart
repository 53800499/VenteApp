import 'package:flutter_test/flutter_test.dart';

import 'package:venteapp/core/errors/failures.dart';
import 'package:venteapp/core/network/online_session_policy.dart';

void main() {
  group('OnlineSessionPolicy', () {
    late OnlineSessionPolicy policy;

    setUp(() {
      policy = OnlineSessionPolicy();
    });

    test('requiresLogout uniquement pour auth expirée ou grâce offline', () {
      expect(
        OnlineSessionPolicy.requiresLogout(const UnauthorizedFailure('expiré')),
        isTrue,
      );
      expect(
        OnlineSessionPolicy.requiresLogout(const OfflineGraceExpiredFailure()),
        isTrue,
      );
      expect(
        OnlineSessionPolicy.requiresLogout(const NetworkFailure('hors ligne')),
        isFalse,
      );
      expect(
        OnlineSessionPolicy.requiresLogout(const ValidationFailure('x')),
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

    test('handleFailure déclenche onSessionInvalidated une seule fois', () async {
      var count = 0;
      policy.onSessionInvalidated = () => count++;

      policy.handleFailure(const NetworkFailure('offline'));
      expect(count, 0);

      policy.handleFailure(const UnauthorizedFailure('session'));
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(count, 1);

      policy.handleFailure(const UnauthorizedFailure('encore'));
      expect(count, 1);
    });

    test('reset permet une nouvelle invalidation', () async {
      var count = 0;
      policy.onSessionInvalidated = () => count++;

      policy.handleFailure(const OfflineGraceExpiredFailure());
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(count, 1);

      policy.reset();
      policy.handleFailure(const UnauthorizedFailure('x'));
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(count, 2);
    });
  });
}
