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
    this.expandHeight = false,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;
  final bool expandHeight;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, type) {
        final resolvedMax = maxWidth ?? Breakpoints.contentMaxWidth(type);
        final resolvedPadding = padding ??
            EdgeInsets.symmetric(
              horizontal: Breakpoints.horizontalPadding(type),
            );

        final content = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: resolvedMax,
          ),
          child: Padding(
            padding: resolvedPadding,
            child: child,
          ),
        );

        if (!expandHeight) {
          return SizedBox(
            width: double.infinity,
            child: Align(
              alignment: alignment,
              child: content,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;

            return Align(
              alignment: alignment,
              child: SizedBox(
                width: double.infinity,
                height: height,
                child: content,
              ),
            );
          },
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
      padding: EdgeInsets.zero,
      expandHeight: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolvedPadding =
              padding ?? const EdgeInsets.all(AppSpacing.lg);
          final hasBoundedHeight =
              constraints.maxHeight.isFinite && constraints.maxHeight > 0;

          if (hasBoundedHeight) {
            return Padding(
              padding: resolvedPadding,
              child: SizedBox(
                height: constraints.maxHeight,
                child: child,
              ),
            );
          }

          return SingleChildScrollView(
            padding: resolvedPadding,
            child: child,
          );
        },
      ),
    );
  }
}

/// Colonne scrollable : le contenu défile sur petits écrans, [Spacer] fonctionne
/// quand la hauteur le permet.
class ResponsiveScrollColumn extends StatelessWidget {
  const ResponsiveScrollColumn({
    super.key,
    required this.children,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;

        // Avec hauteur bornée : scroll si le contenu dépasse ; Spacer possible via minHeight.
        if (hasBoundedHeight) {
          return Padding(
            padding: padding ?? EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: crossAxisAlignment,
                  children: children,
                ),
              ),
            ),
          );
        }

        // Hauteur illimitée : scroll simple, pas de flex vertical.
        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        );
      },
    );
  }
}

/// Grille KPI adaptative (hauteur fixe par tuile, pas de débordement).
class ResponsiveKpiGrid extends StatelessWidget {
  const ResponsiveKpiGrid({
    super.key,
    required this.children,
    this.withSubtitle = false,
    this.crossAxisCount,
  });

  final List<Widget> children;
  final bool withSubtitle;
  final int? crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, type) {
        final columns = crossAxisCount ?? Breakpoints.kpiGridColumns(type);

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm + 4,
          crossAxisSpacing: AppSpacing.sm + 4,
          mainAxisExtent: Breakpoints.kpiTileHeight(
            type,
            withSubtitle: withSubtitle,
          ),
          children: children,
        );
      },
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
