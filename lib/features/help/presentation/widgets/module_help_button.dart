import 'package:flutter/material.dart';

import '../pages/help_article_page.dart';

/// Ouvre le guide pas à pas d'un module depuis sa barre d'outils.
class ModuleHelpButton extends StatelessWidget {
  const ModuleHelpButton({
    super.key,
    required this.articleId,
    this.tooltip = 'Guide utilisateur',
  });

  final String articleId;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu_book_outlined),
      tooltip: tooltip,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HelpArticlePage(articleId: articleId),
          ),
        );
      },
    );
  }
}
