import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/app/theme/app_theme.dart';
import 'package:venteapp/core/theme/ui_scale_controller.dart';
import 'package:venteapp/features/auth/domain/entities/auth_entities.dart';
import 'package:venteapp/features/settings/presentation/pages/categories/appearance_settings_page.dart';
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

  testWidgets('AppearanceSettingsPage displays text scaling section and allows changing font size', (tester) async {
    const session = AuthSession(
      token: 'test-token',
      expiresAt: 9999999999,
      autoLockMinutes: 5,
      shop: AuthShop(id: 1, name: 'Boutique Test'),
      user: AuthUser(
        id: 1,
        name: 'Gérant',
        role: UserRole.owner,
        roleLabel: 'Gérant',
        shopId: 1,
        biometricEnabled: false,
        lastLoginAt: null,
        permissions: {},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AppearanceSettingsPage(session: session),
      ),
    );

    await tester.pumpAndSettle();

    // Verify section header is visible
    expect(find.text('Taille des écritures & Lisibilité'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
    expect(find.text('Grand (115%) — Recommandé'), findsOneWidget);

    // Tap on Grand (115%)
    await tester.tap(find.text('Grand (115%) — Recommandé'));
    await tester.pumpAndSettle();

    final scaleController = sl<UiScaleController>();
    expect(scaleController.scaleFactor, 1.15);
    expect(scaleController.percentage, 115);
    expect(find.text('115%'), findsWidgets);
  });
}

