import 'package:flutter/material.dart';

import '../../../../shared/components/feature_ui.dart';
import '../../domain/entities/help_entities.dart';

class HelpTopicCard extends StatelessWidget {
  const HelpTopicCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  final HelpArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ModuleActionTile(
      icon: article.icon,
      title: article.title,
      subtitle: article.summary,
      accentColor: article.color,
      onTap: onTap,
    );
  }
}
