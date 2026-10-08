import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/subscription_page.dart';

class _PlanOption {
  final String code;
  final String name;
  final String price;
  final String subtitle;
  final bool isRecommended;

  const _PlanOption({
    required this.code,
    required this.name,
    required this.price,
    required this.subtitle,
    this.isRecommended = false,
  });
}

const _kPlanOptions = [
  _PlanOption(
    code: 'ESSENTIEL',
    name: 'ARIKE Essentiel',
    price: '3 000 FCFA/mois',
    subtitle: '1 boutique · 3 utilisateurs · Sauvegarde Cloud automatique',
    isRecommended: false,
  ),
  _PlanOption(
    code: 'PRO',
    name: 'ARIKE Pro ⭐',
    price: '6 000 FCFA/mois',
    subtitle: '2 boutiques · 10 utilisateurs · Assistant Vocal, FX & Cloud',
    isRecommended: true,
  ),
  _PlanOption(
    code: 'BUSINESS',
    name: 'ARIKE Business',
    price: '10 000 FCFA/mois',
    subtitle: '5 boutiques · 30 utilisateurs · Réseau multi-boutiques & Export',
    isRecommended: false,
  ),
];

/// Modal incitatif et pédagogique affiché pour les utilisateurs en mode local
/// pour sensibiliser à la sauvegarde Cloud et permettre d'activer une formule.
class DataSecurityUpgradeModal extends StatefulWidget {
  const DataSecurityUpgradeModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => const DataSecurityUpgradeModal(),
    );
  }

  @override
  State<DataSecurityUpgradeModal> createState() => _DataSecurityUpgradeModalState();
}

class _DataSecurityUpgradeModalState extends State<DataSecurityUpgradeModal> {
  String _selectedPlanCode = 'PRO';

  _PlanOption get _selectedPlan =>
      _kPlanOptions.firstWhere((p) => p.code == _selectedPlanCode,
          orElse: () => _kPlanOptions[1]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 680;
    final selected = _selectedPlan;

    final dialogContent = Container(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 520 : 440,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: isDesktop ? 22 : 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Badge statut et bouton fermer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.shade700.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 15, color: Colors.amber.shade900),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Mode local · Sauvegarde inactive',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Fermer',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. En-tête : Titre & Icône
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isDesktop ? 48 : 42,
                  height: isDesktop ? 48 : 42,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: isDesktop ? 26 : 22,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sécurisez votre commerce',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 18 : 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Activez la synchronisation Cloud pour protéger vos données',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: isDesktop ? 12 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Avertissement risque de perte
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En cas de perte, casse ou panne de votre téléphone, vos ventes et stocks ne pourront être récupérés sans sauvegarde Cloud.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        fontSize: isDesktop ? 12 : 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Choix de formule
            Text(
              'Sélectionnez une formule pour sécuriser vos données :',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontSize: isDesktop ? 13 : 12,
              ),
            ),
            const SizedBox(height: 8),

            // 5. Cartes de formules
            ..._kPlanOptions.map((plan) {
              final isSelected = plan.code == _selectedPlanCode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPlanCard(
                  context,
                  plan: plan,
                  isSelected: isSelected,
                  isDesktop: isDesktop,
                  onTap: () {
                    setState(() => _selectedPlanCode = plan.code);
                  },
                ),
              );
            }),
            const SizedBox(height: 16),

            // 6. Bouton principal interactif affichant clairement ses données
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SubscriptionPage(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: colorScheme.primary,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_done_rounded, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Sécuriser mes données avec ${selected.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Activer la sauvegarde Cloud (${selected.price})',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 7. Bouton secondaire discret
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Continuer en local sans sauvegarde Cloud',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 14,
          vertical: isDesktop ? 32 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: isDesktop ? 0.6 : 0.4),
          ),
        ),
        elevation: isDesktop ? 16 : 8,
        backgroundColor: colorScheme.surface,
        child: dialogContent,
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required _PlanOption plan,
    required bool isSelected,
    required bool isDesktop,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        plan.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                      ),
                      if (plan.isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Conseillé',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan.price,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                plan.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
