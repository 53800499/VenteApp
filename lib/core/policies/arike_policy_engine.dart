import 'arike_settings_snapshot.dart';
import 'domain_policies.dart';

/// Moteur centralisé d'application des règles métier ARIKE.
class ArikePolicyEngine {
  ArikePolicyEngine(this._snapshot);

  ArikeSettingsSnapshot _snapshot;

  /// Met à jour le snapshot actif (utilisé lors du Hot-swap après Sync).
  void updateSnapshot(ArikeSettingsSnapshot newSnapshot) {
    _snapshot = newSnapshot;
  }

  ArikeSettingsSnapshot get snapshot => _snapshot;

  SalesPolicy get sales => SalesPolicy(_snapshot.sales);
  InventoryPolicy get inventory => InventoryPolicy(_snapshot.inventory);
  CashPolicy get cash => CashPolicy(_snapshot.cash);
  DebtPolicy get debts => DebtPolicy(_snapshot.debts);
  OrderPolicy get orders => OrderPolicy(_snapshot.orders);
  ReceiptPolicy get receipts => ReceiptPolicy(_snapshot.receipts);
  LicensePolicy get license => const LicensePolicy();
}
