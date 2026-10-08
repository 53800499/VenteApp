import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/responsive/breakpoints.dart';
import 'package:venteapp/core/responsive/responsive_builder.dart';
import 'package:venteapp/core/responsive/screen_type.dart';
import 'package:venteapp/shared/components/app_page_container.dart';

void main() {
  group('Desktop Adaptive Layout (Full Width & No 960px Bottleneck)', () {
    test('Breakpoints.contentMaxExpanded is double.infinity for Desktop', () {
      expect(Breakpoints.contentMaxExpanded, double.infinity);
      expect(
        Breakpoints.contentMaxWidth(ScreenType.expanded),
        double.infinity,
      );
    });

    testWidgets('ResponsivePage expands to 100% width on Desktop (1280px)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsivePage(
              child: SizedBox(
                key: Key('responsive_child'),
                height: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderBox = tester.renderObject<RenderBox>(
        find.byKey(const Key('responsive_child')),
      );
      // The child should occupy the entire width (1280px), not 960px
      expect(renderBox.size.width, 1280.0);
    });

    testWidgets('AppPageContainer expands to 100% width on Desktop by default',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppPageContainer(
              child: SizedBox(
                key: Key('container_child'),
                height: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderBox = tester.renderObject<RenderBox>(
        find.byKey(const Key('container_child')),
      );
      // The child should occupy the entire width (1440px), not 960px
      expect(renderBox.size.width, 1440.0);
    });

    testWidgets('AppPageContainer.form keeps form width ergonomically constrained',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppPageContainer.form(
              child: SizedBox(
                key: Key('form_child'),
                width: double.infinity,
                height: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderBox = tester.renderObject<RenderBox>(
        find.byKey(const Key('form_child')),
      );
      // Form should remain ergonomically constrained to 560px
      expect(renderBox.size.width, 560.0);
    });
  });
}
