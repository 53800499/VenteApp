import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/sync/widgets/sync_status_indicator.dart';
import '../../../../shared/widgets/header_lock_button.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../models/sidebar_destination.dart';

/// En-tête desktop avec fil d'Ariane (Breadcrumb) dynamique et persistant.
///
/// Permet à l'utilisateur de visualiser précisément son emplacement dans
/// l'arborescence des modules, de revenir facilement à l'accueil et de conserver
/// l'accès permanent aux fonctionnalités de statut de synchro et de verrouillage.
class DesktopBreadcrumbHeader extends StatelessWidget {
  const DesktopBreadcrumbHeader({
    super.key,
    required this.session,
    required this.activeDestination,
    required this.onNavigateHome,
    required this.onLock,
    this.helpArticleId,
    this.useFxPrimary = false,
  });

  final AuthSession session;
  final SidebarDestination activeDestination;
  final VoidCallback onNavigateHome;
  final VoidCallback onLock;
  final String? helpArticleId;
  final bool useFxPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isHome = activeDestination == SidebarDestination.dashboard;

    return Container(
      width: double.infinity,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Bouton flèche retour si on est dans une sous-page
          if (!isHome) ...[
            Tooltip(
              message: 'Retour au tableau de bord',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onNavigateHome,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],

          // Fil d'Ariane (Breadcrumb)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Racine : Accueil / Bureau de Change
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isHome ? null : onNavigateHome,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              useFxPrimary
                                  ? Icons.currency_exchange
                                  : Icons.home_rounded,
                              size: 18,
                              color: isHome
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              useFxPrimary ? 'Bureau de Change' : 'Accueil',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight:
                                    isHome ? FontWeight.w700 : FontWeight.w500,
                                color: isHome
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Séparateur et section parente
                  if (!isHome) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: colorScheme.outline.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      activeDestination.sectionLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: colorScheme.outline.withValues(alpha: 0.6),
                      ),
                    ),

                    // 3. Page active (badge pill surélevé)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            activeDestination.icon(useFxPrimary: useFxPrimary),
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            activeDestination.label(useFxPrimary: useFxPrimary),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Utilitaires de droite
          if (helpArticleId != null) ...[
            ModuleHelpButton(articleId: helpArticleId!),
            const SizedBox(width: AppSpacing.xs),
          ],
          HeaderLockButton(
            onLock: onLock,
            filledTonal: true,
          ),
          const SizedBox(width: AppSpacing.xs),
          SyncStatusIndicator(session: session),
        ],
      ),
    );
  }
}
