import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/database/app_database.dart' hide AuthSession;
import 'package:venteapp/core/utils/commerce_shop_scope.dart';
import 'package:venteapp/core/utils/time.dart';
import 'package:venteapp/features/auth/domain/entities/auth_entities.dart';
import 'package:venteapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:venteapp/features/customers/domain/usecases/customer_usecases.dart';
import 'package:venteapp/features/inventory/data/datasources/local/inventory_local_datasource.dart';
import 'package:venteapp/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:venteapp/features/inventory/domain/entities/inventory_entities.dart';
import 'package:venteapp/features/inventory/domain/usecases/inventory_usecases.dart';
import 'package:venteapp/features/sales/domain/entities/sale_entities.dart';
import 'package:venteapp/features/sales/domain/repositories/sale_repository.dart';
import 'package:venteapp/features/sales/domain/usecases/sale_usecases.dart';
import 'package:venteapp/features/sales/presentation/bloc/new_sale_bloc.dart';
import 'package:venteapp/shared/enums/user_role.dart';
import 'package:venteapp/features/settings/data/datasources/local/settings_local_datasource.dart';
import 'package:venteapp/features/sales/data/datasources/local/customer_product_price_local_datasource.dart';

import '../../../../support/auth_test_helpers.dart';

class _UnusedCustomerRepository implements CustomerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeSaleRepository implements SaleRepository {
  @override
  Future<List<SaleCustomerOption>> listCustomers({
    required int shopId,
    String search = '',
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase database;
  late InventoryRepositoryImpl inventoryRepo;
  late NewSaleBloc bloc;

  setUp(() async {
    database = createTestDatabase();
    inventoryRepo = InventoryRepositoryImpl(
      local: InventoryLocalDatasource(database),
      syncPolicy: await createTestSyncPolicy(database),
    );
    final saleRepo = _FakeSaleRepository();

    final timestamp = nowMs();
    final productShopId = await database.into(database.shops).insert(
          ShopsCompanion.insert(
            name: const Value('Boutique Produits'),
            createdAt: timestamp,
          ),
        );
    final sessionShopId = await database.into(database.shops).insert(
          ShopsCompanion.insert(
            name: const Value('Boutique Session'),
            createdAt: timestamp,
          ),
        );

    final userId = await database.into(database.users).insert(
          UsersCompanion.insert(
            shopId: productShopId,
            name: 'Patron',
            pinHash: 'hash',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );

    final categoryId = await inventoryRepo.ensureDefaultCategory(productShopId);
    await inventoryRepo.createProduct(
      shopId: productShopId,
      userId: userId,
      input: CreateProductInput(
        name: 'Savon',
        categoryId: categoryId,
        priceSell: 500,
        initialQuantity: 8,
      ),
      defaultAlertThreshold: 5,
    );

    final session = AuthSession(
      token: 'test-token',
      expiresAt: timestamp + 600000,
      autoLockMinutes: 5,
      shop: AuthShop(id: sessionShopId, name: 'Boutique Session'),
      user: AuthUser(
        id: userId,
        name: 'Patron',
        role: UserRole.owner,
        roleLabel: 'Patron',
        shopId: productShopId,
        biometricEnabled: false,
        lastLoginAt: null,
        permissions: const {},
      ),
    );

    expect(CommerceShopScope.candidateLocalShopIds(session), [sessionShopId, productShopId]);

    bloc = NewSaleBloc(
      listProducts: ListProducts(inventoryRepo),
      listCustomers: ListSaleCustomers(saleRepo),
      createStandardSale: CreateStandardSale(saleRepo),
      createCustomer: CreateCustomer(_UnusedCustomerRepository()),
      session: session,
      settingsLocal: SettingsLocalDatasource(database),
      customerPrices: CustomerProductPriceLocalDatasource(database),
    );
  });

  tearDown(() async {
    await bloc.close();
    await database.close();
  });

  test('retrouve les produits via le shopId utilisateur si la session pointe ailleurs', () async {
    bloc.add(const NewSaleLoadRequested());

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<NewSaleState>().having(
          (s) => s.status,
          'status',
          NewSaleStatus.loading,
        ),
        isA<NewSaleState>()
            .having((s) => s.status, 'status', NewSaleStatus.ready)
            .having((s) => s.products.length, 'products', 1)
            .having((s) => s.products.first.name, 'name', 'Savon'),
      ]),
    );
  });
}
