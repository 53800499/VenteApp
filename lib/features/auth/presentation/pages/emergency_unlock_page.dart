import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../bloc/auth_bloc.dart';

class EmergencyUnlockPage extends StatefulWidget {
  const EmergencyUnlockPage({super.key});

  @override
  State<EmergencyUnlockPage> createState() => _EmergencyUnlockPageState();
}

class _EmergencyUnlockPageState extends State<EmergencyUnlockPage> {
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _submit() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    context.read<AuthBloc>().add(
          AuthEmergencyUnlockRequested(recoveryToken: token),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Déblocage d\'urgence')),
      body: GradientBackground(
        child: SafeArea(
          child: ResponsiveFormPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(
                  icon: Icons.vpn_key_outlined,
                  title: 'Jeton de récupération',
                  subtitle:
                      'Saisissez le jeton généré lors de l\'installation pour débloquer l\'accès.',
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    labelText: 'Jeton de récupération',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  maxLines: 4,
                ),
                const Spacer(),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return FilledButton.icon(
                      onPressed: isLoading ? null : _submit,
                      icon: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_outlined),
                      label: const Text('Débloquer'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
