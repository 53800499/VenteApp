import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/auth/presentation/pages/auth_entry_page.dart';
import 'package:venteapp/features/onboarding/data/onboarding_slides.dart';
import 'package:venteapp/features/onboarding/presentation/widgets/onboarding_desktop_view.dart';

void main() {
  group('AuthEntryPage Adaptive Layout Tests', () {
    testWidgets('Renders Mobile layout on 400x800', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AuthEntryPage(
            onCreateShop: () {},
            onLogin: () {},
            localSetupAvailable: true,
            onPinLogin: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile displays single column entry cards
      expect(find.text('Comment utilisez-vous ARIKE ?'), findsOneWidget);
      expect(find.text('Créer une boutique'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Connexion par PIN'), findsOneWidget);

      // Desktop-specific left bullet points should NOT be present on mobile
      expect(find.text('100% Offline-First'), findsNothing);
      expect(find.text('Maîtrise des Stocks'), findsNothing);
    });

    testWidgets('Renders full-bleed 2-column Adaptive Desktop layout on 1280x800',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AuthEntryPage(
            onCreateShop: () {},
            onLogin: () {},
            localSetupAvailable: true,
            onPinLogin: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop volet gauche : Identité & Atouts
      expect(find.text('ARIKE VenteApp'), findsOneWidget);
      expect(find.text('100% Offline-First'), findsOneWidget);
      expect(find.text('Maîtrise des Stocks'), findsOneWidget);
      expect(find.text('Dettes & Relances WhatsApp'), findsOneWidget);
      expect(
        find.text('Données chiffrées & sauvegardées localement sur ce poste'),
        findsOneWidget,
      );

      // Desktop volet droit : Cartes de choix
      expect(find.text('Comment utilisez-vous ARIKE ?'), findsOneWidget);
      expect(find.text('Créer une boutique'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Connexion par PIN'), findsOneWidget);
    });
  });

  group('OnboardingDesktopView Adaptive Layout Tests', () {
    testWidgets('Renders full-height edge-docked left panel on 1280x800',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingDesktopView(
            onComplete: () {},
            slides: onboardingSlides,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En-tête Desktop
      expect(find.text('ARIKE VenteApp'), findsOneWidget);
      expect(find.text('Édition Windows POS'), findsOneWidget);

      // Volet Gauche docked bord à bord
      expect(find.text('LES 8 PILIERS ARIKE'), findsOneWidget);
      expect(find.text('Cliquez pour explorer un module'), findsOneWidget);

      // Volet Droit vitrine immersive
      expect(find.text('ATOUTS MAJEURS SUR WINDOWS'), findsOneWidget);
      expect(find.text('APERÇU VISUEL DU MODULE'), findsOneWidget);

      // Barre de raccourcis clavier en bas
      expect(find.text('Naviguer'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
    });
  });
}
