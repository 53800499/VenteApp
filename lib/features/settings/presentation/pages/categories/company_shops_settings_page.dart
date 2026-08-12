import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../../../shop/presentation/pages/shop_list_page.dart';
import '../../../domain/entities/settings_entities.dart';
import '../../bloc/settings_bloc.dart';

class CompanyShopsSettingsPage extends StatefulWidget {
  const CompanyShopsSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<CompanyShopsSettingsPage> createState() => _CompanyShopsSettingsPageState();
}

class _CompanyShopsSettingsPageState extends State<CompanyShopsSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  void _hydrate(ShopConfiguration config) {
    if (_initialized) return;
    _nameController.text = config.shop.name;
    _phoneController.text = config.shop.phone ?? '';
    _addressController.text = config.shop.address ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entreprise & Boutiques'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          if (config == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _hydrate(config);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
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
                      Icon(Icons.business_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Identité & Réseau',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Configuration du profil de l\'entreprise et gestion du réseau de boutiques.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Form section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profil de l\'entreprise', style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _nameController,
                            enabled: widget.canWrite,
                            decoration: const InputDecoration(
                              labelText: 'Nom de l\'entreprise / boutique',
                              prefixIcon: Icon(Icons.store_outlined),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _phoneController,
                            enabled: widget.canWrite,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Téléphone (Reçus & Contact)',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _addressController,
                            enabled: widget.canWrite,
                            decoration: const InputDecoration(
                              labelText: 'Adresse physique',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.monetization_on_outlined),
                            title: Text('Devise principale'),
                            subtitle: Text('FCFA (XOF) — Franc CFA UEMOA'),
                            trailing: Chip(label: Text('Défaut')),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (widget.canWrite)
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: state.isSaving
                                    ? null
                                    : () {
                                        if (_formKey.currentState?.validate() ?? false) {
                                          context.read<SettingsBloc>().add(
                                                SettingsShopSaveRequested(
                                                  name: _nameController.text.trim(),
                                                  phone: _phoneController.text.trim(),
                                                  address: _addressController.text.trim(),
                                                ),
                                              );
                                        }
                                      },
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Enregistrer les modifications'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Multi-boutiques action card
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(Icons.storefront, color: theme.colorScheme.onSecondaryContainer),
                    ),
                    title: const Text('Gestion des boutiques du réseau'),
                    subtitle: Text(
                      'Boutique actuelle: ${widget.session.shop.name}\n'
                      'Ajouter, modifier ou basculer de boutique.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShopListPage(session: widget.session),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
