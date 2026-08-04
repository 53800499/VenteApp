import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/policies/arike_policy_engine.dart';
import 'package:venteapp/core/policies/arike_settings_snapshot.dart';
import 'package:venteapp/core/policies/policy_decision.dart';
import 'package:venteapp/core/policies/settings_snapshot_controller.dart';

void main() {
  group('ArikePolicyEngine Tests', () {
    late ArikePolicyEngine engine;

    setUp(() {
      engine = ArikePolicyEngine(ArikeSettingsSnapshot.defaultSnapshot());
    });

    test('SalesPolicy — Vente à crédit autorisée par défaut', () {
      final decision = engine.sales.canSellOnCredit();
      expect(decision.isAllowed, isTrue);
    });

    test('SalesPolicy — Vente à crédit bloquée si désactivée', () {
      final snapshot = ArikeSettingsSnapshot.defaultSnapshot();
      final updated = ArikeSettingsSnapshot(
        version: 2,
        company: snapshot.company,
        sales: const SalesSettings(allowCredit: false),
        inventory: snapshot.inventory,
        orders: snapshot.orders,
        procurement: snapshot.procurement,
        debts: snapshot.debts,
        cash: snapshot.cash,
        receipts: snapshot.receipts,
        notifications: snapshot.notifications,
        sync: snapshot.sync,
        security: snapshot.security,
        updatedAt: DateTime.now(),
      );
      engine.updateSnapshot(updated);

      final decision = engine.sales.canSellOnCredit();
      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('SALES_CREDIT_DISABLED'));
    });

    test('InventoryPolicy — Mode WARNING autorise la vente négative avec avertissement', () {
      final decision = engine.inventory.canDecreaseStock(
        currentStock: 2,
        requestedQuantity: 5,
      );
      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('INVENTORY_NEGATIVE_STOCK_WARNING'));
    });

    test('InventoryPolicy — Mode DENY bloque la vente négative', () {
      final snapshot = ArikeSettingsSnapshot.defaultSnapshot();
      final updated = ArikeSettingsSnapshot(
        version: 2,
        company: snapshot.company,
        sales: snapshot.sales,
        inventory: const InventorySettings(negativeStockMode: NegativeStockMode.deny),
        orders: snapshot.orders,
        procurement: snapshot.procurement,
        debts: snapshot.debts,
        cash: snapshot.cash,
        receipts: snapshot.receipts,
        notifications: snapshot.notifications,
        sync: snapshot.sync,
        security: snapshot.security,
        updatedAt: DateTime.now(),
      );
      engine.updateSnapshot(updated);

      final decision = engine.inventory.canDecreaseStock(
        currentStock: 2,
        requestedQuantity: 5,
      );
      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('INVENTORY_NEGATIVE_STOCK_DENIED'));
    });

    test('CashPolicy — Requis ouverture de caisse', () {
      final snapshot = ArikeSettingsSnapshot.defaultSnapshot();
      final updated = ArikeSettingsSnapshot(
        version: 2,
        company: snapshot.company,
        sales: snapshot.sales,
        inventory: snapshot.inventory,
        orders: snapshot.orders,
        procurement: snapshot.procurement,
        debts: snapshot.debts,
        cash: const CashSettings(requireCashSessionOpening: true),
        receipts: snapshot.receipts,
        notifications: snapshot.notifications,
        sync: snapshot.sync,
        security: snapshot.security,
        updatedAt: DateTime.now(),
      );
      engine.updateSnapshot(updated);

      final decision = engine.cash.canPerformCashTransaction(isCashSessionOpen: false);
      expect(decision.isAllowed, isFalse);
      expect(decision.errorCode, equals('CASH_SESSION_REQUIRED'));
    });

    test('SettingsSnapshotController — In-memory atomic hot-swap', () {
      final controller = SettingsSnapshotController.instance;
      final initialVersion = controller.value.version;

      final newSnapshot = ArikeSettingsSnapshot.defaultSnapshot(version: initialVersion + 1);
      controller.swapSnapshotAtomically(newSnapshot);

      expect(controller.value.version, equals(initialVersion + 1));
      expect(controller.engine.snapshot.version, equals(initialVersion + 1));
    });
  });
}
