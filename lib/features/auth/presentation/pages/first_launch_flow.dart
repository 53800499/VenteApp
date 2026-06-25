import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import 'auth_entry_page.dart';
import 'setup_page.dart';

enum _FirstLaunchStep { entry, setup }

/// Parcours première utilisation : création boutique ou connexion PIN.
class FirstLaunchFlow extends StatefulWidget {
  const FirstLaunchFlow({super.key});

  @override
  State<FirstLaunchFlow> createState() => _FirstLaunchFlowState();
}

class _FirstLaunchFlowState extends State<FirstLaunchFlow> {
  _FirstLaunchStep _step = _FirstLaunchStep.entry;

  void _goToEntry() {
    context.read<AuthBloc>().add(const AuthEntryResetRequested());
    setState(() => _step = _FirstLaunchStep.entry);
  }

  SetupPage _setupPage() => SetupPage(
        onBack: _goToEntry,
      );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthSetupInProgress || state is AuthSetupFailure) {
          return _setupPage();
        }

        return switch (_step) {
          _FirstLaunchStep.entry => AuthEntryPage(
              onCreateShop: () => setState(() => _step = _FirstLaunchStep.setup),
              onLogin: () => context
                  .read<AuthBloc>()
                  .add(const AuthProceedToLoginRequested()),
            ),
          _FirstLaunchStep.setup => _setupPage(),
        };
      },
    );
  }
}
