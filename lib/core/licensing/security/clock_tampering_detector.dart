enum ClockCheckResult {
  /// < 5 minutes: Normal operation or silent correction
  normal,
  /// 5 to 60 minutes: Gentle warning banner, allow all operations
  minorDesyncWarning,
  /// 1 to 24 hours: Strong warning alert, prompt for resynchronization, allow writes
  moderateDesyncAlert,
  /// > 24 hours: Critical tampering or clock desync, block new writes (read/export/sync only)
  majorTamperBlocked,
}

class ClockTamperingDetector {
  /// Evaluates clock deviation against the graduated 4-tier Time Drift Matrix.
  static ClockCheckResult evaluateClock({
    required DateTime currentSystemTime,
    required DateTime lastKnownTimestamp,
  }) {
    if (currentSystemTime.isBefore(lastKnownTimestamp)) {
      final differenceInMinutes = lastKnownTimestamp.difference(currentSystemTime).inMinutes;

      // Tier 1: Less than 5 minutes -> Ignored or silently handled
      if (differenceInMinutes < 5) {
        return ClockCheckResult.normal;
      }

      // Tier 2: 5 to 60 minutes -> Gentle warning banner
      if (differenceInMinutes <= 60) {
        return ClockCheckResult.minorDesyncWarning;
      }

      // Tier 3: 1 to 24 hours (60 to 1440 minutes) -> Strong alert + sync prompt
      if (differenceInMinutes <= 1440) {
        return ClockCheckResult.moderateDesyncAlert;
      }

      // Tier 4: Greater than 24 hours -> Block new write operations
      return ClockCheckResult.majorTamperBlocked;
    }

    return ClockCheckResult.normal;
  }

  /// High-water mark update logic using max(lastKnownTimestamp, serverTimestamp)
  static DateTime computeNextHighWaterMark({
    required DateTime currentSystemTime,
    required DateTime lastKnownTimestamp,
    DateTime? verifiedServerTime,
  }) {
    // 1. If a verified server timestamp is received during sync, compute max(lastKnown, serverTime)
    if (verifiedServerTime != null) {
      return verifiedServerTime.isAfter(lastKnownTimestamp) ? verifiedServerTime : lastKnownTimestamp;
    }

    // 2. Otherwise update to maximum observed timestamp
    if (currentSystemTime.isAfter(lastKnownTimestamp)) {
      return currentSystemTime;
    }
    return lastKnownTimestamp;
  }
}

