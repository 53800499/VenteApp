import '../utils/time.dart';

class LockState {
  const LockState({
    required this.isLocked,
    required this.lockedUntil,
    required this.remainingSeconds,
    required this.requiresEmergencyRecovery,
  });

  final bool isLocked;
  final int? lockedUntil;
  final int remainingSeconds;
  final bool requiresEmergencyRecovery;
}

class FailedAttemptResult {
  const FailedAttemptResult({
    required this.update,
    this.remainingAttempts,
    required this.lockoutTriggered,
    this.lockoutCount,
    this.lockedUntil,
    this.requiresEmergencyRecovery,
  });

  final Map<String, Object?> update;
  final int? remainingAttempts;
  final bool lockoutTriggered;
  final int? lockoutCount;
  final int? lockedUntil;
  final bool? requiresEmergencyRecovery;
}

class LockoutPolicy {
  LockoutPolicy({
    this.maxFailedAttempts = 5,
    this.lockoutDurationMs = 900000,
    this.maxLockoutPeriods = 3,
  });

  final int maxFailedAttempts;
  final int lockoutDurationMs;
  final int maxLockoutPeriods;

  LockState evaluate({
    required int? lockedUntil,
    required int lockoutCount,
  }) {
    final timestamp = nowMs();
    final isLocked = lockedUntil != null && lockedUntil > timestamp;

    return LockState(
      isLocked: isLocked,
      lockedUntil: isLocked ? lockedUntil : null,
      remainingSeconds:
          isLocked ? ((lockedUntil - timestamp) / 1000).ceil() : 0,
      requiresEmergencyRecovery: !isLocked && lockoutCount >= maxLockoutPeriods,
    );
  }

  FailedAttemptResult onFailedAttempt({
    required int failedAttempts,
    required int lockoutCount,
    required int version,
  }) {
    final nextFailed = failedAttempts + 1;
    final timestamp = nowMs();
    final update = <String, Object?>{
      'failed_attempts': nextFailed,
      'updated_at': timestamp,
      'version': version + 1,
    };

    if (nextFailed >= maxFailedAttempts) {
      final nextLockoutCount = lockoutCount + 1;
      final nextLockedUntil = timestamp + lockoutDurationMs;
      update
        ..['failed_attempts'] = 0
        ..['locked_until'] = nextLockedUntil
        ..['lockout_count'] = nextLockoutCount;

      return FailedAttemptResult(
        update: update,
        lockoutTriggered: true,
        lockoutCount: nextLockoutCount,
        lockedUntil: nextLockedUntil,
        requiresEmergencyRecovery: nextLockoutCount >= maxLockoutPeriods,
      );
    }

    return FailedAttemptResult(
      update: update,
      lockoutTriggered: false,
      remainingAttempts: maxFailedAttempts - nextFailed,
    );
  }
}
