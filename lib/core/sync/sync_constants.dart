/// Tables métier suivies par `sync_queue` (BDD §3.2).
abstract final class SyncEntityTable {
  static const customers = 'customers';
  static const categories = 'categories';
  static const products = 'products';
  static const sales = 'sales';
  static const debts = 'debts';
  static const expenses = 'expenses';
  static const cashSessions = 'cash_sessions';
  static const cashMovements = 'cash_movements';
  static const tenantModules = 'tenant_modules';
  static const calculatorProductData = 'calculator_product_data';
  static const calculatorHistory = 'calculator_history';
  static const suppliers = 'suppliers';
  static const purchaseOrders = 'purchase_orders';
  static const purchaseReceipts = 'purchase_receipts';
  static const supplierInvoices = 'supplier_invoices';
  static const supplierPayments = 'supplier_payments';
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
  static const cashSessionOpen = 'cash_session_open';
  static const cashSessionClose = 'cash_session_close';
  static const cashMovementCreate = 'cash_movement_create';
  static const validate = 'validate';
  static const send = 'send';
  static const receive = 'receive';
}
