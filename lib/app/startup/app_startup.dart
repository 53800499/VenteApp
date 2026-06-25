import 'package:flutter/material.dart';

import '../app.dart';
import '../di/injection_container.dart';

class AppStartup {
  const AppStartup._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initDependencies();
  }

  static Widget createApp() => const VenteApp();
}
