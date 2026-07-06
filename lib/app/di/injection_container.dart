import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audit/local_audit_writer.dart';
import '../../core/backup/google_drive_backup_service.dart';
import '../../core/backup/shop_backup_service.dart';
import '../../core/database/app_database.dart';
import '../../core/auth/app_lock_controller.dart';
import '../../core/auth/cloud_session_coordinator.dart';
import '../../core/network/online_session_policy.dart';
import '../../core/network/remote_api_runner.dart';
import '../../core/network/remote_api_guard.dart';
import '../../core/network/active_shop_context.dart';
import '../../core/network/api_client.dart';
import '../../core/network/network_info.dart';
import '../../core/security/lockout_policy.dart';
import '../../core/security/pin_hasher.dart';
import '../../core/security/recovery_token_service.dart';
import '../../core/storage/api_settings_storage.dart';
import '../../core/storage/auth_credentials_storage.dart';
import '../../core/storage/auth_flow_storage.dart';
import '../../core/storage/device_id_storage.dart';
import '../../core/storage/last_shop_storage.dart';
import '../../core/storage/onboarding_storage.dart';
import '../../core/storage/session_storage.dart';
import '../../features/auth/data/datasources/local/biometric_local_datasource.dart';
import '../../features/auth/data/datasources/remote/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../core/sync/cloud_sync_enabler.dart';
import '../../core/sync/cloud_sync_preferences.dart';
import '../../core/sync/local_write_sync_recorder.dart';
import '../../core/sync/sync_adapters.dart';
import '../../core/sync/sync_policy.dart';
import '../../core/sync/sync_conflict_service.dart';
import '../../core/sync/sync_queue_datasource.dart';
import '../../core/sync/sync_queue_processor.dart';
import '../../core/sync/sync_service.dart';
import '../../features/dashboard/data/datasources/local/dashboard_local_datasource.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/services/dashboard_aggregation_service.dart';
import '../../features/dashboard/domain/usecases/get_dashboard.dart';
import '../../features/inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../features/inventory/data/datasources/remote/inventory_remote_datasource.dart';
import '../../features/inventory/data/repositories/inventory_repository_impl.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/inventory/domain/services/category_validation_service.dart';
import '../../features/inventory/domain/services/product_validation_service.dart';
import '../../features/inventory/domain/usecases/inventory_usecases.dart';
import '../../features/shop/data/datasources/remote/shop_remote_datasource.dart';
import '../../features/shop/data/repositories/shop_repository_impl.dart';
import '../../features/shop/domain/repositories/shop_repository.dart';
import '../../features/shop/domain/usecases/shop_usecases.dart';
import '../../features/users/data/datasources/remote/user_remote_datasource.dart';
import '../../features/users/data/repositories/user_repository_impl.dart';
import '../../features/users/domain/repositories/user_repository.dart';
import '../../features/users/domain/usecases/user_usecases.dart';
import '../../features/rbac/data/datasources/remote/rbac_remote_datasource.dart';
import '../../features/rbac/data/repositories/rbac_repository_impl.dart';
import '../../features/rbac/domain/repositories/rbac_repository.dart';
import '../../features/rbac/domain/usecases/rbac_usecases.dart';
import '../../features/rbac/domain/usecases/refresh_session_permissions.dart';
import '../../features/customers/data/datasources/local/customers_local_datasource.dart';
import '../../features/customers/data/datasources/remote/customers_remote_datasource.dart';
import '../../features/customers/data/repositories/customer_repository_impl.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/customers/domain/services/customer_validation_service.dart';
import '../../features/customers/domain/usecases/customer_usecases.dart';
import '../../features/debts/data/datasources/local/debts_local_datasource.dart';
import '../../features/debts/data/datasources/remote/debts_remote_datasource.dart';
import '../../features/debts/data/repositories/debt_repository_impl.dart';
import '../../features/debts/domain/repositories/debt_repository.dart';
import '../../features/debts/domain/services/debt_validation_service.dart';
import '../../features/debts/domain/usecases/debt_usecases.dart';
import '../../features/reports/data/datasources/local/reports_local_datasource.dart';
import '../../features/reports/data/datasources/remote/reports_remote_datasource.dart';
import '../../features/reports/data/repositories/report_repository_impl.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/reports/domain/services/report_aggregation_service.dart';
import '../../features/reports/domain/usecases/get_report.dart';
import '../../features/reports/presentation/services/report_pdf_exporter.dart';
import '../../features/sales_analysis/data/datasources/local/sales_analysis_local_datasource.dart';
import '../../features/sales_analysis/data/datasources/remote/sales_analysis_remote_datasource.dart';
import '../../features/sales_analysis/data/repositories/sales_analysis_repository_impl.dart';
import '../../features/sales_analysis/domain/repositories/sales_analysis_repository.dart';
import '../../features/sales_analysis/domain/usecases/sales_analysis_usecases.dart';
import '../../features/expenses/data/datasources/local/expenses_local_datasource.dart';
import '../../features/expenses/data/datasources/remote/expenses_remote_datasource.dart';
import '../../features/expenses/data/repositories/expense_repository_impl.dart';
import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/expenses/domain/usecases/expense_usecases.dart';
import '../../features/expenses/presentation/services/expense_pdf_exporter.dart';
import '../../features/notifications/data/datasources/local/notifications_local_datasource.dart';
import '../../features/notifications/data/datasources/remote/notifications_remote_datasource.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/services/notification_feed_builder.dart';
import '../../features/notifications/domain/usecases/notification_usecases.dart';
import '../../core/notifications/local_notification_service.dart';
import '../../core/notifications/notification_deep_link_handler.dart';
import '../../core/notifications/notification_orchestrator.dart';
import '../../features/settings/data/datasources/local/settings_local_datasource.dart';
import '../../features/settings/data/datasources/remote/settings_remote_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/services/settings_validation_service.dart';
import '../../features/settings/domain/usecases/settings_usecases.dart';
import '../../features/audit/data/datasources/local/audit_local_datasource.dart';
import '../../features/audit/data/datasources/remote/audit_remote_datasource.dart';
import '../../features/audit/data/mappers/audit_mapper.dart';
import '../../features/audit/data/repositories/audit_repository_impl.dart';
import '../../features/audit/domain/repositories/audit_repository.dart';
import '../../features/audit/domain/services/audit_label_service.dart';
import '../../features/audit/domain/usecases/audit_usecases.dart';
import '../../features/audit/presentation/services/audit_pdf_exporter.dart';
import '../../features/sales/data/datasources/local/sales_local_datasource.dart';
import '../../features/sales/data/datasources/local/customer_product_price_local_datasource.dart';
import '../../features/sales/data/datasources/remote/sales_remote_datasource.dart';
import '../../features/sales/data/repositories/sale_repository_impl.dart';
import '../../features/sales/domain/repositories/sale_repository.dart';
import '../../features/sales/domain/services/receipt_formatter_service.dart';
import '../../features/sales/domain/services/sale_validation_service.dart';
import '../../features/sales/domain/usecases/sale_usecases.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';

final sl = GetIt.instance;

/// Enregistre le module Statistiques si absent (hot reload après ajout DI).
void ensureReportsDependencies() {
  if (sl.isRegistered<GetReport>()) return;

  ensureExpensesDependencies();

  if (!sl.isRegistered<ReportAggregationService>()) {
    sl.registerLazySingleton(() => const ReportAggregationService());
  }
  if (!sl.isRegistered<ReportsLocalDatasource>()) {
    sl.registerLazySingleton(() => ReportsLocalDatasource(sl()));
  }
  if (!sl.isRegistered<ReportsRemoteDatasource>()) {
    sl.registerLazySingleton(() => ReportsRemoteDatasource(sl()));
  }
  if (!sl.isRegistered<ReportRepository>()) {
    sl.registerLazySingleton<ReportRepository>(
      () => ReportRepositoryImpl(
        local: sl(),
        remote: sl(),
        apiGuard: sl(),
        expensesLocal: sl<ExpensesLocalDatasource>(),
        aggregation: sl(),
      ),
    );
  }
  sl.registerLazySingleton<GetReport>(
    () => GetReport(sl<ReportRepository>()),
  );
  sl.registerLazySingleton(() => const ReportPdfExporter());
}

/// Enregistre le module Analyse des ventes si absent.
void ensureSalesAnalysisDependencies() {
  if (!sl.isRegistered<SalesAnalysisLocalDatasource>()) {
    sl.registerLazySingleton(() => SalesAnalysisLocalDatasource(sl()));
  }
  if (!sl.isRegistered<SalesAnalysisRemoteDatasource>()) {
    sl.registerLazySingleton(() => SalesAnalysisRemoteDatasource(sl()));
  }
  if (!sl.isRegistered<SalesAnalysisRepository>()) {
    sl.registerLazySingleton<SalesAnalysisRepository>(
      () => SalesAnalysisRepositoryImpl(
        local: sl(),
        remote: sl(),
        apiGuard: sl(),
      ),
    );
  }
  if (!sl.isRegistered<ListProductSalesAnalysis>()) {
    sl.registerLazySingleton(
      () => ListProductSalesAnalysis(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<GetProductSalesDetail>()) {
    sl.registerLazySingleton(
      () => GetProductSalesDetail(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<ListEmployeePriceAnalysis>()) {
    sl.registerLazySingleton(
      () => ListEmployeePriceAnalysis(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<ListCustomerSalesInsights>()) {
    sl.registerLazySingleton(
      () => ListCustomerSalesInsights(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<GetCustomerPriceHabits>()) {
    sl.registerLazySingleton(
      () => GetCustomerPriceHabits(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<GetProductSoldPriceRange>()) {
    sl.registerLazySingleton(
      () => GetProductSoldPriceRange(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<ListCategorySalesAnalysis>()) {
    sl.registerLazySingleton(
      () => ListCategorySalesAnalysis(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<GetMarginAnalysis>()) {
    sl.registerLazySingleton(
      () => GetMarginAnalysis(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<ListPriceDeviationAnalysis>()) {
    sl.registerLazySingleton(
      () => ListPriceDeviationAnalysis(sl<SalesAnalysisRepository>()),
    );
  }
  if (!sl.isRegistered<GetSalesTrendAnalysis>()) {
    sl.registerLazySingleton(
      () => GetSalesTrendAnalysis(sl<SalesAnalysisRepository>()),
    );
  }
}

/// Enregistre le module Dépenses si absent.
void ensureExpensesDependencies() {
  if (!sl.isRegistered<ExpensesLocalDatasource>()) {
    sl.registerLazySingleton(() => ExpensesLocalDatasource(sl()));
  }
  if (!sl.isRegistered<ExpensesRemoteDatasource>()) {
    sl.registerLazySingleton(() => ExpensesRemoteDatasource(sl()));
  }
  if (!sl.isRegistered<ExpenseRepository>()) {
    sl.registerLazySingleton<ExpenseRepository>(
      () => ExpenseRepositoryImpl(
        local: sl(),
        remote: sl(),
        apiGuard: sl(),
        recorder: sl(),
      ),
    );
  }
  if (!sl.isRegistered<ListExpenses>()) {
    sl.registerLazySingleton(() => ListExpenses(sl()));
  }
  if (!sl.isRegistered<CreateExpense>()) {
    sl.registerLazySingleton(() => CreateExpense(sl()));
  }
  if (!sl.isRegistered<UpdateExpense>()) {
    sl.registerLazySingleton(() => UpdateExpense(sl()));
  }
  if (!sl.isRegistered<DeleteExpense>()) {
    sl.registerLazySingleton(() => DeleteExpense(sl()));
  }
  if (!sl.isRegistered<GetExpenseSummary>()) {
    sl.registerLazySingleton(() => GetExpenseSummary(sl()));
  }
  if (!sl.isRegistered<ListExpenseCategories>()) {
    sl.registerLazySingleton(() => ListExpenseCategories(sl()));
  }
  if (!sl.isRegistered<CreateExpenseCategory>()) {
    sl.registerLazySingleton(() => CreateExpenseCategory(sl()));
  }
  if (!sl.isRegistered<GetExpensesByCategory>()) {
    sl.registerLazySingleton(() => GetExpensesByCategory(sl()));
  }
  if (!sl.isRegistered<SumValidatedExpenses>()) {
    sl.registerLazySingleton(() => SumValidatedExpenses(sl()));
  }
  if (!sl.isRegistered<GetExpenseDetail>()) {
    sl.registerLazySingleton(() => GetExpenseDetail(sl()));
  }
  if (!sl.isRegistered<UpsertCategoryBudget>()) {
    sl.registerLazySingleton(() => UpsertCategoryBudget(sl()));
  }
  if (!sl.isRegistered<GenerateRecurringExpenses>()) {
    sl.registerLazySingleton(() => GenerateRecurringExpenses(sl()));
  }
  if (!sl.isRegistered<SyncExpensesFromRemote>()) {
    sl.registerLazySingleton(() => SyncExpensesFromRemote(sl()));
  }
  if (!sl.isRegistered<ExpensePdfExporter>()) {
    sl.registerLazySingleton(() => const ExpensePdfExporter());
  }
}

/// Enregistre le module Notifications si absent (hot reload après ajout DI).
void ensureNotificationsDependencies() {
  if (sl.isRegistered<GetNotificationPreferences>()) return;

  if (!sl.isRegistered<NotificationsLocalDatasource>()) {
    sl.registerLazySingleton(() => NotificationsLocalDatasource(sl()));
  }
  if (!sl.isRegistered<NotificationsRemoteDatasource>()) {
    sl.registerLazySingleton(() => NotificationsRemoteDatasource(sl()));
  }
  if (!sl.isRegistered<NotificationFeedBuilder>()) {
    sl.registerLazySingleton(
      () => NotificationFeedBuilder(sl<NotificationsLocalDatasource>()),
    );
  }
  if (!sl.isRegistered<NotificationRepository>()) {
    sl.registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(
        local: sl(),
        remote: sl(),
        apiRunner: sl(),
        feedBuilder: sl(),
      ),
    );
  }
  sl.registerLazySingleton(
    () => GetNotificationPreferences(sl<NotificationRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateNotificationPreferences(sl<NotificationRepository>()),
  );
  sl.registerLazySingleton(
    () => GetPendingNotifications(sl<NotificationRepository>()),
  );
  sl.registerLazySingleton(
    () => AckDebtReminderNotifications(sl<NotificationRepository>()),
  );
}

/// Enregistre le module Paramètres si absent (hot reload après ajout DI).
void ensureSettingsDependencies() {
  if (sl.isRegistered<GetShopConfiguration>()) return;

  if (!sl.isRegistered<SettingsValidationService>()) {
    sl.registerLazySingleton(() => const SettingsValidationService());
  }
  if (!sl.isRegistered<SettingsLocalDatasource>()) {
    sl.registerLazySingleton(() => SettingsLocalDatasource(sl()));
  }
  if (!sl.isRegistered<SettingsRemoteDatasource>()) {
    sl.registerLazySingleton(() => SettingsRemoteDatasource(sl()));
  }
  if (!sl.isRegistered<SettingsRepository>()) {
    sl.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(
        local: sl(),
        remote: sl(),
        apiRunner: sl(),
        cloudSyncEnabler: sl(),
      ),
    );
  }
  if (!sl.isRegistered<GoogleDriveBackupService>()) {
    sl.registerLazySingleton(() => GoogleDriveBackupService());
  }
  if (!sl.isRegistered<ShopBackupService>()) {
    sl.registerLazySingleton(() => ShopBackupService(sl()));
  }
  sl.registerLazySingleton(
    () => GetShopConfiguration(sl<SettingsRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateShopConfiguration(
      sl<SettingsRepository>(),
      sl<SettingsValidationService>(),
    ),
  );
  sl.registerLazySingleton(
    () => RecordShopBackup(sl<SettingsRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateShopBackup(sl<ShopBackupService>(), sl<RecordShopBackup>()),
  );
  sl.registerLazySingleton(
    () => RestoreShopBackup(sl<ShopBackupService>()),
  );
  sl.registerLazySingleton(
    () => ExportShopJson(sl<ShopBackupService>()),
  );
  sl.registerLazySingleton(
    () => UpdateShopSyncSettings(sl<SettingsRepository>()),
  );
}

/// Enregistre le module Audit si absent (hot reload après ajout DI).
void ensureAuditDependencies() {
  if (sl.isRegistered<ListAuditLogs>()) return;

  if (!sl.isRegistered<AuditLabelService>()) {
    sl.registerLazySingleton(() => const AuditLabelService());
  }
  if (!sl.isRegistered<AuditMapper>()) {
    sl.registerLazySingleton(() => AuditMapper(sl()));
  }
  if (!sl.isRegistered<AuditLocalDatasource>()) {
    sl.registerLazySingleton(() => AuditLocalDatasource(sl(), sl()));
  }
  if (!sl.isRegistered<AuditRemoteDatasource>()) {
    sl.registerLazySingleton(() => AuditRemoteDatasource(sl(), sl()));
  }
  if (!sl.isRegistered<AuditRepository>()) {
    sl.registerLazySingleton<AuditRepository>(
      () => AuditRepositoryImpl(
        local: sl(),
        remote: sl(),
        apiRunner: sl(),
        mapper: sl(),
        labels: sl(),
      ),
    );
  }
  if (!sl.isRegistered<AuditPdfExporter>()) {
    sl.registerLazySingleton(() => const AuditPdfExporter());
  }
  sl.registerLazySingleton(() => ListAuditLogs(sl()));
  sl.registerLazySingleton(() => GetAuditLogDetail(sl()));
  sl.registerLazySingleton(() => GetAuditFilterOptions(sl()));
  sl.registerLazySingleton(() => ExportAuditLogs(sl()));
  sl.registerLazySingleton(() => GetEntityAuditHistory(sl()));
}

Future<void> initDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  sl.registerLazySingleton(() => OnboardingStorage(sl()));
  sl.registerLazySingleton(() => AuthFlowStorage(sl()));
  sl.registerLazySingleton(() => LastShopStorage(sl()));
  sl.registerLazySingleton(() => ApiSettingsStorage(sl()));

  sl.registerLazySingleton(AppDatabase.new);
  sl.registerLazySingleton(PinHasher.new);
  sl.registerLazySingleton(() => RecoveryTokenService(sl()));
  sl.registerLazySingleton(LockoutPolicy.new);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => SessionStorage(sl()));
  sl.registerLazySingleton(() => AuthCredentialsStorage(sl()));
  sl.registerLazySingleton(() => DeviceIdStorage(sl()));
  await sl<DeviceIdStorage>().getOrCreate();
  sl.registerLazySingleton(Connectivity.new);
  sl.registerLazySingleton(() => NetworkInfo(sl()));
  sl.registerLazySingleton(ActiveShopContext.new);
  final apiBaseUrl = sl<ApiSettingsStorage>().resolveEffectiveUrl();
  sl.registerLazySingleton(() => ApiClient(
        baseUrl: apiBaseUrl,
        credentials: sl<AuthCredentialsStorage>(),
        activeShop: sl<ActiveShopContext>(),
      ));
  sl.registerLazySingleton(
    () => RemoteApiGuard(
      networkInfo: sl(),
      credentials: sl(),
      apiClient: sl(),
    ),
  );
  sl.registerLazySingleton(OnlineSessionPolicy.new);
  sl.registerLazySingleton(
    () => AppLockController(sl<SharedPreferences>()),
  );
  sl.registerLazySingleton(
    () => CloudSessionCoordinator(
      credentials: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => RemoteApiRunner(
      apiGuard: sl(),
      sessionPolicy: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton(() => AuthRemoteDatasource(sl()));
  sl.registerLazySingleton(() => ShopRemoteDatasource(sl()));
  sl.registerLazySingleton(() => UserRemoteDatasource(sl()));
  sl.registerLazySingleton(() => RbacRemoteDatasource(sl()));
  sl.registerLazySingleton(LocalAuthentication.new);
  sl.registerLazySingleton(() => BiometricLocalDatasource(sl()));

  sl.registerLazySingleton(() => SettingsLocalDatasource(sl()));
  sl.registerLazySingleton(() => CloudSyncPreferences(sl()));
  sl.registerLazySingleton(
    () => CloudSyncEnabler(
      settingsLocal: sl(),
      preferences: sl(),
    ),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      database: sl(),
      pinHasher: sl(),
      lockoutPolicy: sl(),
      recoveryTokenService: sl(),
      sessionStorage: sl(),
      credentialsStorage: sl(),
      authFlowStorage: sl(),
      deviceIdStorage: sl(),
      activeShopContext: sl(),
      remote: sl(),
      networkInfo: sl(),
      apiClient: sl(),
      cloudSyncEnabler: sl(),
      onOnlineSessionReady: (shopId) {
        if (sl.isRegistered<SyncService>()) {
          sl<SyncService>().scheduleSync(shopId: shopId);
        }
      },
    ),
  );

  sl.registerLazySingleton(() => IsSetupComplete(sl()));
  sl.registerLazySingleton(() => WasLoggedOut(sl()));
  sl.registerLazySingleton(() => RestoreSession(sl()));
  sl.registerLazySingleton(() => GetLockScreen(sl()));
  sl.registerLazySingleton(() => LoginWithPin(sl()));
  sl.registerLazySingleton(() => LoginWithBiometric(sl(), sl()));
  sl.registerLazySingleton(() => SetupOwner(sl()));
  sl.registerLazySingleton(() => RequestWhatsappOtp(sl()));
  sl.registerLazySingleton(() => VerifyWhatsappOtp(sl()));
  sl.registerLazySingleton(() => CompleteWhatsappLogin(sl()));
  sl.registerLazySingleton(() => EmergencyUnlock(sl()));
  sl.registerLazySingleton(() => EnableBiometric(sl()));
  sl.registerLazySingleton(() => DisableBiometric(sl()));
  sl.registerLazySingleton(() => ChangeUserPin(sl()));
  sl.registerLazySingleton(() => TouchSession(sl()));
  sl.registerLazySingleton(() => LockActiveSession(sl()));
  sl.registerLazySingleton(() => Logout(sl()));
  sl.registerLazySingleton(() => ListOwnedShops(sl()));
  sl.registerLazySingleton(() => SwitchShop(sl()));
  sl.registerLazySingleton(() => ListDeviceSessions(sl()));
  sl.registerLazySingleton(() => RevokeDeviceSession(sl()));

  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(
      remote: sl(),
      database: sl(),
      apiRunner: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListShops(sl()));
  sl.registerLazySingleton(() => GetShop(sl()));
  sl.registerLazySingleton(() => CreateShop(sl()));
  sl.registerLazySingleton(() => UpdateShop(sl()));
  sl.registerLazySingleton(() => DeactivateShop(sl()));
  sl.registerLazySingleton(() => SetDefaultShop(sl()));

  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(
      remote: sl(),
      database: sl(),
      apiRunner: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListShopUsers(sl()));
  sl.registerLazySingleton(() => GetUserAssignment(sl()));
  sl.registerLazySingleton(() => CreateShopUser(sl()));
  sl.registerLazySingleton(() => ChangeUserRole(sl()));
  sl.registerLazySingleton(() => DeactivateShopUser(sl()));
  sl.registerLazySingleton(() => AssignUserShop(sl()));

  sl.registerLazySingleton<RbacRepository>(
    () => RbacRepositoryImpl(remote: sl(), apiRunner: sl()),
  );
  sl.registerLazySingleton(() => ListRoles(sl()));
  sl.registerLazySingleton(() => GetRoleDetail(sl()));
  sl.registerLazySingleton(() => GetPermissionsCatalog(sl()));
  sl.registerLazySingleton(() => GetMyPermissions(sl()));
  sl.registerLazySingleton(() => GetUserEffectivePermissions(sl()));
  sl.registerLazySingleton(() => ListUserPermissionOverrides(sl()));
  sl.registerLazySingleton(() => ReplaceUserPermissionOverrides(sl()));
  sl.registerLazySingleton(() => CreateShopRole(sl()));
  sl.registerLazySingleton(() => UpdateShopRole(sl()));
  sl.registerLazySingleton(() => DeleteShopRole(sl()));
  sl.registerLazySingleton(() => SetRolePermissions(sl()));
  sl.registerLazySingleton(
    () => RefreshSessionPermissions(
      getMyPermissions: sl(),
      credentials: sl(),
      authRepository: sl(),
    ),
  );

  sl.registerLazySingleton(() => DashboardAggregationService());
  sl.registerLazySingleton(() => DashboardLocalDatasource(sl()));
  ensureExpensesDependencies();
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(
      localDatasource: sl(),
      expensesLocal: sl<ExpensesLocalDatasource>(),
    ),
  );
  sl.registerLazySingleton(() => GetDashboard(sl()));

  ensureReportsDependencies();
  ensureNotificationsDependencies();
  ensureSettingsDependencies();
  ensureAuditDependencies();

  sl.registerLazySingleton(() => const ProductValidationService());
  sl.registerLazySingleton(() => const CategoryValidationService());
  sl.registerLazySingleton(() => InventoryLocalDatasource(sl()));
  sl.registerLazySingleton(() => InventoryRemoteDatasource(sl()));
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      local: sl(),
      remote: sl(),
      apiGuard: sl(),
      validation: sl(),
      categoryValidation: sl(),
      recorder: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListProducts(sl()));
  sl.registerLazySingleton(() => ListCategories(sl()));
  sl.registerLazySingleton(() => ListCategoriesWithStats(sl()));
  sl.registerLazySingleton(() => CreateCategory(sl()));
  sl.registerLazySingleton(() => UpdateCategory(sl()));
  sl.registerLazySingleton(() => DeleteCategory(sl()));
  sl.registerLazySingleton(() => GetProductDetail(sl()));
  sl.registerLazySingleton(() => CreateProduct(sl()));
  sl.registerLazySingleton(() => UpdateProduct(sl()));
  sl.registerLazySingleton(() => ArchiveProduct(sl()));
  sl.registerLazySingleton(() => AdjustProductStock(sl()));

  sl.registerLazySingleton(() => const SaleValidationService());
  sl.registerLazySingleton(() => const ReceiptFormatterService());
  sl.registerLazySingleton(() => SalesLocalDatasource(sl()));
  sl.registerLazySingleton(() => CustomerProductPriceLocalDatasource(sl()));
  sl.registerLazySingleton(() => SalesRemoteDatasource(sl()));
  sl.registerLazySingleton(() => const CustomerValidationService());
  sl.registerLazySingleton(() => CustomersLocalDatasource(sl()));
  sl.registerLazySingleton(() => CustomersRemoteDatasource(sl()));
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(
      local: sl(),
      remote: sl(),
      apiGuard: sl(),
      recorder: sl(),
      validation: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListCustomers(sl()));
  sl.registerLazySingleton(() => GetCustomer(sl()));
  sl.registerLazySingleton(() => ListCustomerSales(sl()));
  sl.registerLazySingleton(() => ListCustomerSalesLifetime(sl()));
  sl.registerLazySingleton(() => ListDebtors(sl()));
  sl.registerLazySingleton(() => GetDebtReminder(sl()));
  sl.registerLazySingleton(() => CreateCustomer(sl()));
  sl.registerLazySingleton(() => UpdateCustomer(sl()));
  sl.registerLazySingleton(() => ArchiveCustomer(sl()));

  sl.registerLazySingleton(() => const DebtValidationService());
  sl.registerLazySingleton(() => DebtsLocalDatasource(sl()));
  sl.registerLazySingleton(() => DebtsRemoteDatasource(sl()));
  sl.registerLazySingleton<DebtRepository>(
    () => DebtRepositoryImpl(
      local: sl(),
      remote: sl(),
      customersLocal: sl(),
      apiGuard: sl(),
      validation: sl(),
      recorder: sl(),
      notificationOrchestrator: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListCustomerDebts(sl()));
  sl.registerLazySingleton(() => ListForgivenDebts(sl()));
  sl.registerLazySingleton(() => GetDebt(sl()));
  sl.registerLazySingleton(() => GetDebtDetail(sl()));
  sl.registerLazySingleton(() => GetDebtDetailReminder(sl()));
  sl.registerLazySingleton(() => RecordDebtPayment(sl()));
  sl.registerLazySingleton(() => ForgiveDebt(sl()));

  sl.registerLazySingleton<SaleRepository>(
    () => SaleRepositoryImpl(
      local: sl(),
      remote: sl(),
      apiGuard: sl(),
      validation: sl(),
      recorder: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListSales(sl()));
  sl.registerLazySingleton(() => GetSale(sl()));
  sl.registerLazySingleton(() => ListSaleCustomers(sl()));
  sl.registerLazySingleton(() => CreateStandardSale(sl()));
  sl.registerLazySingleton(() => CreateQuickSale(sl()));
  sl.registerLazySingleton(() => ConvertQuickSaleToStandard(sl()));
  sl.registerLazySingleton(() => CancelSale(sl()));

  sl.registerLazySingleton(() => CustomerRemoteSyncAdapter(sl<CustomerRepository>()));
  sl.registerLazySingleton(() => InventoryRemoteSyncAdapter(sl<InventoryRepository>()));
  sl.registerLazySingleton(() => SalesRemoteSyncAdapter(sl<SaleRepository>()));
  sl.registerLazySingleton(() => DebtsRemoteSyncAdapter(sl<DebtRepository>()));
  sl.registerLazySingleton(
    () => ExpensesRemoteSyncAdapter(sl<ExpenseRepository>()),
  );
  sl.registerLazySingleton(() => SyncPolicy(sl(), sl()));
  sl.registerLazySingleton(() => SyncQueueDatasource(sl()));
  sl.registerLazySingleton(() => LocalAuditWriter(sl()));
  sl.registerLazySingleton(
    () => SyncConflictService(
      db: sl(),
      queue: sl(),
      auditWriter: sl(),
      customersLocal: sl(),
      customersRemote: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => LocalWriteSyncRecorder(
      policy: sl(),
      queue: sl(),
      onEnqueued: (shopId) => sl<SyncService>().scheduleSync(shopId: shopId),
    ),
  );
  sl.registerLazySingleton(
    () => SyncQueueProcessor(
      queue: sl(),
      apiGuard: sl(),
      customersLocal: sl(),
      customersRemote: sl(),
      inventoryLocal: sl(),
      inventoryRemote: sl(),
      salesLocal: sl(),
      salesRemote: sl(),
      debtsLocal: sl(),
      debtsRemote: sl(),
      expensesLocal: sl(),
      expensesRemote: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => SyncService(
      connectivity: sl(),
      networkInfo: sl(),
      apiGuard: sl(),
      policy: sl(),
      queue: sl(),
      processor: sl(),
      ports: [
        sl<CustomerRemoteSyncAdapter>(),
        sl<InventoryRemoteSyncAdapter>(),
        sl<SalesRemoteSyncAdapter>(),
        sl<DebtsRemoteSyncAdapter>(),
        sl<ExpensesRemoteSyncAdapter>(),
      ],
      settingsLocal: sl(),
    ),
  );

  sl.registerLazySingleton(LocalNotificationService.new);
  sl.registerLazySingleton(NotificationDeepLinkHandler.new);
  sl.registerLazySingleton(
    () => NotificationOrchestrator(
      getPending: sl(),
      ackDebtReminders: sl(),
      localNotifications: sl(),
      deepLinks: sl(),
      preferences: sl(),
    ),
  );

  sl.registerFactory(
    () => AuthBloc(
      isSetupComplete: sl(),
      wasLoggedOut: sl(),
      getLockScreen: sl(),
      loginWithPin: sl(),
      loginWithBiometric: sl(),
      setupOwner: sl(),
      emergencyUnlock: sl(),
      logout: sl(),
      listOwnedShops: sl(),
      switchShop: sl(),
      requestWhatsappOtp: sl(),
      verifyWhatsappOtp: sl(),
      completeWhatsappLogin: sl(),
      lastShopStorage: sl(),
      syncService: sl(),
      appLockController: sl(),
    ),
  );

  await sl<NotificationOrchestrator>().initialize();
  sl<SyncService>().start();
}
