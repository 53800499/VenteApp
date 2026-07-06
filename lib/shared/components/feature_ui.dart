import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// Dégradé hero standard de l'application.
List<Color> featureHeroGradient([Color? accent]) => [
      accent ?? AppColors.heroGradientStart,
      accent != null
          ? Color.lerp(accent, Colors.black, 0.25)!
          : AppColors.heroGradientEnd,
    ];

/// Icône avec halo — onboarding, états vides, placeholders.
class FeatureIllustrationIcon extends StatelessWidget {
  const FeatureIllustrationIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = AppSizes.illustration,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = color ?? scheme.primary;
    final outer = size * 1.75;
    final inner = size * 1.25;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: outer,
          height: outer,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: resolved.withValues(alpha: 0.08),
          ),
        ),
        Container(
          width: inner,
          height: inner,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                resolved.withValues(alpha: 0.18),
                resolved.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: resolved.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: size * 0.55, color: resolved),
        ),
      ],
    );
  }
}

/// Avatar rond standard des listes (40 px).
class FeatureLeadingAvatar extends StatelessWidget {
  const FeatureLeadingAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: AppSizes.leadingRadius,
      backgroundColor: backgroundColor ?? color.withValues(alpha: 0.12),
      child: Icon(icon, color: color, size: AppSizes.iconMd),
    );
  }
}

/// Tuile module unifiée — Plus, Aide, Paramètres.
class ModuleActionTile extends StatelessWidget {
  const ModuleActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = destructive
        ? scheme.error
        : (accentColor ?? scheme.primary);
    final leadingBg = destructive
        ? scheme.errorContainer
        : accent.withValues(alpha: 0.12);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.listTileMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                FeatureLeadingAvatar(
                  icon: icon,
                  color: accent,
                  backgroundColor: leadingBg,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: destructive ? scheme.error : null,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceMuted,
                              height: AppSizes.lineHeightTight,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconLg,
                  color: destructive ? scheme.error : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Titre de section avec icône (catégories aide, paramètres).
class FeatureSectionHeader extends StatelessWidget {
  const FeatureSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          FeatureLeadingAvatar(icon: icon, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ de recherche aligné sur les listes Ventes / Stock.
class FeatureSearchField extends StatelessWidget {
  const FeatureSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.showClear = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: showClear && onClear != null
            ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
            : null,
      ),
    );
  }
}

/// Puce filtre horizontale.
class FeatureFilterChip extends StatelessWidget {
  const FeatureFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: accent.withValues(alpha: 0.14),
        side: BorderSide(
          color: selected
              ? accent.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.25),
        ),
        labelStyle: TextStyle(
          color: selected ? accent : scheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Carte de contenu (articles aide, sections).
class FeatureSurfaceCard extends StatelessWidget {
  const FeatureSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Encart astuce unifié.
class FeatureTipBanner extends StatelessWidget {
  const FeatureTipBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.secondary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: AppSizes.iconSm,
            color: scheme.secondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: AppSizes.lineHeightBody,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge catégorie compact.
class FeatureCategoryBadge extends StatelessWidget {
  const FeatureCategoryBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
