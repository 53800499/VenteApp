import 'package:flutter/material.dart';

/// Catégorie thématique du centre d'aide.
class HelpCategory {
  const HelpCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

/// Section d'un article d'aide.
class HelpSection {
  const HelpSection({
    required this.title,
    this.body = '',
    this.bullets = const [],
    this.steps = const [],
    this.tip,
  });

  final String title;
  final String body;
  final List<String> bullets;

  /// Étapes numérotées pour les procédures pas à pas (A → Z).
  final List<String> steps;
  final String? tip;
}

/// Article d'aide détaillé sur un module.
class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
    required this.sections,
    this.keywords = const [],
  });

  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final IconData icon;
  final Color color;
  final List<HelpSection> sections;
  final List<String> keywords;
}
