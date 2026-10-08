import 'package:flutter/material.dart';

import '../pages/subscription_page.dart';

class TrialExplorationModal extends StatelessWidget {
  const TrialExplorationModal({
    super.key,
    this.trialDaysRemaining = 14,
  });

  final int trialDaysRemaining;

  static Future<void> show(BuildContext context, {int trialDaysRemaining = 14}) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => TrialExplorationModal(trialDaysRemaining: trialDaysRemaining),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 680;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 14,
        vertical: isDesktop ? 32 : 18,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge d'en-tête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Essai Gratuit : $trialDaysRemaining jours restants',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
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
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                '🎉 Bienvenue sur ARIKE !',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre entreprise est actuellement en période d\'essai. Vous bénéficiez d\'un accès complet aux fonctionnalités de la plateforme.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // Liste des modules débloqués pendant l'essai
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MODULES À VOTRE DISPOSITION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildModuleTile(context, Icons.point_of_sale, 'Caisse & Encaissement Rapide', 'Ventes, tickets et paiements multi-modes'),
                    _buildModuleTile(context, Icons.inventory_2, 'Gestion de Stock & Alertes', 'Suivi du stock en temps réel et alertes de rupture'),
                    _buildModuleTile(context, Icons.receipt_long, 'Gestion des Dettes & Clients', 'Fichier clients, échéances et relances WhatsApp'),
                    _buildModuleTile(context, Icons.mic, 'Assistant Vocal Intelligent', 'Dictée vocale des ventes et des articles'),
                    _buildModuleTile(context, Icons.wifi_off, 'Mode 100% Offline', 'Continuez à vendre sans connexion internet'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Exploration des Tarifs
              Text(
                'Nos Formules d\'Abonnement',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Column(
                children: [
                  _buildPlanChip(context, 'ESSENTIEL', '30 000 FCFA/an', '1 Boutique • 3 Utilisateurs'),
                  const SizedBox(height: 8),
                  _buildPlanChip(context, 'PRO ⭐', '60 000 FCFA/an', '2 Boutiques • 10 Utilisateurs'),
                  const SizedBox(height: 8),
                  _buildPlanChip(context, 'BUSINESS 🚀', '100 000 FCFA/an', '5 Boutiques • 30 Utilisateurs'),
                ],
              ),
              const SizedBox(height: 24),

              // Boutons d'action
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                  );
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text(
                  'Prendre une offre ARIKE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Découvrir ARIKE maintenant'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleTile(BuildContext context, IconData icon, String title, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanChip(BuildContext context, String planName, String price, String details) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SubscriptionPage()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(details, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  price,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
