import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/app/theme/app_theme.dart';
import 'package:venteapp/features/auth/domain/entities/auth_entities.dart';
import 'package:venteapp/features/customers/domain/entities/customer_entities.dart';
import 'package:venteapp/features/customers/presentation/bloc/customer_list_bloc.dart';
import 'package:venteapp/features/customers/presentation/pages/customer_list_page.dart';
import 'package:venteapp/features/customers/presentation/widgets/desktop_customer_list_view.dart';
import 'package:venteapp/features/inventory/domain/entities/inventory_entities.dart';
import 'package:venteapp/features/inventory/presentation/bloc/product_list_bloc.dart';
import 'package:venteapp/features/inventory/presentation/pages/product_list_page.dart';
import 'package:venteapp/features/inventory/presentation/widgets/desktop_product_list_view.dart';
import 'package:venteapp/features/sales/domain/entities/sale_entities.dart';
import 'package:venteapp/features/sales/presentation/bloc/sale_list_bloc.dart';
import 'package:venteapp/features/sales/presentation/pages/sale_list_page.dart';
import 'package:venteapp/features/sales/presentation/widgets/desktop_sale_list_view.dart';
import 'package:venteapp/shared/components/app_desktop_data_table.dart';
import 'package:venteapp/shared/enums/permission.dart';
import 'package:venteapp/shared/enums/user_role.dart';

class _FakeSaleListBloc extends Cubit<SaleListState> implements SaleListBloc {
  _FakeSaleListBloc(super.initialState);
  @override
  void add(SaleListEvent event) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProductListBloc extends Cubit<ProductListState>
    implements ProductListBloc {
  _FakeProductListBloc(super.initialState);
  @override
  void add(ProductListEvent event) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCustomerListBloc extends Cubit<CustomerListState>
    implements CustomerListBloc {
  _FakeCustomerListBloc(super.initialState);
  @override
  void add(CustomerListEvent event) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<SharedPreferences>()) {
      sl.registerSingleton<SharedPreferences>(prefs);
    }
  });
  final session = AuthSession(
    token: 'test-token',
    expiresAt: 1770000000000 + 600000,
    autoLockMinutes: 5,
    shop: const AuthShop(id: 1, name: 'Boutique Centrale'),
    user: const AuthUser(
      id: 10,
      name: 'Amadou',
      role: UserRole.owner,
      roleLabel: 'Propriétaire',
      shopId: 1,
      biometricEnabled: false,
      lastLoginAt: null,
      permissions: {
        Permission.salesCreate,
        Permission.inventoryWrite,
        Permission.customersWrite,
      },
    ),
  );

  group('SaleListPage Adaptive Design', () {
    final testSales = [
      const SaleListRow(
        id: 101,
        receiptNumber: 'REC-001',
        saleType: SaleType.standard,
        totalAmount: 15000,
        status: SaleStatus.completed,
        createdAt: 1770000000000,
        customerName: 'Kofi Mensah',
      ),
      const SaleListRow(
        id: 102,
        receiptNumber: 'REC-002',
        saleType: SaleType.quick,
        totalAmount: 25000,
        status: SaleStatus.completed,
        createdAt: 1770003600000,
        customerName: 'Amina Diallo',
      ),
    ];

    testWidgets('Renders Mobile layout on 400x800 and Desktop on 1280x800',
        (tester) async {
      final fakeBloc = _FakeSaleListBloc(
        SaleListState(
          status: SaleListStatus.loaded,
          sales: testSales,
          isRefreshing: false,
        ),
      );

      // --- Mobile 400x800 ---
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BlocProvider<SaleListBloc>.value(
              value: fakeBloc,
              child: SaleListPage(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile : pas de DesktopSaleListView
      expect(find.byType(DesktopSaleListView), findsNothing);
      expect(find.text('Rechercher par n° de reçu…'), findsOneWidget);
      expect(find.text('REC-001'), findsOneWidget);

      // --- Desktop 1280x800 ---
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BlocProvider<SaleListBloc>.value(
              value: fakeBloc,
              child: SaleListPage(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop : bascule vers DesktopSaleListView + AppDesktopDataTable
      expect(find.byType(DesktopSaleListView), findsOneWidget);
      expect(find.byType(AppDesktopDataTable), findsOneWidget);
      expect(find.text('Historique des Ventes'), findsOneWidget);
      expect(find.text('Nouvelle Vente (F2)'), findsOneWidget);
      expect(find.text('Kofi Mensah'), findsOneWidget);
      expect(find.text('Amina Diallo'), findsOneWidget);
    });
  });

  group('ProductListPage Adaptive Design', () {
    final testProducts = [
      const Product(
        id: 1,
        shopId: 1,
        categoryId: 1,
        categoryName: 'Ciment & Liants',
        name: 'Ciment Dangote 50kg',
        sku: 'CIM-50',
        quantityInStock: 80,
        alertThreshold: 20,
        priceSell: 4500,
        isArchived: false,
        isLowStock: false,
      ),
      const Product(
        id: 2,
        shopId: 1,
        categoryId: 2,
        categoryName: 'Fers & Aciers',
        name: 'Fer à béton 12mm',
        sku: 'FER-12',
        quantityInStock: 5,
        alertThreshold: 15,
        priceSell: 7500,
        isArchived: false,
        isLowStock: true,
      ),
    ];

    testWidgets('Renders Mobile layout on 400x800 and Desktop on 1280x800',
        (tester) async {
      final fakeBloc = _FakeProductListBloc(
        ProductListState(
          status: ProductListStatus.loaded,
          products: testProducts,
          categories: const [
            ProductCategory(
              id: 1,
              shopId: 1,
              name: 'Ciment & Liants',
              isActive: true,
              sortOrder: 1,
            ),
          ],
        ),
      );

      // --- Mobile 400x800 ---
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BlocProvider<ProductListBloc>.value(
              value: fakeBloc,
              child: ProductListPage(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile : pas de DesktopProductListView
      expect(find.byType(DesktopProductListView), findsNothing);
      expect(find.text('Rechercher un produit…'), findsOneWidget);

      // --- Desktop 1280x800 ---
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BlocProvider<ProductListBloc>.value(
              value: fakeBloc,
              child: ProductListPage(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop : bascule vers DesktopProductListView + AppDesktopDataTable
      expect(find.byType(DesktopProductListView), findsOneWidget);
      expect(find.byType(AppDesktopDataTable), findsOneWidget);
      expect(find.text('Gestion des Stocks & Produits'), findsOneWidget);
      expect(find.text('Nouveau Produit'), findsOneWidget);
      expect(find.text('Ciment Dangote 50kg'), findsOneWidget);
      expect(find.text('Fer à béton 12mm'), findsOneWidget);
    });
  });

  group('CustomerListPage Adaptive Design', () {
    final testCustomers = [
      const Customer(
        id: 1,
        shopId: 1,
        name: 'Moussa Traoré',
        phone: '+229 97 00 11 22',
        address: 'Cotonou, Akpakpa',
        balanceDue: 0,
        purchaseCount: 12,
        totalPurchases: 350000,
      ),
      const Customer(
        id: 2,
        shopId: 1,
        name: 'Fatou Sow',
        phone: '+229 95 33 44 55',
        address: 'Porto-Novo',
        balanceDue: 45000,
        purchaseCount: 5,
        totalPurchases: 180000,
      ),
    ];

    testWidgets('Renders Mobile layout on 400x800 and Desktop on 1280x800',
        (tester) async {
      final fakeBloc = _FakeCustomerListBloc(
        CustomerListState(
          status: CustomerListStatus.ready,
          customers: testCustomers,
        ),
      );

      // --- Mobile 400x800 ---
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BlocProvider<CustomerListBloc>.value(
              value: fakeBloc,
              child: CustomerListPage(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile : pas de DesktopCustomerListView
      expect(find.byType(DesktopCustomerListView), findsNothing);
      expect(find.text('Rechercher un client…'), findsOneWidget);

      // --- Desktop 1280x800 ---
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BlocProvider<CustomerListBloc>.value(
              value: fakeBloc,
              child: CustomerListPage(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop : bascule vers DesktopCustomerListView + AppDesktopDataTable
      expect(find.byType(DesktopCustomerListView), findsOneWidget);
      expect(find.byType(AppDesktopDataTable), findsOneWidget);
      expect(find.text('Répertoire & Crédits Clients'), findsOneWidget);
      expect(find.text('Nouveau Client'), findsOneWidget);
      expect(find.text('Moussa Traoré'), findsOneWidget);
      expect(find.text('Fatou Sow'), findsOneWidget);
    });
  });
}
