import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/components/app_page_container.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../../domain/entities/settings_entities.dart';
import '../../bloc/settings_bloc.dart';
import '../../widgets/settings_confirmation.dart';

class ReceiptsPrinterSettingsPage extends StatefulWidget {
  const ReceiptsPrinterSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<ReceiptsPrinterSettingsPage> createState() => _ReceiptsPrinterSettingsPageState();
}

class _ReceiptsPrinterSettingsPageState extends State<ReceiptsPrinterSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _footerController;
  String _paperFormat = '58mm'; // 58mm, 80mm, A4
  bool _showQrCode = true;
  bool _showSellerName = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _footerController = TextEditingController();
  }

  void _hydrate(ShopConfiguration config) {
    if (_initialized) return;
    _footerController.text = config.receipts.footer ?? '';
    _paperFormat = config.commerce.paperFormat;
    _showSellerName = config.commerce.showSellerName;
    _showQrCode = config.commerce.showQrCode;
    _initialized = true;
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reçus & Impression'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          if (config == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _hydrate(config);

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
                      Icon(Icons.receipt_long_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personnalisation des tickets',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Format d\'impression (ESC/POS 58mm, 80mm ou A4), message de bas de reçu et QR Code.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Format ticket
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Format d\'impression du ticket', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: '58mm', label: Text('58 mm (Thermique)')),
                            ButtonSegment(value: '80mm', label: Text('80 mm (Grand)')),
                            ButtonSegment(value: 'A4', label: Text('Format A4')),
                          ],
                          selected: {_paperFormat},
                          onSelectionChanged: widget.canWrite
                              ? (set) async {
                                  final newFormat = set.first;
                                  final ok = await SettingsConfirmation.confirm(
                                    context,
                                    title: 'Format d\'impression',
                                    message: 'Changer le format d\'impression du ticket vers $newFormat ?',
                                    confirmLabel: 'Modifier',
                                  );
                                  if (ok && mounted) {
                                    setState(() => _paperFormat = newFormat);
                                    context.read<SettingsBloc>().add(
                                          SettingsOptionUpdated(
                                            input: UpdateShopSettingsInput(paperFormat: newFormat),
                                            successMessage: 'Format du ticket mis à jour : $newFormat.',
                                          ),
                                        );
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Content customization
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Informations affichées', style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.sm),
                          SettingsSwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Afficher le nom du vendeur'),
                            value: _showSellerName,
                            confirmationTitle: 'Nom du vendeur',
                            confirmationMessage: _showSellerName
                                ? 'Masquer le nom du vendeur sur le ticket de caisse ?'
                                : 'Afficher le nom du vendeur sur le ticket de caisse ?',
                            onChanged: widget.canWrite
                                ? (v) {
                                    context.read<SettingsBloc>().add(
                                          SettingsOptionUpdated(
                                            input: UpdateShopSettingsInput(showSellerName: v),
                                            successMessage: v
                                                ? 'Nom du vendeur affiché sur le reçu.'
                                                : 'Nom du vendeur masqué.',
                                          ),
                                        );
                                  }
                                : null,
                          ),
                          SettingsSwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Afficher le QR Code de vérification'),
                            subtitle: const Text('Permet de scanner le ticket pour authenticité'),
                            value: _showQrCode,
                            confirmationTitle: 'QR Code sur le reçu',
                            confirmationMessage: _showQrCode
                                ? 'Désactiver le QR Code d\'authenticité sur le ticket ?'
                                : 'Activer l\'impression du QR Code d\'authenticité sur le ticket ?',
                            onChanged: widget.canWrite
                                ? (v) {
                                    context.read<SettingsBloc>().add(
                                          SettingsOptionUpdated(
                                            input: UpdateShopSettingsInput(showQrCode: v),
                                            successMessage: v
                                                ? 'QR Code activé sur le ticket.'
                                                : 'QR Code désactivé sur le ticket.',
                                          ),
                                        );
                                  }
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _footerController,
                            enabled: widget.canWrite,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Message de bas de reçu',
                              hintText: 'Ex: Merci pour votre confiance ! À bientôt chez ARIKE.',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (widget.canWrite)
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: state.isSaving
                                    ? null
                                    : () async {
                                        final ok = await SettingsConfirmation.confirm(
                                          context,
                                          title: 'Enregistrer le modèle de reçu',
                                          message: 'Confirmer la mise à jour du message de bas de reçu ?',
                                          confirmLabel: 'Enregistrer',
                                        );
                                        if (!ok || !context.mounted) return;
                                        context.read<SettingsBloc>().add(
                                              SettingsReceiptSaveRequested(
                                                _footerController.text.trim(),
                                              ),
                                            );
                                      },
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Enregistrer le reçu'),
                              ),
                            ),
                        ],
                      ),
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
