import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/auth_entities.dart';
import '../../features/auth/presentation/pages/emergency_unlock_page.dart';
import '../../features/auth/presentation/pages/forgot_pin_page.dart';
import '../../features/auth/presentation/pages/lock_screen_page.dart';
import '../../features/auth/presentation/pages/recovery_token_page.dart';
import '../../features/auth/presentation/pages/setup_page.dart';

class AppRouter {
  const AppRouter._();

  static const setup = '/setup';
  static const lock = '/lock';
  static const emergencyUnlock = '/emergency-unlock';
  static const forgotPin = '/forgot-pin';
  static const recovery = '/recovery';

  static Map<String, WidgetBuilder> routes() => {
        setup: (_) => const SetupPage(),
        lock: (_) => const LockScreenPage(),
        emergencyUnlock: (_) => const EmergencyUnlockPage(),
        forgotPin: (_) => const ForgotPinPage(shopId: 1),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == forgotPin) {
      final args = settings.arguments;
      if (args is Map<String, int?>) {
        return MaterialPageRoute(
          builder: (_) => ForgotPinPage(
            shopId: args['shopId'] ?? 1,
            userId: args['userId'],
            serverShopId: args['serverShopId'],
            serverUserId: args['serverUserId'],
          ),
        );
      }
    }
    if (settings.name == recovery) {
      final result = settings.arguments! as SetupOwnerResult;
      return MaterialPageRoute(
        builder: (_) => RecoveryTokenPage(result: result),
      );
    }
    return null;
  }
}
