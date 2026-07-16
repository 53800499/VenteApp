/// Entités suivies pour le cache pull cloud (stale time par type).
abstract final class SyncPullEntity {
  static const customers = 'customers';
  static const products = 'products';
  static const sales = 'sales';
  static const debts = 'debts';
  static const expenses = 'expenses';
  static const cashSessions = 'cash_sessions';
  static const calculators = 'calculators';
  static const procurement = 'procurement';
  static const inventoryLots = 'inventory_lots';

  /// Détail d'un client (pull ciblé GET /customers/:id).
  static String customerDetail(int customerId) => 'customer_detail:$customerId';

  /// Durée avant qu'un pull navigation soit considéré « frais ».
  static Duration staleTimeFor(String entity) {
    if (entity.startsWith('customer_detail:')) {
      return const Duration(minutes: 5);
    }
    return switch (entity) {
      sales => const Duration(minutes: 2),
      debts => const Duration(minutes: 2),
      cashSessions => const Duration(minutes: 1),
      procurement => const Duration(minutes: 5),
      _ => const Duration(minutes: 5),
    };
  }

  /// Entités pull invalidées après une écriture locale sur [entityTable].
  static List<String> invalidatedByWrite(String entityTable, {int? recordId}) {
    switch (entityTable) {
      case 'customers':
        final entities = <String>[customers];
        if (recordId != null) {
          entities.add(customerDetail(recordId));
        }
        return entities;
      case 'categories':
      case 'products':
        return [products, inventoryLots];
      case 'sales':
        return [sales, customers, debts];
      case 'debts':
        final entities = <String>[debts, customers];
        if (recordId != null) {
          // Les dettes n'ont pas d'ID client ici — invalidation globale debts/customers.
        }
        return entities;
      case 'expenses':
        return [expenses];
      case 'cash_sessions':
      case 'cash_movements':
        return [cashSessions];
      case 'tenant_modules':
      case 'calculator_product_data':
      case 'calculator_history':
        return [calculators];
      case 'suppliers':
      case 'purchase_orders':
      case 'purchase_receipts':
      case 'supplier_invoices':
      case 'supplier_payments':
        return [procurement, inventoryLots, products];
      default:
        return const [];
    }
  }
}
