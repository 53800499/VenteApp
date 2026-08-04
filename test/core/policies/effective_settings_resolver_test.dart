import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/policies/admin_policy.dart';
import 'package:venteapp/core/policies/app_preferences.dart';
import 'package:venteapp/core/policies/arike_settings_snapshot.dart';
import 'package:venteapp/core/policies/configuration_sync_dto.dart';
import 'package:venteapp/core/policies/effective_setting.dart';
import 'package:venteapp/core/policies/effective_settings_resolver.dart';
import 'package:venteapp/core/policies/settings_snapshot_controller.dart';

void main() {
  group('EffectiveSettingsResolver Tests', () {
    late ArikeSettingsSnapshot defaultBaseSnapshot;
    late AppPreferences defaultPrefs;

    setUp(() {
      defaultBaseSnapshot = ArikeSettingsSnapshot.defaultSnapshot();
      defaultPrefs = AppPreferences.defaultPreferences;
    });

    test('1. Priorité 3 (Shop Setting) : Utilisée en l\'absence de politique admin', () {
      final shopSnapshot = ArikeSettingsSnapshot(
        version: 1,
        company: defaultBaseSnapshot.company,
        sales: const SalesSettings(maxDiscountPercent: 20.0),
        inventory: defaultBaseSnapshot.inventory,
        orders: defaultBaseSnapshot.orders,
        procurement: defaultBaseSnapshot.procurement,
        debts: defaultBaseSnapshot.debts,
        cash: defaultBaseSnapshot.cash,
        receipts: defaultBaseSnapshot.receipts,
        notifications: defaultBaseSnapshot.notifications,
        sync: defaultBaseSnapshot.sync,
        security: defaultBaseSnapshot.security,
        updatedAt: DateTime.now(),
      );

      final resolver = EffectiveSettingsResolver(
        preferences: defaultPrefs,
        baseSnapshot: shopSnapshot,
      );

      final setting = resolver.maxDiscountPercent;
      expect(setting.value, equals(20.0));
      expect(setting.source, equals(SettingSource.shopSetting));
      expect(setting.isLocked, isFalse);
      expect(setting.lockReason, isNull);
    });

    test('2. Priorité 1 (Admin Policy) : Surpasse le paramètre boutique si enforced', () {
      final shopSnapshot = ArikeSettingsSnapshot(
        version: 1,
        company: defaultBaseSnapshot.company,
        sales: const SalesSettings(maxDiscountPercent: 25.0),
        inventory: defaultBaseSnapshot.inventory,
        orders: defaultBaseSnapshot.orders,
        procurement: defaultBaseSnapshot.procurement,
        debts: defaultBaseSnapshot.debts,
        cash: defaultBaseSnapshot.cash,
        receipts: defaultBaseSnapshot.receipts,
        notifications: defaultBaseSnapshot.notifications,
        sync: defaultBaseSnapshot.sync,
        security: defaultBaseSnapshot.security,
        updatedAt: DateTime.now(),
      );

      const adminCapPolicy = AdminPolicy(
        code: AdminPolicy.maxDiscountCap,
        value: 10.0,
        enforced: true,
        lockReason: 'Plafond de remise imposé par ARIKE (10%).',
      );

      final resolver = EffectiveSettingsResolver(
        preferences: defaultPrefs,
        baseSnapshot: shopSnapshot,
        adminPolicies: [adminCapPolicy],
      );

      final setting = resolver.maxDiscountPercent;
      expect(setting.value, equals(10.0));
      expect(setting.source, equals(SettingSource.adminPolicy));
      expect(setting.isLocked, isTrue);
      expect(setting.lockReason, equals('Plafond de remise imposé par ARIKE (10%).'));
    });

    test('3. Priorité 1 (Admin Policy) : Stock négatif forcé à DENY', () {
      final shopSnapshot = ArikeSettingsSnapshot(
        version: 1,
        company: defaultBaseSnapshot.company,
        sales: defaultBaseSnapshot.sales,
        inventory: const InventorySettings(negativeStockMode: NegativeStockMode.allow),
        orders: defaultBaseSnapshot.orders,
        procurement: defaultBaseSnapshot.procurement,
        debts: defaultBaseSnapshot.debts,
        cash: defaultBaseSnapshot.cash,
        receipts: defaultBaseSnapshot.receipts,
        notifications: defaultBaseSnapshot.notifications,
        sync: defaultBaseSnapshot.sync,
        security: defaultBaseSnapshot.security,
        updatedAt: DateTime.now(),
      );

      const adminStockPolicy = AdminPolicy(
        code: AdminPolicy.negativeStockOverride,
        value: 'DENY',
        enforced: true,
        lockReason: 'Stock négatif strictement interdit par l\'administration.',
      );

      final resolver = EffectiveSettingsResolver(
        preferences: defaultPrefs,
        baseSnapshot: shopSnapshot,
        adminPolicies: [adminStockPolicy],
      );

      final setting = resolver.negativeStockMode;
      expect(setting.value, equals(NegativeStockMode.deny));
      expect(setting.isLocked, isTrue);
      expect(setting.source, equals(SettingSource.adminPolicy));
    });

    test('4. Preferences Utilisateur : Incorruptibles par le Back-Office Admin', () {
      final customPrefs = defaultPrefs.copyWith(
        themeMode: 'dark',
        language: 'yo',
        paperWidthMm: 58,
      );

      final resolver = EffectiveSettingsResolver(
        preferences: customPrefs,
        baseSnapshot: defaultBaseSnapshot,
        adminPolicies: [
          const AdminPolicy(code: 'THEME', value: 'light', enforced: true),
        ],
      );

      expect(resolver.themeMode.value, equals('dark'));
      expect(resolver.themeMode.source, equals(SettingSource.userPreference));
      expect(resolver.language.value, equals('yo'));
    });

    test('5. SettingsSnapshotController — Application DTO sync et Hot-swap du Policy Engine', () {
      final controller = SettingsSnapshotController.instance;

      final syncDto = ConfigurationSyncDto(
        serverTime: DateTime.now(),
        configurationVersion: 50,
        adminPolicies: [
          const AdminPolicy(
            code: AdminPolicy.maxDiscountCap,
            value: 5.0,
            enforced: true,
            lockReason: 'Remise limitée à 5%.',
          ),
        ],
      );

      controller.updateFromSyncDto(
        syncDto: syncDto,
        preferences: defaultPrefs,
        shopBaseSnapshot: defaultBaseSnapshot,
      );

      final effectiveDiscountSetting = controller.activeResolver.maxDiscountPercent;
      expect(effectiveDiscountSetting.value, equals(5.0));
      expect(effectiveDiscountSetting.isLocked, isTrue);

      // Vérification que le Policy Engine applique immédiatement la décision
      final decision = controller.engine.sales.canApplyDiscount(requestedPercent: 10.0);
      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('SALES_DISCOUNT_EXCEEDED'));
    });
  });
}
