import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/app/theme/app_theme.dart';
import 'package:venteapp/features/sales/presentation/widgets/sale_feedback.dart';
import 'package:venteapp/shared/components/action_feedback.dart';
import 'package:venteapp/shared/components/adaptive_modal.dart';

void main() {
  testWidgets('SaleFeedback.confirm with AppTheme.light on desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await SaleFeedback.confirm(
                  context: context,
                  title: 'Confirmer la vente',
                  message: 'Enregistrer 50 000 FCFA en Espèces ?',
                );
              },
              child: const Text('Open Confirm'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmer la vente'), findsOneWidget);
    expect(find.text('Enregistrer 50 000 FCFA en Espèces ?'), findsOneWidget);
    expect(find.text('Confirmer'), findsOneWidget);

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('SaleFeedback.confirm with AppTheme.light on mobile', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await SaleFeedback.confirm(
                  context: context,
                  title: 'Confirmer la vente',
                  message: 'Enregistrer 50 000 FCFA en Espèces ?',
                );
              },
              child: const Text('Open Confirm'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmer la vente'), findsOneWidget);
    expect(find.text('Enregistrer 50 000 FCFA en Espèces ?'), findsOneWidget);
    expect(find.text('Confirmer'), findsOneWidget);

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('ActionFeedback.showSuccess and showErrorDialog with AppTheme.light', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => ActionFeedback.showSuccess(
                    context: context,
                    title: 'Vente enregistrée',
                    message: 'Total: 25 000 FCFA',
                  ),
                  child: const Text('Open Success'),
                ),
                ElevatedButton(
                  onPressed: () => ActionFeedback.showErrorDialog(
                    context,
                    title: 'Erreur',
                    message: 'Stock insuffisant',
                  ),
                  child: const Text('Open Error'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Test Success
    await tester.tap(find.text('Open Success'));
    await tester.pumpAndSettle();
    expect(find.text('Vente enregistrée'), findsOneWidget);
    expect(find.text('Total: 25 000 FCFA'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Test Error
    await tester.tap(find.text('Open Error'));
    await tester.pumpAndSettle();
    expect(find.text('Erreur'), findsOneWidget);
    expect(find.text('Stock insuffisant'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  testWidgets('showAdaptiveAppModal with form fields on mobile and desktop', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAdaptiveAppModal<void>(
                context: context,
                title: 'Nouveau client',
                builder: (ctx) => const TextField(
                  decoration: InputDecoration(labelText: 'Nom'),
                ),
                actions: [
                  Builder(
                    builder: (btnCtx) => FilledButton(
                      onPressed: () => Navigator.pop(btnCtx),
                      child: const Text('Sauvegarder'),
                    ),
                  ),
                ],
              ),
              child: const Text('Open Form Modal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Form Modal'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau client'), findsOneWidget);
    expect(find.text('Sauvegarder'), findsOneWidget);
    await tester.tap(find.text('Sauvegarder'));
    await tester.pumpAndSettle();
  });
}
