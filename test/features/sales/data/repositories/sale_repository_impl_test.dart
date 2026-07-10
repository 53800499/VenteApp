import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/database/app_database.dart';
import 'package:venteapp/core/network/api_client.dart';
import 'package:venteapp/core/network/network_info.dart';
import 'package:venteapp/core/network/remote_api_guard.dart';
import 'package:venteapp/core/storage/auth_credentials_storage.dart';
import 'package:venteapp/core/utils/time.dart';
import 'package:venteapp/features/sales/data/datasources/local/sales_local_datasource.dart';
import 'package:venteapp/features/sales/data/datasources/remote/sales_remote_datasource.dart';
import 'package:venteapp/features/sales/data/repositories/sale_repository_impl.dart';
import 'package:venteapp/features/sales/domain/entities/sale_entities.dart';
import 'package:venteapp/features/cash_sessions/data/datasources/local/cash_sessions_local_datasource.dart';

import '../../../../support/auth_test_helpers.dart';

void main() {
  late AppDatabase database;
  late SaleRepositoryImpl repository;
  late int shopId;
  late int userId;
  late int productId;

  setUp(() async {
    database = createTestDatabase();
    final apiClient = ApiClient(baseUrl: 'http://test');
    repository = SaleRepositoryImpl(
      local: SalesLocalDatasource(database),
      remote: SalesRemoteDatasource(apiClient),
      apiGuard: RemoteApiGuard(
        networkInfo: const NetworkInfo.alwaysOffline(),
        credentials: AuthCredentialsStorage.inMemory(),
        apiClient: apiClient,
      ),
      syncPolicy: await createTestSyncPolicy(database),
      cashSessionsLocal: CashSessionsLocalDatasource(database),
    );

    final timestamp = nowMs();
    shopId = await database.into(database.shops).insert(
          ShopsCompanion.insert(
            name: const Value('Boutique Test'),
            createdAt: timestamp,
          ),
        );
    userId = await database.into(database.users).insert(
          UsersCompanion.insert(
            shopId: shopId,
            name: 'Caissier',
            pinHash: 'hash',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            shopId: shopId,
            name: 'Riz 1kg',
            priceSell: 2500,
            priceBuy: const Value(2000),
            quantityInStock: const Value(10),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    await database.into(database.cashSessions).insert(
          CashSessionsCompanion.insert(
            shopId: shopId,
            openedBy: userId,
            openedAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('convertit une vente rapide en vente standard avec lignes et stock', () async {
    final quick = await repository.createQuickSale(
      shopId: shopId,
      userId: userId,
      input: const CreateQuickSaleInput(
        totalAmount: 5000,
        payment: PaymentDraft(
          method: PaymentMethod.cash,
          amountCash: 5000,
        ),
      ),
    );

    expect(quick.saleType, SaleType.quick);
    expect(quick.items, isEmpty);

    final converted = await repository.convertQuickSaleToStandard(
      shopId: shopId,
      userId: userId,
      saleId: quick.id,
      input: ConvertQuickSaleInput(
        items: [
          SaleLineDraft(productId: productId, quantity: 2, unitPrice: 2500),
        ],
      ),
    );

    expect(converted.id, quick.id);
    expect(converted.saleType, SaleType.standard);
    expect(converted.items, hasLength(1));
    expect(converted.items.first.productName, 'Riz 1kg');
    expect(converted.totalAmount, 5000);

    final product = await (database.select(database.products)
          ..where((p) => p.id.equals(productId)))
        .getSingle();
    expect(product.quantityInStock, 8);
  });
}
