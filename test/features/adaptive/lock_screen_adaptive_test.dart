import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/auth/domain/entities/auth_entities.dart';
import 'package:venteapp/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:venteapp/features/auth/presentation/pages/lock_screen_page.dart';
import 'package:venteapp/shared/enums/user_role.dart';

class _FakeAuthBloc extends Cubit<AuthState> implements AuthBloc {
  _FakeAuthBloc(super.initialState);

  final List<AuthEvent> events = [];

  @override
  void add(AuthEvent event) {
    events.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testLockScreen = LockScreenData(
    shopId: 1,
    shopName: 'Boutique ARIKE Test',
    shopLogoPath: null,
    users: [
      LockScreenUser(
        id: 10,
        name: 'Amina Caissière',
        role: UserRole.seller,
        biometricEnabled: false,
      ),
    ],
  );

  Widget createWidgetUnderTest(AuthBloc bloc) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: bloc,
        child: const LockScreenPage(),
      ),
    );
  }

  group('LockScreenPage Adaptive Design Tests', () {
    testWidgets('Renders Mobile layout on 400x800', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final bloc = _FakeAuthBloc(const AuthLocked(testLockScreen));

      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pumpAndSettle();

      // Mobile should show shop name and standard PIN title
      expect(find.text('Boutique ARIKE Test'), findsOneWidget);
      expect(find.text('Entrez votre code PIN'), findsOneWidget);
      expect(find.text('Amina Caissière · Vendeur'), findsOneWidget);

      // Desktop-specific badge should NOT exist
      expect(find.text('POSTE DE CAISSE SÉCURISÉ'), findsNothing);
    });

    testWidgets('Renders Desktop layout on 1280x800 with dual cards', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final bloc = _FakeAuthBloc(const AuthLocked(testLockScreen));

      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pumpAndSettle();

      // Desktop layout contains the secured POS badge
      expect(find.text('POSTE DE CAISSE SÉCURISÉ'), findsOneWidget);
      expect(find.text('Session locale active & protégée'), findsOneWidget);
      expect(find.text('Amina Caissière'), findsOneWidget);
      expect(find.text('Clavier & pavé numérique actifs (0-9, Entrée)'), findsOneWidget);
    });

    testWidgets('Desktop supports physical keyboard PIN entry and submission', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final bloc = _FakeAuthBloc(const AuthLocked(testLockScreen));

      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pumpAndSettle();

      // Press keys '1', '2', '3', '4' on the keyboard
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.pumpAndSettle();

      // The 'Valider (Entrée)' button appears for 4-digit PIN
      expect(find.text('Valider (Entrée)'), findsOneWidget);

      // Press Enter to submit
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Verify that AuthLoginRequested was dispatched with pin '1234'
      expect(bloc.events.length, 1);
      final event = bloc.events.first;
      expect(event, isA<AuthLoginRequested>());
      final loginEvent = event as AuthLoginRequested;
      expect(loginEvent.pin, '1234');
      expect(loginEvent.shopId, 1);
      expect(loginEvent.userId, 10);
    });
  });
}
