import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/utils/phone_util.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../subscription/data/services/subscription_remote_service.dart';
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
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  int _currentStep = 0; // 0: Entreprise & Boutique, 1: Sécurité, 2: Forfait
  String _selectedPlanCode = 'ESSENTIEL';
  bool _trialEnabled = true;
  int _trialDurationDays = 14;

  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _loadOnboardingPolicy();
  }

  Future<void> _loadOnboardingPolicy() async {
    try {
      final policy = await sl<SubscriptionRemoteService>().fetchOnboardingPolicy();
      if (mounted) {
        setState(() {
          _trialEnabled = policy['trialEnabled'] as bool? ?? true;
          _trialDurationDays = (policy['trialDurationDays'] as num?)?.toInt() ?? 14;
          if (policy['defaultPlanCode'] != null) {
            _selectedPlanCode = policy['defaultPlanCode'].toString();
          }
        });
      }
    } catch (_) {}
  }

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

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_formKeyStep2.currentState!.validate()) return;
      setState(() => _currentStep = 2);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else if (widget.onBack != null) {
      widget.onBack!();
    }
  }

  void _submit() {
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
            planCode: _selectedPlanCode,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthSetupFailure || current is AuthSetupInProgress,
      listener: (context, state) {
        if (state is AuthSetupInProgress) {
          setState(() => _fieldErrors = {});
        }
        if (state is AuthSetupFailure) {
          setState(() => _fieldErrors = state.fieldErrors);
          // Si l'erreur concerne le profil ou la boutique, retourner à l'étape 0
          if (state.fieldErrors.containsKey(SetupField.ownerName.code) ||
              state.fieldErrors.containsKey(SetupField.ownerPhone.code) ||
              state.fieldErrors.containsKey(SetupField.shopName.code)) {
            setState(() => _currentStep = 0);
          }
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthSetupInProgress;
          final summary = state is AuthSetupFailure ? state.message : null;

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: ResponsivePage(
                  maxWidth: Breakpoints.formMaxWidth,
                  padding: EdgeInsets.zero,
                  expandHeight: true,
                  child: Column(
                    children: [
                      // Header Navigation Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: isLoading ? null : _previousStep,
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const Spacer(),
                            // Stepper Indicator
                            Row(
                              children: List.generate(3, (index) {
                                final active = index <= _currentStep;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: index == _currentStep ? 24 : 10,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                            const Spacer(),
                            Text(
                              'Étape ${_currentStep + 1}/3',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      // Header Title & Subtitle
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xs,
                          AppSpacing.lg,
                          0,
                        ),
                        child: PageHeader(
                          icon: _currentStep == 0
                              ? Icons.storefront_outlined
                              : (_currentStep == 1
                                  ? Icons.lock_outline
                                  : Icons.stars_outlined),
                          title: _currentStep == 0
                              ? 'Création de votre Commerce'
                              : (_currentStep == 1
                                  ? 'Sécurité du Patron'
                                  : 'Choix de votre Forfait ARIKE'),
                          subtitle: _currentStep == 0
                              ? 'Identifiez votre entreprise et votre boutique principale.'
                              : (_currentStep == 1
                                  ? 'Définissez votre code PIN sécurisé pour déverrouiller la caisse.'
                                  : 'Sélectionnez votre offre. Vos 14 premiers jours sont 100% gratuits !'),
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ÉTAPE 0 : Profil & Boutique
                              if (_currentStep == 0) ...[
                                Form(
                                  key: _formKeyStep1,
                                  child: Column(
                                    children: [
                                      _FormSection(
                                        title: 'Profil du Patron',
                                        children: [
                                          TextFormField(
                                            controller: _ownerNameController,
                                            decoration: InputDecoration(
                                              labelText: 'Nom & Prénom du patron',
                                              prefixIcon: const Icon(Icons.person_outline),
                                              errorText: _fieldError(SetupField.ownerName.code),
                                            ),
                                            textInputAction: TextInputAction.next,
                                            onChanged: (_) => _clearFieldError(SetupField.ownerName.code),
                                            validator: (value) {
                                              if (value == null || value.trim().length < 2) {
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
                                              prefixIcon: const Icon(Icons.chat_outlined),
                                              errorText: _fieldError(SetupField.ownerPhone.code),
                                            ),
                                            keyboardType: TextInputType.phone,
                                            textInputAction: TextInputAction.next,
                                            onChanged: (_) => _clearFieldError(SetupField.ownerPhone.code),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
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
                                        title: 'Boutique Principale',
                                        children: [
                                          TextFormField(
                                            controller: _shopNameController,
                                            decoration: InputDecoration(
                                              labelText: 'Nom de la boutique',
                                              prefixIcon: const Icon(Icons.store_outlined),
                                              errorText: _fieldError(SetupField.shopName.code),
                                            ),
                                            textInputAction: TextInputAction.next,
                                            onChanged: (_) => _clearFieldError(SetupField.shopName.code),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Le nom de la boutique est requis.';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          TextFormField(
                                            controller: _shopAddressController,
                                            decoration: const InputDecoration(
                                              labelText: 'Adresse / Ville (optionnel)',
                                              prefixIcon: Icon(Icons.location_on_outlined),
                                            ),
                                            textInputAction: TextInputAction.next,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          TextFormField(
                                            controller: _shopPhoneController,
                                            decoration: InputDecoration(
                                              labelText: 'Téléphone boutique (optionnel)',
                                              prefixIcon: const Icon(Icons.phone_outlined),
                                              errorText: _fieldError(SetupField.shopPhone.code),
                                            ),
                                            keyboardType: TextInputType.phone,
                                            textInputAction: TextInputAction.next,
                                            onChanged: (_) => _clearFieldError(SetupField.shopPhone.code),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      FilledButton.icon(
                                        onPressed: _nextStep,
                                        icon: const Icon(Icons.arrow_forward),
                                        label: const Text('Continuer vers la sécurité'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ÉTAPE 1 : Sécurité PIN
                              if (_currentStep == 1) ...[
                                Form(
                                  key: _formKeyStep2,
                                  child: Column(
                                    children: [
                                      _FormSection(
                                        title: 'Sécurité & Code PIN',
                                        children: [
                                          TextFormField(
                                            controller: _pinController,
                                            decoration: const InputDecoration(
                                              labelText: 'Code PIN Patron (4 à 6 chiffres)',
                                              prefixIcon: Icon(Icons.lock_outline),
                                            ),
                                            keyboardType: TextInputType.number,
                                            obscureText: true,
                                            textInputAction: TextInputAction.next,
                                            validator: (value) {
                                              final pin = value?.trim() ?? '';
                                              if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
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
                                              prefixIcon: Icon(Icons.verified_user_outlined),
                                            ),
                                            keyboardType: TextInputType.number,
                                            obscureText: true,
                                            validator: (value) {
                                              if (value?.trim() != _pinController.text.trim()) {
                                                return 'Les codes PIN ne correspondent pas.';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: _previousStep,
                                              child: const Text('Retour'),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            flex: 2,
                                            child: FilledButton.icon(
                                              onPressed: _nextStep,
                                              icon: const Icon(Icons.arrow_forward, size: 18),
                                              label: const Text(
                                                'Choisir forfait',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ÉTAPE 2 : Choix Obligatoire du Forfait SaaS
                              if (_currentStep == 2) ...[
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: _trialEnabled ? Colors.green.shade50 : Colors.amber.shade50,
                                    border: Border.all(
                                      color: _trialEnabled ? Colors.green.shade300 : Colors.amber.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _trialEnabled ? Icons.card_giftcard : Icons.lock_clock_outlined,
                                        color: _trialEnabled ? Colors.green.shade800 : Colors.amber.shade900,
                                        size: 28,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          _trialEnabled
                                              ? '🎁 Essai gratuit de $_trialDurationDays jours activé immédiatement sur le forfait sélectionné. Aucun paiement maintenant !'
                                              : '⚡ Paiement obligatoire à l\'inscription. La validation de votre forfait débloquera immédiatement votre licence d\'utilisation.',
                                          style: TextStyle(
                                            color: _trialEnabled ? Colors.green.shade900 : Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Card 1: ARIKE Essentiel
                                _PlanSelectionCard(
                                  code: 'ESSENTIEL',
                                  name: 'ARIKE Essentiel',
                                  priceText: '3 000 FCFA / mois',
                                  subtitle: 'Petit commerce · 1 boutique · 3 utilisateurs',
                                  features: const [
                                    'Ventes & Caisse enregistreuse',
                                    'Gestion du stock & Alertes rupture',
                                    'Fichier clients & Suivi des dettes',
                                    'Dépenses & Charges de caisse',
                                    'Fonctionne 100% Hors-Ligne',
                                  ],
                                  isSelected: _selectedPlanCode == 'ESSENTIEL',
                                  isDefault: true,
                                  onSelect: () => setState(() => _selectedPlanCode = 'ESSENTIEL'),
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Card 2: ARIKE Pro
                                _PlanSelectionCard(
                                  code: 'PRO',
                                  name: '⭐ ARIKE Pro',
                                  priceText: '6 000 FCFA / mois',
                                  subtitle: 'Boutique en croissance · 2 boutiques · 10 utilisateurs',
                                  features: const [
                                    'Tout le forfait Essentiel',
                                    'Bureau de Change FX (Devises)',
                                    'Assistant Vocal ARIKE',
                                    'Transferts de stock inter-boutiques',
                                    'Commandes & Approvisionnements',
                                  ],
                                  isSelected: _selectedPlanCode == 'PRO',
                                  onSelect: () => setState(() => _selectedPlanCode = 'PRO'),
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Card 3: ARIKE Business
                                _PlanSelectionCard(
                                  code: 'BUSINESS',
                                  name: 'ARIKE Business',
                                  priceText: '10 000 FCFA / mois',
                                  subtitle: 'Réseau & Grossiste · 5 boutiques · 30 utilisateurs',
                                  features: const [
                                    'Tout le forfait Pro',
                                    'Multi-entreprises & Distributeurs',
                                    'Accès API dédiée & Export complet',
                                    'Support prioritaire 24/7 & Configuration',
                                  ],
                                  isSelected: _selectedPlanCode == 'BUSINESS',
                                  onSelect: () => setState(() => _selectedPlanCode = 'BUSINESS'),
                                ),

                                if (summary != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  ErrorBanner(message: summary),
                                ],
                                const SizedBox(height: AppSpacing.lg),

                                FilledButton.icon(
                                  onPressed: isLoading ? null : _submit,
                                  icon: isLoading
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _trialEnabled ? Icons.rocket_launch : Icons.payment,
                                          size: 18,
                                        ),
                                  label: Text(
                                    isLoading
                                        ? 'Activation...'
                                        : (_trialEnabled
                                            ? 'Essai gratuit ${_trialDurationDays}j — $_selectedPlanCode'
                                            : 'Valider et payer — $_selectedPlanCode'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
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

class _PlanSelectionCard extends StatelessWidget {
  const _PlanSelectionCard({
    required this.code,
    required this.name,
    required this.priceText,
    required this.subtitle,
    required this.features,
    required this.isSelected,
    this.isDefault = false,
    required this.onSelect,
  });

  final String code;
  final String name;
  final String priceText;
  final String subtitle;
  final List<String> features;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primaryContainer.withValues(alpha: 0.4) : Colors.white,
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<String>(
                  value: code,
                  groupValue: isSelected ? code : '',
                  onChanged: (_) => onSelect(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? scheme.primary : null,
                                ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: const Text(
                                'Recommandé',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  priceText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: features
                  .map((f) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 14, color: scheme.primary),
                          const SizedBox(width: 4),
                          Text(f, style: const TextStyle(fontSize: 11)),
                        ],
                      ))
                  .toList(),
            ),
          ],
        ),
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
