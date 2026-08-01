import '../security/clock_tampering_detector.dart';
import '../security/license_verifier.dart';

enum ArikeModule {
  sales,
  inventory,
  purchases,
  expenses,
  fxExchange,
  assistant,
  reports,
  multiShop,
  apiAccess,
}

enum LicenseState {
  active,
  inGracePeriod,
  restrictedReadOnly,
  clockTamperDetected,
  minorClockWarning,
  moderateClockAlert,
  noLicenseRecovery,
  tenantMismatch,
  expired,
  suspended,
}

class LicenseInfo {
  final String tenantId;
  final String planCode;
  final LicenseState state;
  final List<ArikeModule> grantedModules;
  final DateTime validFrom;
  final DateTime validUntil;
  final DateTime graceUntil;
  final int remainingGraceDays;
  final int maxUsers;
  final int maxShops;

  const LicenseInfo({
    required this.tenantId,
    required this.planCode,
    required this.state,
    required this.grantedModules,
    required this.validFrom,
    required this.validUntil,
    required this.graceUntil,
    required this.remainingGraceDays,
    required this.maxUsers,
    required this.maxShops,
  });
}

abstract class ModuleAccessGuard {
  bool isModuleAuthorized(ArikeModule module);
  LicenseState getLicenseState();
  LicenseInfo getLicenseInfo();
  bool canCreateNewTransaction();
  int getRemainingGraceDays();
}

class ModuleAccessGuardImpl implements ModuleAccessGuard {
  final SignedLicensePayload? _license;
  final String _activeTenantId;
  final DateTime _lastKnownTimestamp;
  final DateTime Function() _nowProvider;

  ModuleAccessGuardImpl({
    required SignedLicensePayload? license,
    required String activeTenantId,
    required DateTime lastKnownTimestamp,
    DateTime Function()? nowProvider,
  })  : _license = license,
        _activeTenantId = activeTenantId,
        _lastKnownTimestamp = lastKnownTimestamp,
        _nowProvider = nowProvider ?? (() => DateTime.now());

  @override
  LicenseState getLicenseState() {
    // 0. Missing license check
    if (_license == null) {
      return LicenseState.noLicenseRecovery;
    }

    // 1. Tenant mismatch check
    if (_license!.tenantId != _activeTenantId) {
      return LicenseState.tenantMismatch;
    }

    final now = _nowProvider();

    // 2. Clock Evaluation (4-Tier Matrix)
    final clockResult = ClockTamperingDetector.evaluateClock(
      currentSystemTime: now,
      lastKnownTimestamp: _lastKnownTimestamp,
    );

    if (clockResult == ClockCheckResult.majorTamperBlocked) {
      return LicenseState.clockTamperDetected;
    }

    // 3. Signature verification check
    if (!LicenseVerifier.verifyLicense(
      newLicense: _license!,
      activeTenantId: _activeTenantId,
    )) {
      return LicenseState.suspended;
    }

    // 4. Status check
    if (_license!.status == 'SUSPENDED') {
      return LicenseState.suspended;
    }

    // 5. Desync warnings & alerts
    if (clockResult == ClockCheckResult.moderateDesyncAlert) {
      return LicenseState.moderateClockAlert;
    }
    if (clockResult == ClockCheckResult.minorDesyncWarning) {
      return LicenseState.minorClockWarning;
    }

    // 6. Validity dates
    if (!now.isBefore(_license!.validFrom) && !now.isAfter(_license!.validUntil)) {
      return LicenseState.active;
    }

    if (!now.isAfter(_license!.graceUntil)) {
      return LicenseState.inGracePeriod;
    }

    return LicenseState.restrictedReadOnly;
  }

  @override
  bool isModuleAuthorized(ArikeModule module) {
    final state = getLicenseState();

    if (state == LicenseState.suspended ||
        state == LicenseState.tenantMismatch ||
        state == LicenseState.clockTamperDetected) {
      return false;
    }

    if (_license == null) return false;

    final moduleKey = module.name;
    return _license!.grantedModules.contains(moduleKey);
  }

  @override
  bool canCreateNewTransaction() {
    final state = getLicenseState();
    return state == LicenseState.active ||
        state == LicenseState.inGracePeriod ||
        state == LicenseState.minorClockWarning ||
        state == LicenseState.moderateClockAlert;
  }

  @override
  int getRemainingGraceDays() {
    if (_license == null) return 0;
    final now = _nowProvider();
    if (now.isAfter(_license!.graceUntil)) return 0;
    final difference = _license!.graceUntil.difference(now);
    return difference.inDays.clamp(0, 365);
  }

  @override
  LicenseInfo getLicenseInfo() {
    final state = getLicenseState();
    final granted = (_license?.grantedModules ?? [])
        .map((m) => ArikeModule.values.firstWhere(
              (element) => element.name == m,
              orElse: () => ArikeModule.sales,
            ))
        .toList();

    return LicenseInfo(
      tenantId: _license?.tenantId ?? _activeTenantId,
      planCode: _license?.planCode ?? 'NONE',
      state: state,
      grantedModules: granted,
      validFrom: _license?.validFrom ?? DateTime.now(),
      validUntil: _license?.validUntil ?? DateTime.now(),
      graceUntil: _license?.graceUntil ?? DateTime.now(),
      remainingGraceDays: getRemainingGraceDays(),
      maxUsers: _license?.maxUsers ?? 1,
      maxShops: _license?.maxShops ?? 1,
    );
  }
}

