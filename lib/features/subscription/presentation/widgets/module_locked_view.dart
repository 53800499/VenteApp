import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/utils/module_labels.dart';
import '../../domain/services/subscription_controller.dart';
import '../pages/subscription_page.dart';

/// Vue affichée dans le panneau de contenu principal lorsqu'un module
/// est inaccessible avec le forfait d'abonnement actuel de l'utilisateur.
class ModuleLockedView extends StatelessWidget {
  const ModuleLockedView({
    super.key,
    required this.moduleName,
    required this.requiredPlanName,
    required this.currentPlanName,
    this.description,
    this.icon,
  });

  final String moduleName;
  final String requiredPlanName;
  final String currentPlanName;
  final String? description;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final friendlyModuleName = formatModuleName(moduleName);
    final friendlyRequiredPlan = formatPlanName(requiredPlanName);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icône de verrouillage avec badge dégradé
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.15),
                          colorScheme.secondary.withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon ?? Icons.lock_rounded,
                        size: 34,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Titre du module
                  Text(
                    'Module « $friendlyModuleName »',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Explication
                  Text(
                    description ??
                        'Ce module n\'est pas inclus dans votre forfait actuel ($currentPlanName). '
                        'Passez au forfait $friendlyRequiredPlan ou supérieur pour débloquer immédiatement toutes ses fonctionnalités.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Carte d'information forfait
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Disponible avec le forfait $friendlyRequiredPlan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Bouton d'action
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionPage(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      label: const Text(
                        'Voir les offres et forfaits',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Bouton de vérification instantanée si débloqué depuis le back-office
                  TextButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      messenger?.showSnackBar(
                        const SnackBar(
                          content: Text('Vérification des droits d\'accès en cours...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      try {
                        ensureSubscriptionDependencies();
                        await sl<SubscriptionController>().refreshFromRemote();
                        messenger?.hideCurrentSnackBar();
                        messenger?.showSnackBar(
                          const SnackBar(
                            content: Text('Droits d\'accès mis à jour avec succès.'),
                            backgroundColor: Color(0xFF2E7D32),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } catch (_) {
                        messenger?.hideCurrentSnackBar();
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Actualiser mes droits maintenant',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

