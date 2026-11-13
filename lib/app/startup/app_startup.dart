import 'package:flutter/material.dart';

import '../app.dart';
import '../di/injection_container.dart';
import '../../shared/components/global_error_fallback.dart';

class AppStartup {
  const AppStartup._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Remplacer l'écran rouge d'erreur Flutter par un composant d'affichage élégant et propre
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: GlobalErrorFallback(details: details),
      );
    };

    // Journalisation sans crash des exceptions de layout ou de widgets
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('[Arike FlutterError] ${details.exceptionAsString()}');
      if (originalOnError != null) {
        originalOnError(details);
      }
    };

    await initDependencies();
  }

  static Widget createApp() => const ArikeApp();
}
