import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/auth/presentation/widgets/auth_split_layout.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

const _contentKey = Key('auth-content');

AuthSplitLayout _layout() => const AuthSplitLayout(
      heroIcon: Icons.chat_outlined,
      heroTitle: 'Hero Title',
      heroSubtitle: 'Hero subtitle',
      points: [
        AuthHeroPoint(
          icon: Icons.key_outlined,
          title: 'Point A',
          subtitle: 'Desc A',
        ),
      ],
      child: SizedBox.expand(key: _contentKey),
    );

void main() {
  group('AuthSplitLayout', () {
    testWidgets('mobile renders child only', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_layout()));

      expect(find.byKey(_contentKey), findsOneWidget);
      expect(find.text('Hero Title'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop renders full-height edge-docked left panel',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_layout()));

      expect(find.text('Hero Title'), findsOneWidget);
      expect(find.text('Point A'), findsOneWidget);
      expect(find.byKey(_contentKey), findsOneWidget);

      // Le volet gauche démarre au bord gauche et occupe toute la hauteur.
      final leftPanel = find
          .ancestor(of: find.text('Hero Title'), matching: find.byType(Expanded))
          .first;
      final rect = tester.getRect(leftPanel);
      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.height, 800);
      expect(tester.takeException(), isNull);
    });
  });
}
