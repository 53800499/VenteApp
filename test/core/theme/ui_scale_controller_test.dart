import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venteapp/core/theme/ui_scale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('UiScaleController', () {
    test('initializes with default scale (1.0 = 100%) when not set', () {
      final controller = UiScaleController(prefs);
      expect(controller.scaleFactor, 1.0);
      expect(controller.percentage, 100);
      expect(controller.isDefault, isTrue);
    });

    test('initializes with saved scale factor if present', () async {
      await prefs.setDouble(UiScaleController.keyTextScaleFactor, 1.25);
      final controller = UiScaleController(prefs);
      expect(controller.scaleFactor, 1.25);
      expect(controller.percentage, 125);
      expect(controller.isDefault, isFalse);
    });

    test('setScaleFactor updates scale, percentage, persists and notifies listeners', () async {
      final controller = UiScaleController(prefs);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setScaleFactor(1.15);

      expect(controller.scaleFactor, 1.15);
      expect(controller.percentage, 115);
      expect(notifyCount, 1);
      expect(prefs.getDouble(UiScaleController.keyTextScaleFactor), 1.15);
    });

    test('clamps scale between minScale (0.85) and maxScale (1.50)', () async {
      final controller = UiScaleController(prefs);

      await controller.setScaleFactor(0.50);
      expect(controller.scaleFactor, 0.85);

      await controller.setScaleFactor(2.00);
      expect(controller.scaleFactor, 1.50);
    });

    test('reset restores default scale 1.0', () async {
      final controller = UiScaleController(prefs);
      await controller.setScaleFactor(1.30);
      expect(controller.isDefault, isFalse);

      await controller.reset();
      expect(controller.scaleFactor, 1.0);
      expect(controller.percentage, 100);
      expect(controller.isDefault, isTrue);
    });
  });
}

