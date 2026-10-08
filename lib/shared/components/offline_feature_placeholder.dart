import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// Un composant d'état hors-ligne chaleureux, clair et ergonomique.
/// Utilisé pour les fonctionnalités administratives ou cloud qui nécessitent
/// une connexion Internet, tout en rassurant le commerçant sur la continuité
/// des fonctions caisse/stock hors ligne.
class OfflineFeaturePlaceholder extends StatelessWidget {
  const OfflineFeaturePlaceholder({
    super.key,
    required this.featureName,
    this.customMessage,
    this.onRetry,
    this.isRetrying = false,
    this.showBackToHome = true,
  });

  /// Nom de la fonctionnalité (ex: 'Gestion de l\'équipe', 'Abonnement', 'Rôles & droits')
  final String featureName;

  /// Message personnalisé additionnel
  final String? customMessage;

  /// Action de réessai (rechargement)
  final Future<void> Function()? onRetry;

  /// Indique si une vérification de connexion est en cours
  final bool isRetrying;

  /// Afficher ou non le bouton de retour rapide à la caisse / accueil
  final bool showBackToHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Icône illustrée avec dégradé doux
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 44,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. Titre explicite
              Text(
                'Connexion requise pour\n$featureName',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              // 3. Explication bienveillante
              Text(
                customMessage ??
                    'Cette section nécessite un accès direct aux serveurs sécurisés '
                        'ARIKE pour garantir l\'intégrité des droits et de la synchronisation.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  height: AppSizes.lineHeightBody,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Carte d'information rassurante pour le commerçant
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Vos encaissements, ventes en boutique, gestion de stock et '
                        'tickets de caisse restent 100 % opérationnels hors ligne.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 5. Actions principales
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  if (onRetry != null)
                    FilledButton.icon(
                      onPressed: isRetrying ? null : () => onRetry!(),
                      icon: isRetrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        isRetrying ? 'Vérification…' : 'Vérifier la connexion',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                      ),
                    ),
                  if (showBackToHome)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Retour'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
