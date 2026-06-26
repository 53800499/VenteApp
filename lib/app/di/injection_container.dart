import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_config.dart';
import '../../core/database/app_database.dart';
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
import '../../features/dashboard/data/datasources/local/dashboard_local_datasource.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/services/dashboard_aggregation_service.dart';
import '../../features/dashboard/domain/usecases/get_dashboard.dart';
import '../../features/inventory/data/datasources/local/inventory_local_datasource.dart';
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
import '../../features/sales/data/datasources/local/sales_local_datasource.dart';
import '../../features/sales/data/repositories/sale_repository_impl.dart';
import '../../features/sales/domain/repositories/sale_repository.dart';
import '../../features/sales/domain/services/sale_validation_service.dart';
import '../../features/sales/domain/usecases/sale_usecases.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';

final sl = GetIt.instance;

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
  sl.registerLazySingleton(() => AuthRemoteDatasource(sl()));
  sl.registerLazySingleton(() => ShopRemoteDatasource(sl()));
  sl.registerLazySingleton(() => UserRemoteDatasource(sl()));
  sl.registerLazySingleton(LocalAuthentication.new);
  sl.registerLazySingleton(() => BiometricLocalDatasource(sl()));

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
  sl.registerLazySingleton(() => TouchSession(sl()));
  sl.registerLazySingleton(() => LockActiveSession(sl()));
  sl.registerLazySingleton(() => Logout(sl()));
  sl.registerLazySingleton(() => ListOwnedShops(sl()));
  sl.registerLazySingleton(() => SwitchShop(sl()));

  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(
      remote: sl(),
      database: sl(),
      apiGuard: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListShops(sl()));
  sl.registerLazySingleton(() => GetShop(sl()));
  sl.registerLazySingleton(() => CreateShop(sl()));
  sl.registerLazySingleton(() => UpdateShop(sl()));
  sl.registerLazySingleton(() => DeactivateShop(sl()));
  sl.registerLazySingleton(() => SetDefaultShop(sl()));

  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(remote: sl(), apiGuard: sl()),
  );
  sl.registerLazySingleton(() => ListShopUsers(sl()));
  sl.registerLazySingleton(() => GetUserAssignment(sl()));
  sl.registerLazySingleton(() => CreateShopUser(sl()));
  sl.registerLazySingleton(() => ChangeUserRole(sl()));
  sl.registerLazySingleton(() => DeactivateShopUser(sl()));
  sl.registerLazySingleton(() => AssignUserShop(sl()));

  sl.registerLazySingleton(() => DashboardAggregationService());
  sl.registerLazySingleton(() => DashboardLocalDatasource(sl()));
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(localDatasource: sl()),
  );
  sl.registerLazySingleton(() => GetDashboard(sl()));

  sl.registerLazySingleton(() => const ProductValidationService());
  sl.registerLazySingleton(() => const CategoryValidationService());
  sl.registerLazySingleton(() => InventoryLocalDatasource(sl()));
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      local: sl(),
      validation: sl(),
      categoryValidation: sl(),
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
  sl.registerLazySingleton(() => SalesLocalDatasource(sl()));
  sl.registerLazySingleton<SaleRepository>(
    () => SaleRepositoryImpl(local: sl(), validation: sl()),
  );
  sl.registerLazySingleton(() => ListSales(sl()));
  sl.registerLazySingleton(() => GetSale(sl()));
  sl.registerLazySingleton(() => ListSaleCustomers(sl()));
  sl.registerLazySingleton(() => CreateStandardSale(sl()));
  sl.registerLazySingleton(() => CreateQuickSale(sl()));
  sl.registerLazySingleton(() => CancelSale(sl()));

  sl.registerFactory(
    () => AuthBloc(
      isSetupComplete: sl(),
      wasLoggedOut: sl(),
      restoreSession: sl(),
      getLockScreen: sl(),
      loginWithPin: sl(),
      loginWithBiometric: sl(),
      setupOwner: sl(),
      emergencyUnlock: sl(),
      lockActiveSession: sl(),
      logout: sl(),
      listOwnedShops: sl(),
      switchShop: sl(),
      requestWhatsappOtp: sl(),
      verifyWhatsappOtp: sl(),
      completeWhatsappLogin: sl(),
      lastShopStorage: sl(),
    ),
  );
}
