import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/licensing/domain/module_access_guard.dart';

import 'package:venteapp/core/policies/access_policy_resolver.dart';
import 'package:venteapp/core/policies/admin_policy.dart';
import 'package:venteapp/core/policies/app_preferences.dart';
import 'package:venteapp/core/policies/arike_action.dart';
import 'package:venteapp/core/policies/arike_access_facade.dart';
import 'package:venteapp/core/policies/arike_settings_snapshot.dart';
import 'package:venteapp/core/policies/effective_settings_resolver.dart';
import 'package:venteapp/core/policies/settings_snapshot_controller.dart';

class MockModuleAccessGuard implements ModuleAccessGuard {
  MockModuleAccessGuard({
    this.authorizedModules = const [ArikeModule.sales, ArikeModule.inventory],
    this.isSuspended = false,
  });

  final List<ArikeModule> authorizedModules;
  final bool isSuspended;

  @override
  bool isModuleAuthorized(ArikeModule module) {
    if (isSuspended) return false;
    return authorizedModules.contains(module);
  }

  @override
  bool canCreateNewTransaction() => !isSuspended;

  @override
  LicenseState getLicenseState() => isSuspended ? LicenseState.suspended : LicenseState.active;

  @override
  LicenseInfo getLicenseInfo() => throw UnimplementedError();

  @override
  int getRemainingGraceDays() => 7;
}

void main() {
  group('AccessPolicyResolver Tests', () {
    late ArikeSettingsSnapshot defaultBaseSnapshot;
    late AppPreferences defaultPrefs;
    late MockModuleAccessGuard validGuard;

    setUp(() {
      defaultBaseSnapshot = ArikeSettingsSnapshot.defaultSnapshot();
      defaultPrefs = AppPreferences.defaultPreferences;
      validGuard = MockModuleAccessGuard();
    });

    test('1. Cas nominal : Action autorisée quand toutes les conditions sont remplies', () {
      final resolver = EffectiveSettingsResolver(
        preferences: defaultPrefs,
        baseSnapshot: defaultBaseSnapshot,
      );

      final accessResolver = AccessPolicyResolver(
        effectiveSettingsResolver: resolver,
        moduleAccessGuard: validGuard,
      );

      final decision = accessResolver.evaluateAction(
        action: ArikeAction.createSale,
        userPermissions: {'sales.create'},
      );

      expect(decision.isAllowed, isTrue);
    });

    test('2. Blocage Admin : Compte suspendu (TENANT_STATUS = INACTIVE)', () {
      const tenantPolicy = AdminPolicy(
        code: AdminPolicy.tenantStatus,
        value: 'INACTIVE',
        enforced: true,
        lockReason: 'Compte suspendu pour non-paiement.',
      );

      final resolver = EffectiveSettingsResolver(
        preferences: defaultPrefs,
        baseSnapshot: defaultBaseSnapshot,
        adminPolicies: [tenantPolicy],
      );

      final accessResolver = AccessPolicyResolver(
        effectiveSettingsResolver: resolver,
        moduleAccessGuard: validGuard,
      );

      final decision = accessResolver.evaluateAction(
        action: ArikeAction.createSale,
        userPermissions: {'sales.create'},
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('TENANT_SUSPENDED'));
      expect(decision.reason, equals('Compte suspendu pour non-paiement.'));
    });

    test('3. Blocage Admin : Mode lecture seule (FORCE_READONLY = true)', () {
      const readonlyPolicy = AdminPolicy(
        code: AdminPolicy.forceReadonly,
        value: true,
        enforced: true,
        lockReason: 'Maintenance planifiée ARIKE.',
      );

      final resolver = EffectiveSettingsResolver(
        preferences: defaultPrefs,
        baseSnapshot: defaultBaseSnapshot,
        adminPolicies: [readonlyPolicy],
      );

      final accessResolver = AccessPolicyResolver(
        effectiveSettingsResolver: resolver,
        moduleAccessGuard: validGuard,
      );

      final decision = accessResolver.evaluateAction(
        action: ArikeAction.createSale,
        userPermissions: {'sales.create'},
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('FORCE_READONLY'));
    });

    test('4. Blocage Licence : Module Bureau de Change non inclus', () {
      final resolver = EffectiveSettingsResolver(
        preferences: defaultPrefs,
        baseSnapshot: defaultBaseSnapshot,
      );

      final accessResolver = AccessPolicyResolver(
        effectiveSettingsResolver: resolver,
        moduleAccessGuard: validGuard, // Seuls sales et inventory sont autorisés
      );

      final decision = accessResolver.evaluateAction(
        action: ArikeAction.accessFxExchange,
        userPermissions: {'fx.read'},
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('LICENSE_MODULE_DISABLED'));
    });

    test('5. Blocage RBAC : Permission manquante au niveau utilisateur', () {
      final resolver = EffectiveSettingsResolver(
        preferences: defaultPrefs,
        baseSnapshot: defaultBaseSnapshot,
      );

      final accessResolver = AccessPolicyResolver(
        effectiveSettingsResolver: resolver,
        moduleAccessGuard: validGuard,
      );

      final decision = accessResolver.evaluateAction(
        action: ArikeAction.sellOnCredit,
        userPermissions: {'sales.create'}, // Manque 'sales.credit'
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('PERMISSIONS_FORBIDDEN'));
      expect(decision.requiredPermission, equals('sales.credit'));
    });

    test('6. ArikeAccessFacade — Evaluation fluide et accès aux settings', () {
      final controller = SettingsSnapshotController.instance;

      final facade = ArikeAccessFacade(
        settingsController: controller,
        moduleAccessGuard: validGuard,
      );

      final decision = facade.canExecute(
        ArikeAction.createSale,
        userPermissions: {'sales.create'},
      );

      expect(decision.isAllowed, isTrue);

      final maxDiscountSetting = facade.getSetting((r) => r.maxDiscountPercent);
      expect(maxDiscountSetting.value, equals(100.0));
      expect(maxDiscountSetting.isLocked, isFalse);
    });
  });
}
