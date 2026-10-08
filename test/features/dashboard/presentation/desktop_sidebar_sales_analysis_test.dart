import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/app/theme/app_theme.dart';
import 'package:venteapp/features/auth/domain/entities/auth_entities.dart';
import 'package:venteapp/features/dashboard/presentation/models/sidebar_destination.dart';
import 'package:venteapp/features/dashboard/presentation/widgets/desktop_sidebar.dart';
import 'package:venteapp/shared/enums/permission.dart';
import 'package:venteapp/shared/enums/user_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    await initDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  test('SidebarDestination.salesAnalysis metadata is properly configured', () {
    const dest = SidebarDestination.salesAnalysis;
    expect(dest.label(), 'Analyse des Ventes');
    expect(dest.sectionLabel, 'Modules & Commerce');
    expect(dest.icon(), Icons.analytics_outlined);
    expect(dest.activeIcon(), Icons.analytics_rounded);
    expect(dest.isSubpage, isTrue);
    expect(dest.helpArticleId, 'sales_analysis');
  });

  testWidgets(
      'DesktopSidebar displays Analyse des Ventes when user has reports permission',
      (tester) async {
    final session = AuthSession(
      token: 'test-token',
      expiresAt: DateTime.now().millisecondsSinceEpoch + 600000,
      autoLockMinutes: 5,
      shop: const AuthShop(id: 1, name: 'Boutique Test'),
      user: const AuthUser(
        id: 1,
        name: 'Gérant',
        role: UserRole.owner,
        roleLabel: 'Gérant',
        shopId: 1,
        biometricEnabled: false,
        lastLoginAt: null,
        permissions: {Permission.reportsRead},
      ),
    );

    SidebarDestination? selectedDestination;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DesktopSidebar(
            session: session,
            activeDestination: SidebarDestination.dashboard,
            onDestinationSelected: (dest) => selectedDestination = dest,
            onNewSale: () {},
            useFxPrimary: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final itemFinder = find.text('Analyse des Ventes');
    expect(itemFinder, findsOneWidget);

    await tester.tap(itemFinder);
    await tester.pumpAndSettle();

    expect(selectedDestination, SidebarDestination.salesAnalysis);
  });
}
