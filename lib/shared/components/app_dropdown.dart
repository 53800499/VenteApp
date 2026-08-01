import 'package:flutter/material.dart';
import 'package:dropdown_flutter/custom_dropdown.dart';
import '../../app/theme/app_tokens.dart';

/// Composant sélecteur déroulant hautement ergonomique basé sur [DropdownFlutter].
/// Utilisable partout dans l'application ARIKE pour une UX moderne et fluide.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    this.initialItem,
    this.hintText,
    this.labelText,
    required this.onChanged,
    this.headerBuilder,
    this.listItemBuilder,
    this.validator,
    this.enableSearch = false,
    this.searchHintText = 'Rechercher...',
  });

  final List<T> items;
  final T? initialItem;
  final String? hintText;
  final String? labelText;
  final ValueChanged<T?> onChanged;
  final Widget Function(BuildContext context, T selectedItem, bool enabled)? headerBuilder;
  final Widget Function(BuildContext context, T item, bool isSelected, VoidCallback onItemSelect)? listItemBuilder;
  final String? Function(T?)? validator;
  final bool enableSearch;
  final String searchHintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final decoration = CustomDropdownDecoration(
      closedBorder: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      closedBorderRadius: BorderRadius.circular(AppRadius.sm),
      expandedBorder: Border.all(color: colorScheme.primary, width: 1.5),
      expandedBorderRadius: BorderRadius.circular(AppRadius.sm),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      headerStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      listItemStyle: theme.textTheme.bodyMedium,
      closedFillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      expandedFillColor: colorScheme.surface,
      searchFieldDecoration: SearchFieldDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        textStyle: theme.textTheme.bodyMedium,
      ),
    );

    Widget dropdownWidget;

    if (enableSearch) {
      dropdownWidget = DropdownFlutter<T>.search(
        hintText: hintText ?? 'Sélectionner...',
        items: items,
        initialItem: initialItem,
        onChanged: onChanged,
        headerBuilder: headerBuilder,
        listItemBuilder: listItemBuilder,
        validator: validator,
        searchHintText: searchHintText,
        decoration: decoration,
      );
    } else {
      dropdownWidget = DropdownFlutter<T>(
        hintText: hintText ?? 'Sélectionner...',
        items: items,
        initialItem: initialItem,
        onChanged: onChanged,
        headerBuilder: headerBuilder,
        listItemBuilder: listItemBuilder,
        validator: validator,
        decoration: decoration,
      );
    }

    if (labelText != null && labelText!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            labelText!,
            style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          dropdownWidget,
        ],
      );
    }

    return dropdownWidget;
  }
}
