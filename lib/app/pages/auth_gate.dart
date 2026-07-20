import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive/responsive_builder.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/first_launch_flow.dart';
import '../../features/auth/presentation/pages/membership_selection_page.dart';
import '../../features/auth/presentation/pages/whatsapp_login_page.dart';
import '../../features/auth/presentation/pages/shop_selection_page.dart';
import '../../features/auth/presentation/pages/lock_screen_page.dart';
import '../../features/auth/presentation/pages/recovery_token_page.dart';
import '../../features/dashboard/presentation/pages/home_shell_page.dart';

/// Route l'utilisateur vers l'écran d'authentification approprié.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthInitial() || AuthLoading() => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          AuthNeedsSetup() => const FirstLaunchFlow(),
          AuthSetupInProgress() || AuthSetupFailure() => const FirstLaunchFlow(),
          AuthSetupCompleted(:final result) =>
            RecoveryTokenPage(result: result),
          AuthLocked() => const LockScreenPage(),
          AuthWhatsappLogin() => const WhatsappLoginPage(),
          AuthMembershipSelection() => const MembershipSelectionPage(),
          AuthShopSelection() => const ShopSelectionPage(),
          AuthAuthenticated(:final session) =>
            HomeShellPage(
              key: ValueKey('shop-${session.shop.apiShopId}'),
              session: session,
            ),
          AuthFailure(:final message) => Scaffold(
              body: ResponsivePage(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context
                            .read<AuthBloc>()
                            .add(const AuthBootstrapRequested()),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        };
      },
    );
  }
}
