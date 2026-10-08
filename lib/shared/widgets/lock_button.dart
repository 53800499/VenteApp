import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/lock_screen_page.dart';
import 'app_key_button.dart';

export 'app_key_button.dart';

class LockButton extends StatelessWidget {
  const LockButton({
    super.key,
    this.iconSize = 22.0,
    this.color,
    this.tooltip = 'Verrouiller la session',
  });

  final double iconSize;
  final Color? color;
  final String tooltip;

  /// Triggers lock screen from any page and pops back upon successful unlock.
  static Future<bool?> lockSession(BuildContext context) async {
    // Notify AuthBloc that session is locked
    context.read<AuthBloc>().add(const AuthLockScreenRequested(canGoBack: true));

    // Push LockScreenPage on top of current navigation stack
    final unlocked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LockScreenPage(),
        fullscreenDialog: true,
      ),
    );

    return unlocked;
  }

  @override
  Widget build(BuildContext context) {
    return AppKeyButton(
      iconSize: iconSize,
      onLock: () => lockSession(context),
    );
  }
}
