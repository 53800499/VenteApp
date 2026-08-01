import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/licensing/security/clock_tampering_detector.dart';

void main() {
  group('ClockTamperingDetector (4-Tier Time Drift Matrix)', () {
    final lastKnown = DateTime(2026, 7, 30, 12, 0, 0);

    test('Tier 1 (< 5 min desync): returns normal', () {
      final now = lastKnown.subtract(const Duration(minutes: 3));
      final result = ClockTamperingDetector.evaluateClock(
        currentSystemTime: now,
        lastKnownTimestamp: lastKnown,
      );
      expect(result, ClockCheckResult.normal);
    });

    test('Tier 2 (5-60 min desync): returns minorDesyncWarning', () {
      final now = lastKnown.subtract(const Duration(minutes: 30));
      final result = ClockTamperingDetector.evaluateClock(
        currentSystemTime: now,
        lastKnownTimestamp: lastKnown,
      );
      expect(result, ClockCheckResult.minorDesyncWarning);
    });

    test('Tier 3 (1-24 hours desync): returns moderateDesyncAlert', () {
      final now = lastKnown.subtract(const Duration(hours: 5));
      final result = ClockTamperingDetector.evaluateClock(
        currentSystemTime: now,
        lastKnownTimestamp: lastKnown,
      );
      expect(result, ClockCheckResult.moderateDesyncAlert);
    });

    test('Tier 4 (> 24 hours desync): returns majorTamperBlocked', () {
      final now = lastKnown.subtract(const Duration(hours: 30));
      final result = ClockTamperingDetector.evaluateClock(
        currentSystemTime: now,
        lastKnownTimestamp: lastKnown,
      );
      expect(result, ClockCheckResult.majorTamperBlocked);
    });

    test('computeNextHighWaterMark with max(lastKnown, serverTimestamp)', () {
      final serverTime = DateTime(2026, 7, 30, 15, 0, 0);
      final nextMark = ClockTamperingDetector.computeNextHighWaterMark(
        currentSystemTime: DateTime(2026, 7, 30, 10, 0, 0),
        lastKnownTimestamp: lastKnown,
        verifiedServerTime: serverTime,
      );
      expect(nextMark, serverTime);
    });
  });
}
