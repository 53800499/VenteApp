import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

/// Sélecteur d'élément avec recherche intégrée fluide et sans superposition d'input.
/// Idéal pour la sélection de produits/articles dans les formulaires et dialogues.
class AppSearchableItemPicker<T> extends StatefulWidget {
  const AppSearchableItemPicker({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.labelBuilder,
    this.subtitleBuilder,
    this.filterPredicate,
    this.labelText = 'Produit *',
    this.hintText = 'Rechercher un produit...',
    this.maxListHeight = 180,
    this.autofocus = false,
  });

  /// Liste complète des éléments disponibles
  final List<T> items;

  /// Élément actuellement sélectionné
  final T? selectedItem;

  /// Callback appelé lors de la sélection ou dé-sélection
  final ValueChanged<T?> onChanged;

  /// Texte principal de l'élément (ex: nom du produit)
  final String Function(T item) labelBuilder;

  /// Texte secondaire de l'élément (ex: stock, prix)
  final String Function(T item)? subtitleBuilder;

  /// Prédicat de filtre personnalisé (par défaut teste si label contient la requête)
  final bool Function(T item, String query)? filterPredicate;

  final String labelText;
  final String hintText;
  final double maxListHeight;
  final bool autofocus;

  @override
  State<AppSearchableItemPicker<T>> createState() =>
      _AppSearchableItemPickerState<T>();
}

class _AppSearchableItemPickerState<T>
    extends State<AppSearchableItemPicker<T>> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _query) {
        setState(() {
          _query = q;
        });
      }
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_isExpanded) {
        setState(() => _isExpanded = true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<T> get _filteredItems {
    if (_query.isEmpty) {
      // Afficher les premiers éléments (jusqu'à 15) pour un accès direct rapide
      return widget.items.take(15).toList();
    }
    final qLower = _query.toLowerCase();
    if (widget.filterPredicate != null) {
      return widget.items
          .where((item) => widget.filterPredicate!(item, qLower))
          .toList();
    }
    return widget.items.where((item) {
      final label = widget.labelBuilder(item).toLowerCase();
      final subtitle = widget.subtitleBuilder?.call(item).toLowerCase() ?? '';
      return label.contains(qLower) || subtitle.contains(qLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 1. État : Un élément est sélectionné
    if (widget.selectedItem != null && !_isExpanded) {
      final item = widget.selectedItem as T;
      final label = widget.labelBuilder(item);
      final subtitle = widget.subtitleBuilder?.call(item);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.labelText.isNotEmpty) ...[
            Text(
              widget.labelText,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    widget.onChanged(null);
                    setState(() {
                      _isExpanded = true;
                      _searchController.clear();
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _focusNode.requestFocus();
                    });
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Changer'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 2. État : Champ de recherche avec liste intégrée directe
    final filtered = _filteredItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText.isNotEmpty) ...[
          Text(
            widget.labelText,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        // Champ de saisie de recherche (unique, non superposé)
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : (widget.selectedItem != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          setState(() => _isExpanded = false);
                        },
                      )
                    : null),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),

        const SizedBox(height: 4),

        // Liste des suggestions en dessous du champ
        Container(
          constraints: BoxConstraints(maxHeight: widget.maxListHeight),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Aucun article disponible'
                          : 'Aucun article ne correspond à « $_query »',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < filtered.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                        Builder(
                          builder: (context) {
                            final item = filtered[i];
                            final label = widget.labelBuilder(item);
                            final subtitle = widget.subtitleBuilder?.call(item);
                            final isSelected = widget.selectedItem == item;

                            return InkWell(
                              onTap: () {
                                widget.onChanged(item);
                                setState(() {
                                  _isExpanded = false;
                                  _searchController.clear();
                                });
                              },
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 16,
                                      color: isSelected
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? cs.primary
                                                  : null,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (subtitle != null) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              subtitle,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: cs.primary,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
