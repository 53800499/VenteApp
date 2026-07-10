import 'user_role.dart';

enum Permission {
  authSessionTouch('auth:session:touch'),
  authBiometricEnable('auth:biometric:enable'),
  dashboardRead('dashboard:read'),
  dashboardFinancial('dashboard:financial'),
  inventoryRead('inventory:read'),
  inventoryWrite('inventory:write'),
  inventoryAdjust('inventory:adjust'),
  inventoryArchive('inventory:archive'),
  salesCreate('sales:create'),
  salesRead('sales:read'),
  salesCancel('sales:cancel'),
  salesPriceOverride('sales:price_override'),
  paymentsCreate('payments:create'),
  paymentsRead('payments:read'),
  customersRead('customers:read'),
  customersWrite('customers:write'),
  customersArchive('customers:archive'),
  debtsRead('debts:read'),
  debtsPayment('debts:payment'),
  debtsForgive('debts:forgive'),
  settingsRead('settings:read'),
  settingsWrite('settings:write'),
  usersRead('users:read'),
  usersCreate('users:create'),
  usersUpdateRole('users:update_role'),
  usersDeactivate('users:deactivate'),
  usersAssignShop('users:assign_shop'),
  rbacRead('rbac:read'),
  rbacManage('rbac:manage'),
  rbacOverride('rbac:override'),
  reportsRead('reports:read'),
  reportsFinancial('reports:financial'),
  expensesRead('expenses:read'),
  expensesCreate('expenses:create'),
  expensesUpdate('expenses:update'),
  expensesArchive('expenses:archive'),
  expensesCategories('expenses:categories'),
  auditRead('audit:read'),
  shopsRead('shops:read'),
  shopsCreate('shops:create'),
  shopsUpdate('shops:update'),
  shopsDeactivate('shops:deactivate'),
  shopsSwitch('shops:switch'),
  shopsConsolidatedRead('shops:consolidated_read'),
  cashSessionsRead('cash_sessions:read'),
  cashSessionsOpen('cash_sessions:open'),
  cashSessionsClose('cash_sessions:close'),
  cashSessionsAdjust('cash_sessions:adjust'),
  calculatorsUse('calculators:use'),
  calculatorsExport('calculators:export'),
  calculatorsHistory('calculators:history');

  const Permission(this.code);

  final String code;
}

const _sellerPermissions = <Permission>{
  Permission.authSessionTouch,
  Permission.authBiometricEnable,
  Permission.dashboardRead,
  Permission.inventoryRead,
  Permission.salesCreate,
  Permission.salesRead,
  Permission.paymentsCreate,
  Permission.paymentsRead,
  Permission.customersRead,
  Permission.customersWrite,
  Permission.debtsRead,
  Permission.debtsPayment,
  Permission.expensesRead,
  Permission.expensesCreate,
  Permission.cashSessionsRead,
  Permission.cashSessionsOpen,
  Permission.cashSessionsClose,
  Permission.cashSessionsAdjust,
  Permission.calculatorsUse,
  Permission.calculatorsExport,
  Permission.calculatorsHistory,
};

const _viewerPermissions = <Permission>{
  Permission.authSessionTouch,
  Permission.dashboardRead,
  Permission.inventoryRead,
  Permission.salesRead,
  Permission.paymentsRead,
  Permission.customersRead,
  Permission.debtsRead,
  Permission.reportsRead,
  Permission.expensesRead,
  Permission.cashSessionsRead,
  Permission.calculatorsUse,
  Permission.calculatorsHistory,
};

Set<Permission> permissionsForRole(UserRole role) {
  switch (role) {
    case UserRole.owner:
      return Permission.values.toSet();
    case UserRole.seller:
      return _sellerPermissions;
    case UserRole.viewer:
      return _viewerPermissions;
  }
}
