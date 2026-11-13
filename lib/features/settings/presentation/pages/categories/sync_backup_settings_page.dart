import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/di/injection_container.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/components/app_page_container.dart';
import '../../../../../core/backup/google_drive_backup_service.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../bloc/settings_bloc.dart';
import '../../widgets/settings_confirmation.dart';

class SyncBackupSettingsPage extends StatefulWidget {
  const SyncBackupSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<SyncBackupSettingsPage> createState() => _SyncBackupSettingsPageState();
}

class _SyncBackupSettingsPageState extends State<SyncBackupSettingsPage> {
  String? _driveEmail;
  bool _driveAutoBackup = false;
  bool _isDriveLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDriveState();
  }

  Future<void> _loadDriveState() async {
    final drive = sl<GoogleDriveBackupService>();
    final email = await drive.connectedEmail();
    final auto = await drive.isAutoBackupEnabled();
    if (!mounted) return;
    setState(() {
      _driveEmail = email;
      _driveAutoBackup = auto;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation & Sauvegarde'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          if (config == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final syncEnabled = config.sync.enabled;

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
                      Icon(Icons.cloud_sync_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline-First & Cloud',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Gestion de la synchronisation continue et des sauvegardes de la base de données locale.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Cloud Sync
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsSwitchListTile(
                          title: const Text('Synchronisation cloud automatique'),
                          subtitle: const Text('Envoie et récupère les données dès qu\'une connexion est disponible'),
                          value: syncEnabled,
                          confirmationTitle: 'Synchronisation Cloud',
                          confirmationMessage: syncEnabled
                              ? 'Désactiver la synchronisation cloud automatique ? L\'application fonctionnera exclusivement hors ligne sans envoi distant.'
                              : 'Activer la synchronisation cloud automatique ?',
                          onChanged: widget.canWrite
                              ? (enabled) {
                                  context.read<SettingsBloc>().add(
                                        SettingsSyncToggled(enabled),
                                      );
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Local Backup
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sauvegarde locale de la base SQLite', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Exportez un fichier de sauvegarde chiffré pour conserver vos données en sécurité hors ligne.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await FilePicker.platform.saveFile(
                                    dialogTitle: 'Exporter la sauvegarde locale',
                                    fileName: 'arike_backup_${widget.session.shop.id}.arike',
                                  );
                                  if (result != null && context.mounted) {
                                    context.read<SettingsBloc>().add(
                                          SettingsBackupRecordRequested(path: result),
                                        );
                                  }
                                },
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('Exporter vers le stockage'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Google Drive Backup
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.add_to_drive, color: Colors.blue),
                            const SizedBox(width: AppSpacing.xs),
                            Text('Sauvegarde Cloud Google Drive', style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _driveEmail != null
                              ? 'Compte connecté : $_driveEmail'
                              : 'Aucun compte Google Drive connecté.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_driveEmail == null)
                          FilledButton.icon(
                            onPressed: _isDriveLoading
                                ? null
                                : () async {
                                    setState(() => _isDriveLoading = true);
                                    try {
                                      final drive = sl<GoogleDriveBackupService>();
                                      final account = await drive.signIn();
                                      if (mounted) {
                                        await _loadDriveState();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Compte Google Drive connecté : $account'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        final msg = e.toString()
                                            .replaceAll('Exception: ', '')
                                            .replaceAll('StateError: ', '');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(msg),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isDriveLoading = false);
                                      }
                                    }
                                  },
                            icon: _isDriveLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(_isDriveLoading ? 'Connexion en cours...' : 'Connecter Google Drive'),
                          )
                        else
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _isDriveLoading
                                    ? null
                                    : () async {
                                        final ok = await SettingsConfirmation.confirm(
                                          context,
                                          title: 'Déconnexion Google Drive',
                                          message: 'Déconnecter votre compte Google Drive de cette boutique ?',
                                          confirmLabel: 'Déconnecter',
                                          isDestructive: true,
                                        );
                                        if (!ok || !context.mounted) return;
                                        setState(() => _isDriveLoading = true);
                                        try {
                                          final drive = sl<GoogleDriveBackupService>();
                                          await drive.signOut();
                                          if (mounted) {
                                            await _loadDriveState();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Compte Google Drive déconnecté.'),
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _isDriveLoading = false);
                                          }
                                        }
                                      },
                                child: const Text('Déconnecter'),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Switch(
                                value: _driveAutoBackup,
                                onChanged: (val) async {
                                  final drive = sl<GoogleDriveBackupService>();
                                  await drive.setAutoBackupEnabled(val);
                                  await _loadDriveState();
                                },
                              ),
                              const Text('Auto-backup'),
                            ],
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
