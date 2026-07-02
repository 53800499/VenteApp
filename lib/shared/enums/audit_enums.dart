/// Actions journalisées — aligné sur `backend/src/shared/enums/audit.enum.ts`.
enum AuditAction {
  emergencyUnlock('emergency_unlock'),
  userRoleChanged('user_role_changed'),
  userShopAssigned('user_shop_assigned'),
  rbacOverridesReplaced('rbac_overrides_replaced'),
  debtCreated('debt_created'),
  debtPaymentRecorded('debt_payment_recorded'),
  debtForgiven('debt_forgiven'),
  saleCreated('sale_created'),
  saleCancelled('sale_cancelled'),
  stockAdjusted('stock_adjusted'),
  productPriceChanged('product_price_changed'),
  productArchived('product_archived'),
  productDeleted('product_deleted'),
  categoryDeleted('category_deleted'),
  shopCreated('shop_created'),
  shopUpdated('shop_updated'),
  shopDeactivated('shop_deactivated'),
  shopDefaultSet('shop_default_set'),
  shopSwitched('shop_switched'),
  customerArchived('customer_archived'),
  customerCreated('customer_created'),
  customerUpdated('customer_updated'),
  settingsUpdated('settings_updated'),
  backupRecorded('backup_recorded'),
  syncSettingsUpdated('sync_settings_updated'),
  syncConflictResolved('sync_conflict_resolved');

  const AuditAction(this.code);

  final String code;

  static AuditAction? tryFromCode(String code) {
    for (final value in AuditAction.values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

enum AuditModule {
  auth('auth'),
  settings('settings'),
  users('users'),
  sales('sales'),
  debts('debts'),
  products('products'),
  shops('shops'),
  customers('customers'),
  sync('sync');

  const AuditModule(this.code);

  final String code;

  static AuditModule? tryFromCode(String code) {
    for (final value in AuditModule.values) {
      if (value.code == code) return value;
    }
    return null;
  }
}
