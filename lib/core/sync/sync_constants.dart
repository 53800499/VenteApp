/// Tables métier suivies par `sync_queue` (BDD §3.2).
abstract final class SyncEntityTable {
  static const customers = 'customers';
  static const categories = 'categories';
  static const products = 'products';
  static const sales = 'sales';
  static const debts = 'debts';
}

/// Opérations poussées vers le cloud (FIFO).
abstract final class SyncOperation {
  static const create = 'create';
  static const update = 'update';
  static const archive = 'archive';
  static const stockAdjust = 'stock_adjust';
  static const payment = 'payment';
  static const forgive = 'forgive';
  static const cancel = 'cancel';
  static const saleQuick = 'sale_quick';
}
