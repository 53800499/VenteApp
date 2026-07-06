import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/auth/app_lock_controller.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../notifications/presentation/pages/notification_settings_page.dart';
import '../../domain/entities/settings_entities.dart';
import '../../domain/services/settings_validation_service.dart';
import '../../domain/usecases/settings_usecases.dart';
import '../bloc/settings_bloc.dart';
import '../widgets/settings_feedback.dart';
import '../../../../core/backup/backup_file_sharer.dart';
import '../../../../core/backup/google_drive_backup_service.dart';
import 'change_pin_page.dart';
import 'connected_devices_page.dart';
import '../../../auth/data/datasources/local/biometric_local_datasource.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../../../auth/presentation/widgets/pin_pad.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.session});

  final AuthSession session;

  bool get _canRead => PermissionGuard.can(
        session.user.permissions,
        Permission.settingsRead,
      );

  bool get _canWrite => PermissionGuard.can(
        session.user.permissions,
        Permission.settingsWrite,
      );

  @override
  Widget build(BuildContext context) {
    ensureSettingsDependencies();

    if (!_canRead) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paramètres')),
        body: const Center(
          child: Text('Vous n\'avez pas accès aux paramètres.'),
        ),
      );
    }

    return BlocProvider(
      create: (_) => SettingsBloc(
        getConfiguration: sl<GetShopConfiguration>(),
        updateConfiguration: sl<UpdateShopConfiguration>(),
        recordBackup: sl<RecordShopBackup>(),
        updateSyncSettings: sl<UpdateShopSyncSettings>(),
        shopId: session.shop.id,
      )..add(const SettingsLoadRequested()),
      child: _SettingsView(canWrite: _canWrite, session: session),
    );
  }
}

class _SettingsView extends StatefulWidget {
  const _SettingsView({required this.canWrite, required this.session});

  final bool canWrite;
  final AuthSession session;

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _shopFormKey = GlobalKey<FormState>();
  final _receiptFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _footerController = TextEditingController();
  bool _hydrated = false;
  int? _lastUpdatedAt;
  bool _biometricEnabled = false;
  String? _driveEmail;
  bool _driveAutoBackup = false;

  @override
  void initState() {
    super.initState();
    _biometricEnabled = widget.session.user.biometricEnabled;
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
    await drive.retryPendingUpload(
      createBackup: ({
        required int shopId,
        required String shopName,
        required String passphrase,
      }) =>
          sl<CreateShopBackup>()(
        shopId: shopId,
        shopName: shopName,
        passphrase: passphrase,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _hydrate(ShopConfiguration config) {
    _nameController.text = config.shop.name;
    _phoneController.text = config.shop.phone ?? '';
    _addressController.text = config.shop.address ?? '';
    _footerController.text = config.receipts.footer ?? '';
    _hydrated = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.adminCacheMessage,
          ),
          Expanded(
            child: BlocConsumer<SettingsBloc, SettingsState>(
        listenWhen: (prev, curr) {
          if (prev.errorMessage != curr.errorMessage &&
              curr.errorMessage != null &&
              curr.status == SettingsStatus.loaded) {
            return true;
          }
          if (prev.successMessage != curr.successMessage &&
              curr.successMessage != null) {
            return true;
          }
          if (!prev.refreshSession && curr.refreshSession) {
            return true;
          }
          return false;
        },
        listener: (context, state) async {
          if (state.refreshSession) {
            final session = await sl<AuthRepository>().restoreSession();
            if (session != null && context.mounted) {
              context.read<AuthBloc>().add(AuthSessionRefreshed(session));
            }
            if (context.mounted) {
              context
                  .read<SettingsBloc>()
                  .add(const SettingsSessionRefreshAcknowledged());
            }
          }
          if (state.errorMessage != null &&
              state.status == SettingsStatus.loaded) {
            if (!context.mounted) return;
            await SettingsFeedback.showErrorDialog(
              context,
              title: 'Action impossible',
              message: state.errorMessage!,
            );
            if (context.mounted) {
              context.read<SettingsBloc>().add(const SettingsFeedbackDismissed());
            }
            return;
          }
          if (state.successMessage != null) {
            if (!context.mounted) return;
            await SettingsFeedback.showSuccess(
              context: context,
              title: state.successMessage!,
            );
            if (context.mounted) {
              context.read<SettingsBloc>().add(const SettingsFeedbackDismissed());
            }
          }
        },
        builder: (context, state) {
          final config = state.configuration;

          if (config == null) {
            if (state.status == SettingsStatus.failure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.errorMessage ?? 'Erreur de chargement'),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: () => context
                            .read<SettingsBloc>()
                            .add(const SettingsLoadRequested()),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  Text('Chargement des paramètres…'),
                ],
              ),
            );
          }

          if (!_hydrated || _lastUpdatedAt != config.updatedAt) {
            _hydrate(config);
            _lastUpdatedAt = config.updatedAt;
          }

          final autoLock = const SettingsValidationService()
              .normalizeAutoLockMinutes(config.security.autoLockMinutes);

          return Column(
            children: [
              if (state.isSaving)
                const LinearProgressIndicator()
              else
                const SizedBox.shrink(),
              Expanded(
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Configuration boutique',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Module 10 — identité, inventaire, sécurité, reçus et sauvegarde.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (state.errorMessage != null &&
                            state.status == SettingsStatus.loaded) ...[
                          const SizedBox(height: AppSpacing.sm),
                          ErrorBanner(message: state.errorMessage!),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle(title: 'Boutique'),
                        Form(
                          key: _shopFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                enabled: widget.canWrite && !state.isSaving,
                                decoration: const InputDecoration(
                                  labelText: 'Nom de la boutique *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().length < 2) {
                                    return 'Au moins 2 caractères';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _phoneController,
                                enabled: widget.canWrite && !state.isSaving,
                                decoration: const InputDecoration(
                                  labelText: 'Téléphone',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _addressController,
                                enabled: widget.canWrite && !state.isSaving,
                                decoration: const InputDecoration(
                                  labelText: 'Adresse',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (widget.canWrite) ...[
                                const SizedBox(height: AppSpacing.md),
                                FilledButton(
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _saveShop(context),
                                  child: state.isSaving
                                      ? SettingsFeedback.inlineLoader()
                                      : const Text('Enregistrer la boutique'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle(title: 'Localisation'),
                        _ReadOnlyField(
                          label: 'Devise',
                          value: config.localization.currency,
                          hint: 'Non modifiable (RG-PARAM-01)',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _ReadOnlyField(
                          label: 'Langue',
                          value: 'Français',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle(title: 'Inventaire'),
                        Text(
                          'Seuil d\'alerte stock par défaut',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            'threshold-${config.inventory.defaultAlertThreshold}',
                          ),
                          initialValue: config.inventory.defaultAlertThreshold,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [3, 5, 10, 15, 20]
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('$v unités'),
                                ),
                              )
                              .toList(),
                          onChanged: !widget.canWrite || state.isSaving
                              ? null
                              : (value) async {
                                  if (value == null) return;
                                  final confirmed =
                                      await SettingsFeedback.confirm(
                                    context: context,
                                    title: 'Modifier le seuil',
                                    message:
                                        'Définir le seuil d\'alerte à $value unités ?',
                                  );
                                  if (confirmed == true && context.mounted) {
                                    context.read<SettingsBloc>().add(
                                          SettingsThresholdChanged(value),
                                        );
                                  }
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Grilles tarifaires'),
                          subtitle: const Text(
                            'Détail, demi-gros et gros sur les produits et ventes.',
                          ),
                          value: config.commerce.pricingTiersEnabled,
                          onChanged: !widget.canWrite || state.isSaving
                              ? null
                              : (enabled) {
                                  context.read<SettingsBloc>().add(
                                        SettingsPricingTiersChanged(enabled),
                                      );
                                },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle(title: 'Sécurité'),
                        Text(
                          'Verrouillage automatique',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<int>(
                          key: ValueKey('autolock-$autoLock'),
                          initialValue: autoLock,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: autoLockMinuteOptions
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m min'),
                                ),
                              )
                              .toList(),
                          onChanged: !widget.canWrite || state.isSaving
                              ? null
                              : (value) async {
                                  if (value == null) return;
                                  final confirmed =
                                      await SettingsFeedback.confirm(
                                    context: context,
                                    title: 'Modifier le verrouillage',
                                    message:
                                        'Verrouiller l\'app après $value minutes d\'inactivité ?',
                                  );
                                  if (confirmed == true && context.mounted) {
                                    context.read<SettingsBloc>().add(
                                          SettingsAutoLockChanged(value),
                                        );
                                  }
                                },
                        ),
                        if (widget.canWrite) ...[
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: state.isSaving
                                ? null
                                : () => _openChangePin(context),
                            icon: const Icon(Icons.password_outlined),
                            label: const Text('Changer mon PIN'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _BiometricTile(
                            enabled: _biometricEnabled,
                            canEnable: PermissionGuard.can(
                              widget.session.user.permissions,
                              Permission.authBiometricEnable,
                            ),
                            onEnable: state.isSaving
                                ? null
                                : _openEnableBiometric,
                            onDisable: state.isSaving
                                ? null
                                : _openDisableBiometric,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: state.isSaving
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ConnectedDevicesPage(
                                          session: widget.session,
                                        ),
                                      ),
                                    ),
                            icon: const Icon(Icons.devices_outlined),
                            label: const Text('Appareils connectés'),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle(title: 'Reçus'),
                        Form(
                          key: _receiptFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _footerController,
                                enabled: widget.canWrite && !state.isSaving,
                                decoration: const InputDecoration(
                                  labelText: 'Message en bas de reçu',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 3,
                                maxLength: SettingsValidationService
                                    .receiptFooterMaxLength,
                              ),
                              if (widget.canWrite) ...[
                                const SizedBox(height: AppSpacing.md),
                                FilledButton(
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _saveReceipt(context),
                                  child: const Text('Enregistrer le pied de reçu'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle(title: 'Sauvegarde'),
                        if (config.backup.reminderRecommended)
                          const Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ErrorBanner(
                              message:
                                  'Dernière sauvegarde absente ou datant de plus de 7 jours.',
                            ),
                          ),
                        Text(
                          _formatBackupStatus(config.backup),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (widget.canWrite) ...[
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: state.isSaving
                                ? null
                                : () => _createBackup(context, config.shop.name),
                            icon: const Icon(Icons.save_alt_outlined),
                            label: const Text('Créer sauvegarde .venteapp'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: state.isSaving
                                ? null
                                : () => _restoreBackup(context),
                            icon: const Icon(Icons.restore_outlined),
                            label: const Text('Restaurer .venteapp'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: state.isSaving
                                ? null
                                : () => _exportJson(context, config.shop.name),
                            icon: const Icon(Icons.data_object_outlined),
                            label: const Text('Exporter JSON'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: state.isSaving
                                ? null
                                : () => _saveToGoogleDrive(
                                      context,
                                      config.shop.name,
                                    ),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Sauvegarder sur Google Drive'),
                          ),
                          if (_driveEmail != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text('Compte Google : $_driveEmail'),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Sauvegarde auto sur Drive'),
                              subtitle: const Text(
                                'Upload automatique au retour réseau',
                              ),
                              value: _driveAutoBackup,
                              onChanged: state.isSaving
                                  ? null
                                  : (v) async {
                                      await sl<GoogleDriveBackupService>()
                                          .setAutoBackupEnabled(v);
                                      if (mounted) {
                                        setState(() => _driveAutoBackup = v);
                                      }
                                    },
                            ),
                            TextButton(
                              onPressed: state.isSaving
                                  ? null
                                  : () => _disconnectGoogleDrive(context),
                              child: const Text('Déconnecter Google'),
                            ),
                          ] else ...[
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: state.isSaving
                                  ? null
                                  : () => _connectGoogleDrive(context),
                              icon: const Icon(Icons.login),
                              label: const Text('Connecter Google Drive'),
                            ),
                          ],
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle(title: 'Synchronisation cloud'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Sync cloud (V2)'),
                          subtitle: Text(
                            config.sync.enabled
                                ? 'Activée${_formatSyncDate(config.sync.lastAt)}'
                                : 'Désactivée — données locales uniquement',
                          ),
                          value: config.sync.enabled,
                          onChanged: !widget.canWrite || state.isSaving
                              ? null
                              : (v) => context.read<SettingsBloc>().add(
                                    SettingsSyncToggled(v),
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle(title: 'Notifications'),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.notifications_outlined),
                            title: const Text('Alertes'),
                            subtitle: const Text(
                              'Stock, dettes, résumé du jour…',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NotificationSettingsPage(
                                  session: widget.session,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveShop(BuildContext context) async {
    if (!_shopFormKey.currentState!.validate()) return;
    final confirmed = await SettingsFeedback.confirm(
      context: context,
      title: 'Enregistrer la boutique',
      message:
          'Mettre à jour « ${_nameController.text.trim()} » ?',
    );
    if (confirmed != true || !context.mounted) return;
    context.read<SettingsBloc>().add(
          SettingsShopSaveRequested(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
          ),
        );
  }

  Future<void> _saveReceipt(BuildContext context) async {
    if (!_receiptFormKey.currentState!.validate()) return;
    final confirmed = await SettingsFeedback.confirm(
      context: context,
      title: 'Enregistrer le pied de reçu',
      message: 'Appliquer ce message sur les prochains reçus ?',
    );
    if (confirmed != true || !context.mounted) return;
    context.read<SettingsBloc>().add(
          SettingsReceiptSaveRequested(_footerController.text.trim()),
        );
  }

  Future<void> _openChangePin(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangePinPage(session: widget.session),
      ),
    );
  }

  Future<void> _refreshBiometricSession() async {
    final session = await sl<AuthRepository>().restoreSession();
    if (session != null && mounted) {
      context.read<AuthBloc>().add(AuthSessionRefreshed(session));
      setState(() => _biometricEnabled = session.user.biometricEnabled);
    }
  }

  Future<void> _openEnableBiometric() async {
    final pin = await _askPinConfirmation(
      title: 'Activer la biométrie',
      subtitle:
          'Saisissez votre code PIN pour activer le déverrouillage par empreinte.',
      confirmLabel: 'Activer',
    );
    if (pin == null || !mounted) return;

    final canUseBio = await sl<BiometricLocalDatasource>().canCheckBiometrics();
    if (!canUseBio) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Empreinte indisponible',
        message:
            'Aucune empreinte n\'est configurée sur cet appareil. '
            'Enregistrez-en une dans les réglages du téléphone.',
      );
      return;
    }

    try {
      final bioOk = await sl<BiometricLocalDatasource>().authenticate();
      if (!bioOk) {
        if (!mounted) return;
        await SettingsFeedback.showErrorDialog(
          context,
          title: 'Empreinte non validée',
          message:
              'L\'activation a été annulée ou l\'empreinte n\'a pas été reconnue.',
        );
        return;
      }
    } on Failure catch (e) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Empreinte indisponible',
        message: friendlyErrorMessage(e),
      );
      return;
    }
    if (!mounted) return;

    try {
      final ok = await ActionFeedback.runWithBlockingLoader(
        context: context,
        message: 'Activation…',
        action: () => sl<EnableBiometric>()(
          userId: widget.session.user.id,
          sessionToken: widget.session.token,
          pin: pin,
        ),
      );
      if (ok != true || !mounted) return;
      await SettingsFeedback.showSuccess(
        context: context,
        title: 'Biométrie activée',
        message: 'Vous pourrez déverrouiller avec votre empreinte.',
      );
      await _refreshBiometricSession();
    } on Failure catch (e) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Activation impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Activation impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  Future<void> _openDisableBiometric() async {
    final pin = await _askPinConfirmation(
      title: 'Désactiver la biométrie',
      subtitle:
          'Saisissez votre code PIN pour désactiver le déverrouillage par empreinte.',
      confirmLabel: 'Désactiver',
    );
    if (pin == null || !mounted) return;

    try {
      final ok = await ActionFeedback.runWithBlockingLoader(
        context: context,
        message: 'Désactivation…',
        action: () => sl<DisableBiometric>()(
          userId: widget.session.user.id,
          sessionToken: widget.session.token,
          pin: pin,
        ),
      );
      if (ok != true || !mounted) return;
      await SettingsFeedback.showSuccess(
        context: context,
        title: 'Biométrie désactivée',
        message: 'Le déverrouillage par empreinte est désormais inactif.',
      );
      await _refreshBiometricSession();
    } on Failure catch (e) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Désactivation impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Désactivation impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  Future<String?> _askPinConfirmation({
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PinConfirmSheet(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
      ),
    );
  }

  Future<void> _connectGoogleDrive(BuildContext context) async {
    try {
      final email = await ActionFeedback.runWithBlockingLoader(
        context: context,
        message: 'Connexion Google…',
        action: () => sl<GoogleDriveBackupService>().signIn(),
      );
      if (!mounted || email == null) return;
      setState(() => _driveEmail = email);
      await SettingsFeedback.showSuccess(
        context: context,
        title: 'Google Drive connecté',
        message: 'Compte : $email',
      );
    } catch (e) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Connexion impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  Future<void> _disconnectGoogleDrive(BuildContext context) async {
    await sl<GoogleDriveBackupService>().signOut();
    if (mounted) setState(() => _driveEmail = null);
  }

  Future<void> _saveToGoogleDrive(BuildContext context, String shopName) async {
    final passphrase = await _askPassphrase(
      context,
      title: 'Sauvegarde Google Drive',
      confirmLabel: 'Créer',
    );
    if (passphrase == null || !context.mounted) return;

    try {
      final file = await ActionFeedback.runWithBlockingLoader(
        context: context,
        message: 'Préparation de la sauvegarde…',
        action: () => sl<CreateShopBackup>()(
          shopId: widget.session.shop.id,
          shopName: shopName,
          passphrase: passphrase,
        ),
      );
      if (file == null || !context.mounted) return;

      final drive = sl<GoogleDriveBackupService>();
      final email = await drive.connectedEmail();
      if (email != null) {
        try {
          final message = await ActionFeedback.runWithBlockingLoader(
            context: context,
            message: 'Upload vers Google Drive…',
            action: () => drive.uploadBackup(file),
          );
          if (!context.mounted) return;
          context.read<SettingsBloc>().add(const SettingsLoadRequested());
          await SettingsFeedback.showSuccess(
            context: context,
            title: 'Sauvegarde sur Drive',
            message: message ?? 'Fichier uploadé dans le dossier VenteApp.',
          );
          return;
        } catch (e) {
          if (_driveAutoBackup) {
            await drive.queuePendingUpload(
              shopId: widget.session.shop.id,
              shopName: shopName,
              passphrase: passphrase,
            );
          }
          if (!context.mounted) return;
          await SettingsFeedback.showErrorDialog(
            context,
            title: 'Upload Drive échoué',
            message:
                '${friendlyErrorMessage(e)}\n\n'
                'Partage manuel proposé en secours.',
          );
        }
      }

      await BackupFileSharer.share(
        file,
        subject: 'Sauvegarde VenteApp — $shopName',
        text:
            'Sauvegarde chiffrée VenteApp. Enregistrez ce fichier sur Google Drive.',
      );

      if (!context.mounted) return;
      context.read<SettingsBloc>().add(const SettingsLoadRequested());
      await SettingsFeedback.showSuccess(
        context: context,
        title: 'Sauvegarde partagée',
        message: 'Choisissez Google Drive dans le menu de partage.',
      );
    } on Failure catch (e) {
      if (!context.mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Sauvegarde impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!context.mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Sauvegarde impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  Future<String?> _askPassphrase(
    BuildContext context, {
    required String title,
    String? confirmLabel,
  }) async {
    final controller = TextEditingController();
    String? error;

    final value = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Phrase secrète (min. 8 caractères)',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.length < 8) {
                  setState(
                    () => error = 'Minimum 8 caractères requis.',
                  );
                  return;
                }
                Navigator.pop(ctx, trimmed);
              },
              child: Text(confirmLabel ?? 'Confirmer'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _createBackup(BuildContext context, String shopName) async {
    final passphrase = await _askPassphrase(
      context,
      title: 'Sauvegarde chiffrée',
      confirmLabel: 'Créer',
    );
    if (passphrase == null || !context.mounted) return;

    try {
      final file = await ActionFeedback.runWithBlockingLoader(
        context: context,
        message: 'Création de la sauvegarde…',
        action: () => sl<CreateShopBackup>()(
          shopId: widget.session.shop.id,
          shopName: shopName,
          passphrase: passphrase,
        ),
      );
      if (file == null || !context.mounted) return;

      await BackupFileSharer.share(
        file,
        subject: 'Sauvegarde $shopName',
      );

      if (!context.mounted) return;
      context.read<SettingsBloc>().add(const SettingsLoadRequested());
      await SettingsFeedback.showSuccess(
        context: context,
        title: 'Sauvegarde créée',
        message: 'Le fichier a été enregistré sur cet appareil.',
      );
    } on Failure catch (e) {
      if (!context.mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Sauvegarde impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!context.mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Sauvegarde impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final confirmed = await SettingsFeedback.confirm(
      context: context,
      title: 'Restaurer une sauvegarde ?',
      message:
          'Les données actuelles de cette boutique seront remplacées. '
          'Cette action est irréversible.',
      confirmLabel: 'Continuer',
      isDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    final picked = await sl<AppLockController>().runWithLockSuppressed(
      () => FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['venteapp'],
        withData: true,
      ),
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;
    final bytes = picked.files.first.bytes;
    if (bytes == null || bytes.isEmpty) {
      SettingsFeedback.showErrorMessage(
        context,
        'Impossible de lire le fichier sélectionné.',
      );
      return;
    }

    final passphrase = await _askPassphrase(
      context,
      title: 'Phrase secrète de la sauvegarde',
      confirmLabel: 'Restaurer',
    );
    if (passphrase == null || !context.mounted) return;

    try {
      await ActionFeedback.runWithBlockingLoader(
        context: context,
        message: 'Restauration en cours…',
        action: () => sl<RestoreShopBackup>()(
          shopId: widget.session.shop.id,
          bytes: bytes,
          passphrase: passphrase,
        ),
      );
      if (!context.mounted) return;
      await SettingsFeedback.showSuccess(
        context: context,
        title: 'Restauration terminée',
        message: 'Les données de la boutique ont été restaurées.',
      );
      if (context.mounted) {
        context.read<SettingsBloc>().add(const SettingsLoadRequested());
      }
    } on Failure catch (e) {
      if (!context.mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Restauration impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!context.mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Restauration impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  Future<void> _exportJson(BuildContext context, String shopName) async {
    try {
      final export = await ActionFeedback.runWithBlockingLoader(
        context: context,
        message: 'Export JSON en cours…',
        action: () => sl<ExportShopJson>()(
          shopId: widget.session.shop.id,
          shopName: shopName,
        ),
      );
      if (export == null || !context.mounted) return;

      await BackupFileSharer.shareBytes(
        bytes: utf8.encode(export.json),
        filename: export.filename,
        mimeType: 'application/json',
        subject: 'Export JSON — $shopName',
      );
      if (!context.mounted) return;
      await SettingsFeedback.showSuccess(
        context: context,
        title: 'Export terminé',
        message: 'Le fichier JSON est prêt à être partagé.',
      );
    } on Failure catch (e) {
      if (!context.mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Export impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!context.mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Export impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  String _formatBackupStatus(BackupSettings backup) {
    if (backup.lastAt == null) {
      return 'Aucune sauvegarde enregistrée.';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(backup.lastAt!);
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
    if (backup.path != null && backup.path!.isNotEmpty) {
      return 'Dernière sauvegarde : $formatted\n${backup.path}';
    }
    return 'Dernière sauvegarde : $formatted';
  }

  String _formatSyncDate(int? lastAt) {
    if (lastAt == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(lastAt);
    return ' — dernière sync '
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _BiometricTile extends StatelessWidget {
  const _BiometricTile({
    required this.enabled,
    required this.canEnable,
    this.onEnable,
    this.onDisable,
  });

  final bool enabled;
  final bool canEnable;
  final VoidCallback? onEnable;
  final VoidCallback? onDisable;

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.fingerprint),
            title: Text('Biométrie'),
            subtitle: Text('Déverrouillage par empreinte activé'),
          ),
          OutlinedButton.icon(
            onPressed: onDisable,
            icon: const Icon(Icons.block_outlined),
            label: const Text('Désactiver la biométrie'),
          ),
        ],
      );
    }
    if (!canEnable) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.fingerprint),
        title: Text('Biométrie'),
        subtitle: Text('Non disponible pour votre rôle'),
      );
    }
    return OutlinedButton.icon(
      onPressed: onEnable,
      icon: const Icon(Icons.fingerprint),
      label: const Text('Activer la biométrie'),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value),
          if (hint != null)
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _PinConfirmSheet extends StatefulWidget {
  const _PinConfirmSheet({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;

  @override
  State<_PinConfirmSheet> createState() => _PinConfirmSheetState();
}

class _PinConfirmSheetState extends State<_PinConfirmSheet> {
  static const _minPinLength = 4;
  static const _maxPinLength = 6;

  String _buffer = '';

  void _onDigit(String digit) {
    if (_buffer.length >= _maxPinLength) return;
    setState(() => _buffer += digit);
    if (_buffer.length == _maxPinLength) {
      Navigator.pop(context, _buffer);
    }
  }

  void _onBackspace() {
    if (_buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  void _confirm() {
    if (_buffer.length < _minPinLength) return;
    Navigator.pop(context, _buffer);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          PinPad(
            filledCount: _buffer.length,
            maxLength: _maxPinLength,
            onDigit: _onDigit,
            onBackspace: _onBackspace,
          ),
          if (_buffer.length >= _minPinLength &&
              _buffer.length < _maxPinLength) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _confirm,
              child: Text(widget.confirmLabel),
            ),
          ],
        ],
      ),
    );
  }
}
