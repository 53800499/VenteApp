enum ScreenType {
  compact,
  medium,
  expanded,
}

extension ScreenTypeX on ScreenType {
  bool get isCompact => this == ScreenType.compact;
  bool get isMedium => this == ScreenType.medium;
  bool get isExpanded => this == ScreenType.expanded;
  bool get isTablet => this != ScreenType.compact;
}
