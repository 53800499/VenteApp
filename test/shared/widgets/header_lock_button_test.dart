import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/core/auth/cloud_session_repair_service.dart';
import 'package:venteapp/core/auth/recent_pin_proof.dart';
import 'package:venteapp/core/network/network_monitor.dart';
import 'package:venteapp/shared/widgets/header_lock_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await initDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('HeaderLockButton is grey when session is normal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HeaderLockButton(),
        ),
      ),
    );

    // Initial state: normal grey lock outline
    final iconFinder = find.byIcon(Icons.lock_outline_rounded);
    expect(iconFinder, findsOneWidget);
  });

  testWidgets('HeaderLockButton turns red when awaiting PIN reconnection', (tester) async {
    final repair = sl<CloudSessionRepairService>();

    // Simulate session needing PIN unlock
    repair.markAwaitingPinUnlock();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HeaderLockButton(filledTonal: true),
        ),
      ),
    );

    // Should display red locked icon and alert tooltip
    final redIconFinder = find.byIcon(Icons.lock_rounded);
    expect(redIconFinder, findsOneWidget);

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      iconButton.tooltip,
      contains('Reconnexion au serveur requise'),
    );
  });

  testWidgets('HeaderLockButton turns red when server connection is lost', (tester) async {
    // Re-register NetworkMonitor as localNetworkOnly (connected to wifi/radio, but backend unreachable)
    if (sl.isRegistered<NetworkMonitor>()) {
      await sl.unregister<NetworkMonitor>();
    }
    sl.registerSingleton<NetworkMonitor>(NetworkMonitor.fixed(NetworkState.localNetworkOnly));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HeaderLockButton(filledTonal: true),
        ),
      ),
    );

    // Should display red locked icon indicating server disconnected
    final redIconFinder = find.byIcon(Icons.lock_rounded);
    expect(redIconFinder, findsOneWidget);

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      iconButton.tooltip,
      contains('Connexion au serveur perdue'),
    );
  });

  testWidgets('HeaderLockButton does not turn red if recent PIN proof is already present', (tester) async {
    if (sl.isRegistered<NetworkMonitor>()) {
      await sl.unregister<NetworkMonitor>();
    }
    sl.registerSingleton<NetworkMonitor>(NetworkMonitor.fixed(NetworkState.localNetworkOnly));

    // Preuve PIN déjà en mémoire vive
    sl<RecentPinProof>().record(
      pin: '1234',
      serverShopId: 1,
      localShopId: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HeaderLockButton(filledTonal: true),
        ),
      ),
    );

    // Cadenas normal (non rouge) car l'utilisateur a déjà déverrouillé par PIN
    final outlineIconFinder = find.byIcon(Icons.lock_outline_rounded);
    expect(outlineIconFinder, findsOneWidget);

    final redIconFinder = find.byIcon(Icons.lock_rounded);
    expect(redIconFinder, findsNothing);
  });
}

