import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import 'feature_ui.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  final Widget child;
  final List<Color>? colors;
  final Alignment begin;
  final Alignment end;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: colors ??
              const [
                AppColors.lockGradientTop,
                AppColors.lockGradientBottom,
              ],
        ),
      ),
      child: child,
    );
  }
}

/// Logo ARIKE (monogramme AK).
///
/// - Variante par défaut : logo charbon sur fond clair.
/// - [AppLogo.onDark] : logo crème (fond sombre / splash).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96}) : _onDark = false;

  /// Variante pour fond sombre/dégradé (identique au splash).
  const AppLogo.onDark({super.key, this.size = 108}) : _onDark = true;

  final double size;
  final bool _onDark;

  static const _darkAsset = 'assets/images/arike_logo_dark.png';
  static const _lightAsset = 'assets/images/arike_logo_light.png';

  @override
  Widget build(BuildContext context) {
    final asset = _onDark ? _lightAsset : _darkAsset;

    if (_onDark) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceCard,
        border: Border.all(
          color: AppColors.seed.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.seed.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null) ...[
          FeatureIllustrationIcon(
            icon: icon!,
            color: iconColor,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShopAvatar extends StatelessWidget {
  const ShopAvatar({
    super.key,
    required this.label,
    this.radius = 40,
  });

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial =
        label.isNotEmpty ? label.characters.first.toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surface,
        child: Text(
          initial,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
