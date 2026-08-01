import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.onTap,
    this.accentColor,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? colorScheme.primary;

    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boundedHeight = constraints.hasBoundedHeight &&
                constraints.maxHeight.isFinite;
            final tight = boundedHeight && constraints.maxHeight < 128;
            final padding = tight ? AppSpacing.sm : AppSpacing.md;
            final valueStyle = tight
                ? Theme.of(context).textTheme.titleLarge
                : Theme.of(context).textTheme.headlineSmall;

            final valueBlock = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: valueStyle?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: tight ? 11 : 12,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );

            return Container(
              width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:
                    boundedHeight ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (icon != null)
                        Container(
                          padding: EdgeInsets.all(tight ? 6 : 8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Icon(icon, size: tight ? 16 : 18, color: accent),
                        ),
                      if (icon != null)
                        SizedBox(width: tight ? 6 : AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: tight ? 12 : null,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tight ? AppSpacing.xs : AppSpacing.sm),
                  if (boundedHeight)
                    Expanded(child: valueBlock)
                  else
                    valueBlock,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class RevenueHeroCard extends StatelessWidget {
  const RevenueHeroCard({
    super.key,
    required this.revenue,
    required this.saleCount,
    this.onTap,
    this.onNewSale,
  });

  final int revenue;
  final int saleCount;
  final VoidCallback? onTap;
  final VoidCallback? onNewSale;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: Colors.indigo.withValues(alpha: 0.25),
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1B4B), // Premium Deep Indigo
                Color(0xFF312E81),
                Color(0xFF4338CA),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative background glow
              Positioned(
                right: -25,
                top: -25,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.insights_rounded,
                                color: Colors.amberAccent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'CA du jour',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        if (onNewSale != null)
                          ElevatedButton.icon(
                            onPressed: onNewSale,
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text('Vendre', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatFcfa(revenue),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 14,
                            color: Color(0xFF34D399),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            saleCount == 1 ? '1 vente effectuée' : '$saleCount ventes effectuées',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
