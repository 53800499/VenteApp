import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_entities.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/pin_pad.dart';

class LockScreenPage extends StatefulWidget {
  const LockScreenPage({super.key});

  @override
  State<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage> {
  static const _minPinLength = 4;
  static const _maxPinLength = 6;
  String _pin = '';
  int? _selectedUserId;

  void _submitPin() {
    if (_pin.length < _minPinLength) return;
    final state = context.read<AuthBloc>().state;
    if (state is! AuthLocked) return;

    context.read<AuthBloc>().add(
          AuthLoginRequested(
            pin: _pin,
            shopId: state.lockScreen.shopId,
            userId: _selectedUserId ?? state.lockScreen.users.firstOrNull?.id,
          ),
        );
    setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLocked && state.errorMessage != null) {
          setState(() => _pin = '');
        }
      },
      builder: (context, state) {
        if (state is! AuthLocked) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final lockScreen = state.lockScreen;
        _selectedUserId ??= lockScreen.users.firstOrNull?.id;
        final selectedUser = lockScreen.users
            .where((user) => user.id == _selectedUserId)
            .firstOrNull;

        return Scaffold(
          body: GradientBackground(
            child: SafeArea(
              child: ResponsivePage(
                maxWidth: Breakpoints.authMaxWidth,
                padding: EdgeInsets.zero,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 720;

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        compact ? AppSpacing.sm : AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Column(
                        children: [
                          if (state.canGoBack)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => context.read<AuthBloc>().add(
                                          const AuthLockScreenBackRequested(),
                                        ),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Retour à l\'accueil'),
                              ),
                            ),
                          ShopAvatar(
                            label: lockScreen.shopName,
                            radius: compact ? 36 : 44,
                          ),
                          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                          Text(
                            lockScreen.shopName,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Entrez votre code PIN',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (lockScreen.users.length > 1) ...[
                            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                            _UserSelector(
                              users: lockScreen.users,
                              selectedUserId: _selectedUserId,
                              enabled: !state.isSubmitting,
                              onChanged: (value) =>
                                  setState(() => _selectedUserId = value),
                            ),
                          ] else if (selectedUser != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _UserChip(
                              name: selectedUser.name,
                              role: selectedUser.role.label,
                            ),
                          ],
                          if (state.errorMessage != null) ...[
                            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                            ErrorBanner(message: state.errorMessage!),
                          ],
                          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                          PinPad(
                            filledCount: _pin.length,
                            maxLength: _maxPinLength,
                            compact: compact,
                            enabled: !state.isSubmitting,
                            onDigit: (digit) {
                              if (_pin.length >= _maxPinLength) return;
                              setState(() => _pin += digit);
                              if (_pin.length == _maxPinLength) _submitPin();
                            },
                            onBackspace: () {
                              if (_pin.isEmpty) return;
                              setState(
                                () => _pin = _pin.substring(0, _pin.length - 1),
                              );
                            },
                          ),
                          if (_pin.length >= _minPinLength &&
                              _pin.length < _maxPinLength) ...[
                            const SizedBox(height: AppSpacing.sm),
                            FilledButton(
                              onPressed: state.isSubmitting ? null : _submitPin,
                              child: const Text('Valider'),
                            ),
                          ],
                          if (state.isSubmitting)
                            const Padding(
                              padding: EdgeInsets.only(top: AppSpacing.sm),
                              child: CircularProgressIndicator(),
                            ),
                          if (selectedUser?.biometricEnabled == true) ...[
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: state.isSubmitting
                                  ? null
                                  : () {
                                      context.read<AuthBloc>().add(
                                            AuthBiometricLoginRequested(
                                              shopId: lockScreen.shopId,
                                              userId: _selectedUserId,
                                            ),
                                          );
                                    },
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Empreinte digitale'),
                            ),
                          ],
                          if (state.requiresEmergencyRecovery) ...[
                            const SizedBox(height: AppSpacing.xs),
                            TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pushNamed(AppRouter.emergencyUnlock),
                              child: const Text('Déblocage d\'urgence'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '$name · $role',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _UserSelector extends StatelessWidget {
  const _UserSelector({
    required this.users,
    required this.selectedUserId,
    required this.enabled,
    required this.onChanged,
  });

  final List<LockScreenUser> users;
  final int? selectedUserId;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            isExpanded: true,
            value: selectedUserId,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            items: users
                .map(
                  (user) => DropdownMenuItem(
                    value: user.id,
                    child: Text('${user.name} (${user.role.label})'),
                  ),
                )
                .toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
    );
  }
}
