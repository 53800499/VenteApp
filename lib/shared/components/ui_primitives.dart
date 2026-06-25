import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (icon != null) ...[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  (iconColor ?? colorScheme.primary).withValues(alpha: 0.15),
                  (iconColor ?? colorScheme.primary).withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: (iconColor ?? colorScheme.primary).withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon,
              size: 36,
              color: iconColor ?? colorScheme.primary,
            ),
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
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 20),
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
    final initial = label.isNotEmpty ? label.characters.first.toUpperCase() : '?';

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
