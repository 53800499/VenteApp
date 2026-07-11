import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:venteapp/app/app.dart';
import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/features/onboarding/presentation/pages/splash_page.dart';

import 'package:venteapp/core/auth/cloud_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ARIKE démarre avec le splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await initDependencies();
    await initDeferredServices();
    await tester.pumpWidget(const ArikeApp());
    await tester.pump();

    expect(find.byType(ArikeApp), findsOneWidget);
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // Dispose the widget tree to cancel repeating background animations
    await tester.pumpWidget(const SizedBox());

    // Dispose the cloud session controller ticker to avoid pending timers
    if (sl.isRegistered<CloudSessionController>()) {
      sl<CloudSessionController>().dispose();
    }
  });
}
