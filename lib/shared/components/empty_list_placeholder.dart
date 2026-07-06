import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import 'feature_ui.dart';

/// État vide uniforme (style liste produits) avec rechargement optionnel.
class EmptyListPlaceholder extends StatelessWidget {
  const EmptyListPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRefresh,
    this.topPadding = AppSizes.emptyStatePadding,
    this.embedded = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Si fourni et [embedded] est `false`, enveloppe avec [RefreshIndicator].
  final Future<void> Function()? onRefresh;

  /// Espace vertical minimal hors contrainte parente.
  final double topPadding;

  /// `true` : contenu scrollable pour un [RefreshIndicator] parent.
  final bool embedded;

  /// État vide avec tirer-pour-actualiser (onglets, pages pleines).
  static Widget refreshable({
    required IconData icon,
    required String title,
    String? subtitle,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: EmptyListPlaceholder(
        embedded: true,
        icon: icon,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FeatureIllustrationIcon(icon: icon),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
                height: AppSizes.lineHeightBody,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scrollableContent(BuildContext context, double minHeight) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Center(child: buildContent(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (embedded || onRefresh != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final minHeight = constraints.maxHeight.isFinite &&
                  constraints.maxHeight > 0
              ? constraints.maxHeight
              : topPadding * 2 + 220;

          final scrollable = _scrollableContent(context, minHeight);

          if (embedded || onRefresh == null) {
            return scrollable;
          }
          return RefreshIndicator(
            onRefresh: onRefresh!,
            child: scrollable,
          );
        },
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: buildContent(context),
      ),
    );
  }
}
