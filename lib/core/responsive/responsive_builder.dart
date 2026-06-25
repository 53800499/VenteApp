import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'breakpoints.dart';
import 'screen_type.dart';

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  ScreenType get screenType => Breakpoints.screenTypeOf(screenWidth);
  bool get isCompactScreen => screenType.isCompact;
  bool get isTabletScreen => screenType.isTablet;
}

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, ScreenType screenType) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final type = Breakpoints.screenTypeOf(constraints.maxWidth);
        return builder(context, type);
      },
    );
  }
}

/// Centre le contenu et limite la largeur sur tablette.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, type) {
        final resolvedMax = maxWidth ?? Breakpoints.contentMaxWidth(type);
        final resolvedPadding = padding ??
            EdgeInsets.symmetric(
              horizontal: Breakpoints.horizontalPadding(type),
            );

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: resolvedMax,
            ),
            child: Padding(
              padding: resolvedPadding,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Page formulaire avec largeur optimale pour la saisie.
class ResponsiveFormPage extends StatelessWidget {
  const ResponsiveFormPage({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      maxWidth: Breakpoints.formMaxWidth,
      padding: padding ??
          const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }
}

/// Grille adaptative selon la taille d'écran.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 3,
    this.mainAxisSpacing = AppSpacing.sm + 4,
    this.crossAxisSpacing = AppSpacing.sm + 4,
    this.childAspectRatio,
    this.mainAxisExtent,
    this.padding,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int compactColumns;
  final int mediumColumns;
  final int expandedColumns;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double? childAspectRatio;
  final double? mainAxisExtent;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, type) {
        final columns = Breakpoints.gridColumns(
          type,
          compact: compactColumns,
          medium: mediumColumns,
          expanded: expandedColumns,
        );

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: childAspectRatio ?? 1.35,
            mainAxisExtent: mainAxisExtent,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

/// Valeur responsive simple (padding, tailles, etc.).
class ResponsiveValue<T> {
  const ResponsiveValue({
    required this.compact,
    this.medium,
    this.expanded,
  });

  final T compact;
  final T? medium;
  final T? expanded;

  T of(ScreenType type) {
    return switch (type) {
      ScreenType.compact => compact,
      ScreenType.medium => medium ?? compact,
      ScreenType.expanded => expanded ?? medium ?? compact,
    };
  }

  T ofContext(BuildContext context) => of(context.screenType);
}
