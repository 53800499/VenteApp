import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:venteapp/app/app.dart';
import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/features/onboarding/presentation/pages/splash_page.dart';

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
