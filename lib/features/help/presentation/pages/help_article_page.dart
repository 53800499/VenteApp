import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/components/feature_ui.dart';
import '../../data/help_catalog.dart';
import '../widgets/help_section_block.dart';

class HelpArticlePage extends StatelessWidget {
  const HelpArticlePage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context) {
    final article = HelpCatalog.articleById(articleId);
    if (article == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aide')),
        body: const EmptyListPlaceholder(
          icon: Icons.article_outlined,
          title: 'Article introuvable',
        ),
      );
    }

    final category = HelpCatalog.categoryById(article.categoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text(article.title),
      ),
      body: ResponsiveBuilder(
        builder: (context, screenType) {
          final horizontal = Breakpoints.horizontalPadding(screenType);
          final maxWidth = Breakpoints.contentMaxWidth(screenType);

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.md,
                  horizontal,
                  AppSpacing.xl,
                ),
                children: [
                  if (category != null) ...[
                    FeatureCategoryBadge(
                      label: category.title,
                      icon: category.icon,
                      color: category.color,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    article.summary,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          height: AppSizes.lineHeightBody,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...article.sections.map(
                    (s) => HelpSectionBlock(section: s),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
