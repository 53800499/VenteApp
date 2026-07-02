import 'package:venteapp/core/security/lockout_policy.dart';
import 'package:venteapp/core/utils/time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LockoutPolicy policy;

  setUp(() {
    policy = LockoutPolicy(
      maxFailedAttempts: 5,
      lockoutDurationMs: 900000,
      maxLockoutPeriods: 3,
    );
  });

  group('LockoutPolicy.evaluate', () {
    test('compte non verrouillé sans locked_until', () {
      final state = policy.evaluate(lockedUntil: null, lockoutCount: 0);

      expect(state.isLocked, isFalse);
      expect(state.remainingSeconds, 0);
      expect(state.requiresEmergencyRecovery, isFalse);
    });

    test('compte verrouillé si locked_until est dans le futur', () {
      final lockedUntil = nowMs() + 600000;

      final state = policy.evaluate(lockedUntil: lockedUntil, lockoutCount: 1);

      expect(state.isLocked, isTrue);
      expect(state.lockedUntil, lockedUntil);
      expect(state.remainingSeconds, greaterThan(0));
      expect(state.requiresEmergencyRecovery, isFalse);
    });

    test('compte déverrouillé si locked_until est expiré', () {
      final lockedUntil = nowMs() - 1000;

      final state = policy.evaluate(lockedUntil: lockedUntil, lockoutCount: 1);

      expect(state.isLocked, isFalse);
      expect(state.requiresEmergencyRecovery, isFalse);
    });

    test('exige récupération d\'urgence après 3 périodes de blocage', () {
      final state = policy.evaluate(lockedUntil: null, lockoutCount: 3);

      expect(state.isLocked, isFalse);
      expect(state.requiresEmergencyRecovery, isTrue);
    });
  });

  group('LockoutPolicy.onFailedAttempt', () {
    test('incrémente les échecs et retourne les tentatives restantes', () {
      final result = policy.onFailedAttempt(
        failedAttempts: 2,
        lockoutCount: 0,
        version: 1,
      );

      expect(result.lockoutTriggered, isFalse);
      expect(result.remainingAttempts, 2);
      expect(result.update['failed_attempts'], 3);
      expect(result.update['version'], 2);
    });

    test('déclenche un verrouillage à la 5e tentative', () {
      final result = policy.onFailedAttempt(
        failedAttempts: 4,
        lockoutCount: 0,
        version: 3,
      );

      expect(result.lockoutTriggered, isTrue);
      expect(result.lockoutCount, 1);
      expect(result.lockedUntil, isNotNull);
      expect(result.update['failed_attempts'], 0);
      expect(result.update['lockout_count'], 1);
      expect(result.requiresEmergencyRecovery, isFalse);
    });

    test('exige récupération d\'urgence à la 3e période de blocage', () {
      final result = policy.onFailedAttempt(
        failedAttempts: 4,
        lockoutCount: 2,
        version: 5,
      );

      expect(result.lockoutTriggered, isTrue);
      expect(result.lockoutCount, 3);
      expect(result.requiresEmergencyRecovery, isTrue);
    });
  });
}
