import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/core/auth/cloud_session_repair_service.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUserBio = LockScreenUser(
    id: 1,
    name: 'Patron Eskay',
    role: UserRole.owner,
    biometricEnabled: true,
  );

  const testLockScreenWithBio = LockScreenData(
    shopId: 1,
    shopName: 'Boutique ARIKE Test',
    shopLogoPath: null,
    users: [testUserBio],
  );

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await initDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget createWidgetUnderTest(AuthBloc bloc) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: bloc,
        child: const LockScreenPage(),
      ),
    );
  }

  group('LockScreenPage Biometric Gating Tests', () {
    testWidgets('Mode nominal : le bouton biométrie est visible et cliquable', (tester) async {
      final bloc = _FakeAuthBloc(const AuthLocked(testLockScreenWithBio));

      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pumpAndSettle();

      // En mode normal, l'option empreinte/biométrie est présente
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      // Le bandeau d'alerte cloud n'est pas affiché
      expect(find.text('Reconnexion cloud requise : saisissez votre code PIN'), findsNothing);

      // Clic sur le bouton biométrie émet AuthBiometricLoginRequested
      await tester.tap(find.byIcon(Icons.fingerprint));
      await tester.pump();

      expect(bloc.events.whereType<AuthBiometricLoginRequested>().length, 1);
    });

    testWidgets('Reconnexion cloud requise : le bouton biométrie est masqué et le message explicatif apparaît', (tester) async {
      final repair = sl<CloudSessionRepairService>();
      repair.markAwaitingPinUnlock();

      final bloc = _FakeAuthBloc(const AuthLocked(testLockScreenWithBio));

      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pumpAndSettle();

      // Le bouton biométrie doit être masqué pour éviter la fausse manipulation
      expect(find.byIcon(Icons.fingerprint), findsNothing);

      // Le message explicite doit être présent pour guider l'utilisateur
      expect(find.text('Reconnexion cloud requise : saisissez votre code PIN'), findsOneWidget);
    });
  });
}
