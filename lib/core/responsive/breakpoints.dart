import 'screen_type.dart';

abstract final class Breakpoints {
  static const compactMax = 599.0;
  static const mediumMax = 839.0;

  static const contentMaxCompact = double.infinity;
  static const contentMaxMedium = 720.0;
  static const contentMaxExpanded = 960.0;

  static const formMaxWidth = 560.0;
  static const pinPadMaxWidth = 420.0;
  static const authMaxWidth = 480.0;

  static ScreenType screenTypeOf(double width) {
    if (width <= compactMax) return ScreenType.compact;
    if (width <= mediumMax) return ScreenType.medium;
    return ScreenType.expanded;
  }

  static double contentMaxWidth(ScreenType type) {
    return switch (type) {
      ScreenType.compact => contentMaxCompact,
      ScreenType.medium => contentMaxMedium,
      ScreenType.expanded => contentMaxExpanded,
    };
  }

  static double horizontalPadding(ScreenType type) {
    return switch (type) {
      ScreenType.compact => 16,
      ScreenType.medium => 24,
      ScreenType.expanded => 32,
    };
  }

  static int gridColumns(
    ScreenType type, {
    int compact = 1,
    int medium = 2,
    int expanded = 3,
  }) {
    return switch (type) {
      ScreenType.compact => compact,
      ScreenType.medium => medium,
      ScreenType.expanded => expanded,
    };
  }

  static int kpiGridColumns(ScreenType type) {
    return switch (type) {
      ScreenType.compact => 2,
      ScreenType.medium => 3,
      ScreenType.expanded => 4,
    };
  }

  static bool useNavigationRail(ScreenType type) => type != ScreenType.compact;

  static double navigationRailWidth(ScreenType type) {
    return type == ScreenType.expanded ? 88 : 72;
  }
}
