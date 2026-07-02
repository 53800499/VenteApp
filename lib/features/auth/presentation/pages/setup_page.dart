import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/utils/phone_util.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../domain/entities/setup_field.dart';
import '../bloc/auth_bloc.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _clearFieldError(String fieldCode) {
    if (!_fieldErrors.containsKey(fieldCode)) return;
    setState(() => _fieldErrors.remove(fieldCode));
  }

  String? _fieldError(String fieldCode) => _fieldErrors[fieldCode];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
          AuthSetupRequested(
            ownerName: _ownerNameController.text.trim(),
            shopName: _shopNameController.text.trim(),
            pin: _pinController.text.trim(),
            ownerPhone: _ownerPhoneController.text.trim(),
            shopAddress: _shopAddressController.text.trim().isEmpty
                ? null
                : _shopAddressController.text.trim(),
            shopPhone: _shopPhoneController.text.trim().isEmpty
                ? null
                : _shopPhoneController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthSetupFailure || current is AuthSetupInProgress,
      listener: (context, state) {
        if (state is AuthSetupInProgress) {
          setState(() => _fieldErrors = {});
        }
        if (state is AuthSetupFailure) {
          setState(() => _fieldErrors = state.fieldErrors);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthSetupInProgress;
          final summary =
              state is AuthSetupFailure ? state.message : null;

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: ResponsivePage(
                  maxWidth: Breakpoints.formMaxWidth,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (widget.onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: isLoading ? null : widget.onBack,
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          0,
                        ),
                        child: const PageHeader(
                          icon: Icons.storefront_outlined,
                          title: 'Bienvenue sur VenteApp',
                          subtitle:
                              'Connexion internet requise. Configurez votre boutique en quelques étapes pour commencer à vendre.',
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FormSection(
                                  title: 'Votre profil',
                                  children: [
                                    TextFormField(
                                      controller: _ownerNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Nom du patron',
                                        prefixIcon:
                                            const Icon(Icons.person_outline),
                                        errorText: _fieldError(
                                          SetupField.ownerName.code,
                                        ),
                                      ),
                                      textInputAction: TextInputAction.next,
                                      onChanged: (_) => _clearFieldError(
                                        SetupField.ownerName.code,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().length < 2) {
                                          return 'Le nom doit comporter au moins 2 caractères.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                      controller: _ownerPhoneController,
                                      decoration: InputDecoration(
                                        labelText: 'WhatsApp du patron',
                                        hintText: '+229 01 97 00 00 00',
                                        prefixIcon:
                                            const Icon(Icons.chat_outlined),
                                        errorText: _fieldError(
                                          SetupField.ownerPhone.code,
                                        ),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (_) => _clearFieldError(
                                        SetupField.ownerPhone.code,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Le numéro WhatsApp est requis.';
                                        }
                                        if (!isValidPhone(value)) {
                                          return 'Numéro invalide (indicatif pays requis, ex. +229…).';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _FormSection(
                                  title: 'Votre boutique',
                                  children: [
                                    TextFormField(
                                      controller: _shopNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Nom de la boutique',
                                        prefixIcon:
                                            const Icon(Icons.store_outlined),
                                        errorText: _fieldError(
                                          SetupField.shopName.code,
                                        ),
                                      ),
                                      textInputAction: TextInputAction.next,
                                      onChanged: (_) => _clearFieldError(
                                        SetupField.shopName.code,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Le nom de la boutique est requis.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                      controller: _shopAddressController,
                                      decoration: const InputDecoration(
                                        labelText: 'Adresse (optionnel)',
                                        prefixIcon:
                                            Icon(Icons.location_on_outlined),
                                      ),
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                      controller: _shopPhoneController,
                                      decoration: InputDecoration(
                                        labelText: 'Téléphone (optionnel)',
                                        prefixIcon:
                                            const Icon(Icons.phone_outlined),
                                        errorText: _fieldError(
                                          SetupField.shopPhone.code,
                                        ),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (_) => _clearFieldError(
                                        SetupField.shopPhone.code,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _FormSection(
                                  title: 'Sécurité',
                                  children: [
                                    TextFormField(
                                      controller: _pinController,
                                      decoration: const InputDecoration(
                                        labelText: 'Code PIN (4 à 6 chiffres)',
                                        prefixIcon: Icon(Icons.lock_outline),
                                      ),
                                      keyboardType: TextInputType.number,
                                      obscureText: true,
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        final pin = value?.trim() ?? '';
                                        if (!RegExp(r'^\d{4,6}$')
                                            .hasMatch(pin)) {
                                          return 'Le PIN doit comporter entre 4 et 6 chiffres.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                      controller: _confirmPinController,
                                      decoration: const InputDecoration(
                                        labelText: 'Confirmer le PIN',
                                        prefixIcon: Icon(
                                          Icons.verified_user_outlined,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      obscureText: true,
                                      validator: (value) {
                                        if (value?.trim() !=
                                            _pinController.text.trim()) {
                                          return 'Les codes PIN ne correspondent pas.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                if (summary != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  ErrorBanner(message: summary),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                FilledButton(
                                  onPressed: isLoading ? null : _submit,
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Terminer l\'installation'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.seed,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}
