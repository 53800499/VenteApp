import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/app/theme/app_theme.dart';
import 'package:venteapp/features/auth/domain/entities/auth_entities.dart';
import 'package:venteapp/features/dashboard/domain/entities/dashboard_entities.dart';
import 'package:venteapp/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:venteapp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:venteapp/features/dashboard/presentation/widgets/desktop_dashboard_view.dart';
import 'package:venteapp/shared/enums/user_role.dart';

class _FakeDashboardBloc extends Cubit<DashboardState>
    implements DashboardBloc {
  _FakeDashboardBloc(super.initialState);

  @override
  void add(DashboardEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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
      permissions: {},
    ),
  );

  const testData = DashboardData(
    shopId: 1,
    date: 'Mardi 6 Octobre 2026',
    kpis: DashboardKpis(
      totalRevenue: 250000,
      saleCount: 14,
      lowStockCount: 3,
      debtorCount: 2,
    ),
    recentSales: [
      DashboardRecentSale(
        id: 101,
        totalAmount: 15000,
        createdAt: 1770000000000,
        customerName: 'Kofi Mensah',
        paymentMode: 'cash',
      ),
      DashboardRecentSale(
        id: 102,
        totalAmount: 45000,
        createdAt: 1770003600000,
        customerName: 'Amina Diallo',
        paymentMode: 'momo',
      ),
    ],
    generatedAt: 1770000000000,
    financial: DashboardFinancialKpis(
      totalCash: 150000,
      totalMomo: 80000,
      totalCredit: 20000,
      estimatedProfit: 65000,
      profitAvailable: true,
      totalDebt: 95000,
      totalExpenses: 12000,
      netProfit: 53000,
    ),
  );

  testWidgets(
      'DesktopDashboardView renders rich ERP desktop dashboard on wide screen',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool newSaleTapped = false;
    bool debtorsTapped = false;
    bool lowStockTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DesktopDashboardView(
            session: session,
            data: testData,
            isRefreshing: false,
            onRefresh: () async {},
            onNewSaleTap: () => newSaleTapped = true,
            onDebtorsTap: () => debtorsTapped = true,
            onLowStockTap: () => lowStockTapped = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérification de l'en-tête et salutations
    expect(find.text('Bonjour, Amadou 👋'), findsOneWidget);
    expect(find.text('Boutique Centrale'), findsOneWidget);

    // Vérification de la barre de commande
    expect(find.text('Nouvelle Vente (F2)'), findsOneWidget);
    expect(find.text('Dettes (2)'), findsOneWidget);
    expect(find.text('Stock faible (3)'), findsOneWidget);

    // Vérification des 4 tuiles KPI Bento
    expect(find.text('Chiffre d\'affaires'), findsOneWidget);
    expect(find.text('Total Encaissé'), findsOneWidget);
    expect(find.text('Créances clients'), findsOneWidget);
    expect(find.text('Alertes stock'), findsOneWidget);

    // Vérification de la synthèse financière
    expect(find.text('Indicateurs du jour :'), findsOneWidget);
    expect(find.text('Ventes à crédit : '), findsOneWidget);

    // Vérification du tableau des transactions récentes
    expect(find.text('Dernières ventes du jour'), findsOneWidget);
    expect(find.text('Kofi Mensah'), findsOneWidget);
    expect(find.text('Amina Diallo'), findsOneWidget);
    expect(find.text('#101'), findsOneWidget);
    expect(find.text('#102'), findsOneWidget);

    // Vérification du panneau de répartition des paiements
    expect(find.text('Répartition des encaissements'), findsOneWidget);
    expect(find.text('Espèces'), findsWidgets);
    expect(find.text('Mobile Money'), findsWidgets);

    // Vérification des actions rapides
    await tester.tap(find.text('Nouvelle Vente (F2)'));
    expect(newSaleTapped, isTrue);

    await tester.tap(find.text('Dettes (2)'));
    expect(debtorsTapped, isTrue);

    await tester.tap(find.text('Stock faible (3)'));
    expect(lowStockTapped, isTrue);
  });

  testWidgets(
      'DashboardPage switches adaptively: Mobile (400x800) preserves existing layout, Desktop (1280x800) uses DesktopDashboardView',
      (tester) async {
    final fakeBloc = _FakeDashboardBloc(
      const DashboardLoaded(testData, isRefreshing: false),
    );

    // --- 1. TEST RENDU MOBILE (400 x 800) ---
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BlocProvider<DashboardBloc>.value(
            value: fakeBloc,
            child: DashboardPage(
              key: const ValueKey('mobile'),
              session: session,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Sur mobile : Le layout classique est strictement préservé
    expect(find.text('Bonjour, Amadou 👋'), findsOneWidget);
    expect(find.text('Boutique Centrale'), findsOneWidget);
    expect(find.text('CA du jour'), findsOneWidget); // RevenueHeroCard
    expect(find.text('Raccourcis rapides'), findsOneWidget); // _QuickActionsHub
    // Le bouton desktop spécifique n'est PAS affiché sur mobile
    expect(find.text('Nouvelle Vente (F2)'), findsNothing);

    // --- 2. TEST RENDU DESKTOP (1280 x 800) ---
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BlocProvider<DashboardBloc>.value(
            value: fakeBloc,
            child: DashboardPage(
              key: const ValueKey('desktop'),
              session: session,
              onNewSaleTap: () {},
              onDebtorsTap: () {},
              onLowStockTap: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Sur desktop : La vue DesktopDashboardView prend le relais
    expect(find.text('Nouvelle Vente (F2)'), findsOneWidget);
    expect(find.text('Chiffre d\'affaires'), findsOneWidget);
    expect(find.text('Dernières ventes du jour'), findsOneWidget);
    expect(find.text('Répartition des encaissements'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
