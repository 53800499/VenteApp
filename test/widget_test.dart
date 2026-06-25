import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/app/di/injection_container.dart';
import 'package:frontend/features/onboarding/presentation/pages/splash_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VenteApp démarre avec le splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await initDependencies();
    await tester.pumpWidget(const VenteApp());
    await tester.pump();

    expect(find.byType(VenteApp), findsOneWidget);
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump();
  });
}
