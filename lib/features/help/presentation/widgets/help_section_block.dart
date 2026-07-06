import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/components/feature_ui.dart';
import '../../domain/entities/help_entities.dart';

class HelpSectionBlock extends StatelessWidget {
  const HelpSectionBlock({super.key, required this.section});

  final HelpSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FeatureSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            section.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: AppSizes.lineHeightBody,
              color: AppColors.onSurfaceMuted,
            ),
          ),
          if (section.bullets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...section.bullets.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        bullet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: AppSizes.lineHeightBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (section.tip != null) ...[
            const SizedBox(height: AppSpacing.md),
            FeatureTipBanner(message: section.tip!),
          ],
        ],
      ),
    );
  }
}
