import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/components/feature_ui.dart';
import '../../data/help_catalog.dart';
import '../../domain/entities/help_entities.dart';
import '../widgets/help_topic_card.dart';
import 'help_article_page.dart';

/// Hub central de documentation utilisateur.
class HelpHubPage extends StatefulWidget {
  const HelpHubPage({super.key});

  @override
  State<HelpHubPage> createState() => _HelpHubPageState();
}

class _HelpHubPageState extends State<HelpHubPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HelpArticle> get _filteredArticles {
    var list = HelpCatalog.search(_query);
    if (_selectedCategoryId != null) {
      list = list.where((a) => a.categoryId == _selectedCategoryId).toList();
    }
    return list;
  }

  void _openArticle(HelpArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HelpArticlePage(articleId: article.id),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final articles = _filteredArticles;
    final showCategories = _query.isEmpty && _selectedCategoryId == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide & guides'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveBuilder(
            builder: (context, screenType) {
              final horizontal = Breakpoints.horizontalPadding(screenType);
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.sm,
                  horizontal,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FeatureSearchField(
                      controller: _searchController,
                      hintText: 'Rechercher un module, une action…',
                      showClear: _query.isNotEmpty,
                      onChanged: (v) => setState(() => _query = v),
                      onClear: _clearSearch,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: AppSizes.filterChipRowHeight,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          FeatureFilterChip(
                            label: 'Tout',
                            selected: _selectedCategoryId == null,
                            onTap: () =>
                                setState(() => _selectedCategoryId = null),
                          ),
                          ...HelpCatalog.categories.map(
                            (c) => FeatureFilterChip(
                              label: c.title,
                              selected: _selectedCategoryId == c.id,
                              color: c.color,
                              onTap: () => setState(
                                () => _selectedCategoryId =
                                    _selectedCategoryId == c.id ? null : c.id,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: ResponsiveBuilder(
              builder: (context, screenType) {
                final horizontal = Breakpoints.horizontalPadding(screenType);

                if (showCategories) {
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      0,
                      horizontal,
                      AppSpacing.xl,
                    ),
                    children: HelpCatalog.categories
                        .map(
                          (category) => _CategorySection(
                            category: category,
                            onArticleTap: _openArticle,
                          ),
                        )
                        .toList(),
                  );
                }

                if (articles.isEmpty) {
                  return EmptyListPlaceholder(
                    icon: Icons.search_off_outlined,
                    title: 'Aucun article ne correspond',
                    subtitle:
                        'Essayez un autre mot-clé ou retirez les filtres',
                  );
                }

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    0,
                    horizontal,
                    AppSpacing.xl,
                  ),
                  children: articles
                      .map(
                        (a) => HelpTopicCard(
                          article: a,
                          onTap: () => _openArticle(a),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.onArticleTap,
  });

  final HelpCategory category;
  final void Function(HelpArticle article) onArticleTap;

  @override
  Widget build(BuildContext context) {
    final articles = HelpCatalog.articlesForCategory(category.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeatureSectionHeader(
            title: category.title,
            subtitle: category.subtitle,
            icon: category.icon,
            color: category.color,
          ),
          ...articles.map(
            (a) => HelpTopicCard(
              article: a,
              onTap: () => onArticleTap(a),
            ),
          ),
        ],
      ),
    );
  }
}
