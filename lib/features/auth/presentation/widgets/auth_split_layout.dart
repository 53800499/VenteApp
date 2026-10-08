import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../shared/components/ui_primitives.dart';

/// Point mis en avant dans le volet gauche (desktop).
class AuthHeroPoint {
  const AuthHeroPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// Mise en page adaptative des écrans d'authentification.
///
/// - Mobile / tablette : retourne [child] tel quel (aucune régression).
/// - Desktop : volet gauche bord à bord, pleine hauteur, même dégradé que
///   l'écran PIN ; [child] est placé dans le volet droit, centré.
class AuthSplitLayout extends StatelessWidget {
  const AuthSplitLayout({
    super.key,
    required this.child,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroSubtitle,
    this.points = const [],
    this.contentMaxWidth = 520,
  });

  final Widget child;
  final IconData heroIcon;
  final String heroTitle;
  final String heroSubtitle;
  final List<AuthHeroPoint> points;
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!Breakpoints.isDesktopWidth(constraints.maxWidth)) {
          return child;
        }
        return _buildDesktop(context);
      },
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- VOLET GAUCHE : pleine hauteur, bord à bord ---
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.lockGradientTop,
                  AppColors.lockGradientBottom,
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 64),
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          heroIcon,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        heroTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        heroSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      for (final point in points) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _HeroPointTile(point: point),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // --- VOLET DROIT : contenu de la page ---
        Expanded(
          flex: 6,
          child: ColoredBox(
            color: colorScheme.surface,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPointTile extends StatelessWidget {
  const _HeroPointTile({required this.point});

  final AuthHeroPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(point.icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                point.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
