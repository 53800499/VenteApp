import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/di/injection_container.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/components/app_page_container.dart';
import '../../../../auth/data/datasources/local/biometric_local_datasource.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../../domain/entities/settings_entities.dart';
import '../../../domain/services/settings_validation_service.dart';
import '../../bloc/settings_bloc.dart';
import '../change_pin_page.dart';
import '../connected_devices_page.dart';
import '../disable_biometric_page.dart';
import '../enable_biometric_page.dart';

class SecurityDeviceSettingsPage extends StatefulWidget {
  const SecurityDeviceSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<SecurityDeviceSettingsPage> createState() => _SecurityDeviceSettingsPageState();
}

class _SecurityDeviceSettingsPageState extends State<SecurityDeviceSettingsPage> {
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _biometricEnabled = widget.session.user.biometricEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité & Appareils'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          if (config == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final autoLock = const SettingsValidationService().normalizeAutoLockMinutes(
            config.security.autoLockMinutes,
          );

          return AppPageContainer(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Protections d\'accès',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Code PIN local, authentification biométrique, verrouillage automatique et appareils révoqués.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: const Text('Modifier le code PIN'),
                        subtitle: const Text('Changer votre code de déverrouillage local (4-6 chiffres)'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangePinPage(session: widget.session),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.fingerprint_outlined),
                        title: const Text('Biométrie (Empreinte / FaceID)'),
                        subtitle: Text(
                          _biometricEnabled
                              ? 'Biométrie activée pour le déverrouillage rapide'
                              : 'Biométrie désactivée',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          if (_biometricEnabled) {
                            final disabled = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => DisableBiometricPage(session: widget.session),
                              ),
                            );
                            if (disabled == true && context.mounted) {
                              setState(() => _biometricEnabled = false);
                            }
                          } else {
                            final bioDs = sl<BiometricLocalDatasource>();
                            final supported = await bioDs.canCheckBiometrics();
                            if (!supported && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Votre appareil ne prend pas en charge la biométrie.'),
                                ),
                              );
                              return;
                            }
                            if (!context.mounted) return;
                            final enabled = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => EnableBiometricPage(session: widget.session),
                              ),
                            );
                            if (enabled == true && context.mounted) {
                              setState(() => _biometricEnabled = true);
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.devices_outlined),
                        title: const Text('Appareils connectés'),
                        subtitle: const Text('Voir et révoquer les sessions actives sur d\'autres appareils'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConnectedDevicesPage(session: widget.session),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Délai de verrouillage automatique', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<int>(
                          initialValue: autoLock,
                          decoration: const InputDecoration(
                            labelText: 'Durée d\'inactivité avant verrouillage PIN',
                          ),
                          items: autoLockMinuteOptions
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m min'),
                                ),
                              )
                              .toList(),
                          onChanged: widget.canWrite
                              ? (val) {
                                  if (val != null) {
                                    context.read<SettingsBloc>().add(
                                          SettingsAutoLockChanged(val),
                                        );
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}
