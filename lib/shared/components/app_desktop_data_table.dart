import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Définition d'une colonne pour le tableau desktop
class AppTableColumn {
  const AppTableColumn({
    required this.label,
    this.icon,
    this.width,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
    this.textAlign = TextAlign.left,
    this.onSort,
    this.sortAscending,
    this.isSorted = false,
  });

  final String label;
  final IconData? icon;
  final double? width;
  final int flex;
  final Alignment alignment;
  final TextAlign textAlign;
  final VoidCallback? onSort;
  final bool? sortAscending;
  final bool isSorted;
}

/// Ligne de données pour le tableau desktop
class AppTableRow {
  const AppTableRow({
    required this.cells,
    this.onTap,
    this.selected = false,
    this.color,
  });

  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
}

/// Tableau de données moderne et ergonomique pour les pages de listing sur Windows Desktop
class AppDesktopDataTable extends StatefulWidget {
  const AppDesktopDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyPlaceholder,
    this.itemsPerPage = 15,
    this.showPagination = true,
    this.minWidth = 800,
    this.headerTrailing,
  });

  final List<AppTableColumn> columns;
  final List<AppTableRow> rows;
  final Widget? emptyPlaceholder;
  final int itemsPerPage;
  final bool showPagination;
  final double minWidth;
  final Widget? headerTrailing;

  @override
  State<AppDesktopDataTable> createState() => _AppDesktopDataTableState();
}

class _AppDesktopDataTableState extends State<AppDesktopDataTable> {
  int _currentPage = 0;
  late int _pageSize;
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.itemsPerPage;
  }

  @override
  void didUpdateWidget(AppDesktopDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows.length != oldWidget.rows.length) {
      final maxPage = (widget.rows.length - 1) ~/ _pageSize;
      if (_currentPage > maxPage) {
        _currentPage = maxPage.clamp(0, 99999);
      }
    }
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (widget.rows.isEmpty) {
      return widget.emptyPlaceholder ??
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('Aucune donnée à afficher'),
            ),
          );
    }

    final totalRows = widget.rows.length;
    final startIndex = widget.showPagination ? (_currentPage * _pageSize) : 0;
    final endIndex = widget.showPagination
        ? (startIndex + _pageSize).clamp(0, totalRows)
        : totalRows;
    final pageRows = widget.rows.sublist(
      startIndex.clamp(0, totalRows),
      endIndex,
    );
    final totalPages = (totalRows / _pageSize).ceil();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table avec barre de défilement horizontal et vertical
            Expanded(
              child: LayoutBuilder(
                builder: (context, boxConstraints) {
                  final tableWidth = mathMax(widget.minWidth, boxConstraints.maxWidth);
                  return Scrollbar(
                    controller: _horizontalScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          children: [
                            // En-tête des colonnes
                            _buildHeader(theme, scheme),

                        const Divider(height: 1, thickness: 1),

                        // Corps des lignes scrollables
                        Expanded(
                          child: Scrollbar(
                            controller: _verticalScroll,
                            thumbVisibility: true,
                            child: ListView.separated(
                              controller: _verticalScroll,
                              itemCount: pageRows.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                thickness: 1,
                                color: scheme.outlineVariant.withValues(alpha: 0.15),
                              ),
                              itemBuilder: (context, index) {
                                final row = pageRows[index];
                                final isHovered = _hoveredIndex == index;

                                return MouseRegion(
                                  cursor: row.onTap != null
                                      ? SystemMouseCursors.click
                                      : SystemMouseCursors.basic,
                                  onEnter: (_) => setState(() => _hoveredIndex = index),
                                  onExit: (_) => setState(() => _hoveredIndex = null),
                                  child: InkWell(
                                    onTap: row.onTap,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      color: row.selected
                                          ? scheme.primary.withValues(alpha: 0.12)
                                          : (isHovered
                                              ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
                                              : (row.color ?? Colors.transparent)),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm + 2,
                                      ),
                                      child: Row(
                                        children: List.generate(
                                          widget.columns.length,
                                          (colIndex) {
                                            final col = widget.columns[colIndex];
                                            final cell = colIndex < row.cells.length
                                                ? row.cells[colIndex]
                                                : const SizedBox.shrink();

                                            if (col.width != null) {
                                              return SizedBox(
                                                width: col.width,
                                                child: Align(
                                                  alignment: col.alignment,
                                                  child: cell,
                                                ),
                                              );
                                            }

                                            return Expanded(
                                              flex: col.flex,
                                              child: Align(
                                                alignment: col.alignment,
                                                child: cell,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

            // Pied de table avec pagination
            if (widget.showPagination)
              _buildPaginationFooter(
                theme,
                scheme,
                startIndex: startIndex + 1,
                endIndex: endIndex,
                totalRows: totalRows,
                totalPages: totalPages,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: List.generate(widget.columns.length, (colIndex) {
          final col = widget.columns[colIndex];

          final content = InkWell(
            onTap: col.onSort,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (col.icon != null) ...[
                    Icon(
                      col.icon,
                      size: 14,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      col.label.toUpperCase(),
                      textAlign: col.textAlign,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: col.isSorted ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (col.onSort != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      col.isSorted
                          ? (col.sortAscending == true
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                          : Icons.unfold_more_rounded,
                      size: 14,
                      color: col.isSorted ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          );

          if (col.width != null) {
            return SizedBox(
              width: col.width,
              child: Align(alignment: col.alignment, child: content),
            );
          }

          return Expanded(
            flex: col.flex,
            child: Align(alignment: col.alignment, child: content),
          );
        }),
      ),
    );
  }

  Widget _buildPaginationFooter(
    ThemeData theme,
    ColorScheme scheme, {
    required int startIndex,
    required int endIndex,
    required int totalRows,
    required int totalPages,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          // Statut d'affichage
          Text(
            'Affichage de $startIndex à $endIndex sur $totalRows résultat${totalRows > 1 ? 's' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),

          // Sélecteur d'éléments par page
          Text(
            'Lignes :',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButton<int>(
            value: _pageSize,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 15, child: Text('15')),
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _pageSize = val;
                  _currentPage = 0;
                });
              }
            },
          ),
          const SizedBox(width: AppSpacing.lg),

          // Boutons navigation de page
          IconButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Page précédente',
            visualDensity: VisualDensity.compact,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${_currentPage + 1} / ${totalPages > 0 ? totalPages : 1}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Page suivante',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  double mathMax(double a, double b) => a > b ? a : b;
}
