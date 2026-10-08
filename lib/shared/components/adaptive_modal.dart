import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/responsive/breakpoints.dart';

/// Affiche une modale adaptée à la plateforme et à la taille d'écran :
/// - **Windows / grand écran** (≥ [Breakpoints.desktopMin]) : dialogue centré,
///   largeur et hauteur bornées, barre de titre avec bouton « X »,
///   fermeture par Échap, pied d'actions aligné à droite.
/// - **Mobile** : bottom sheet tactile ancrée en bas, réactive au clavier virtuel
///   (viewInsets), scrollable avec zone de sécurité.
///
/// [scrollable] : à `false` si le contenu gère déjà son propre défilement.
Future<T?> showAdaptiveAppModal<T>({
  required BuildContext context,
  required Widget Function(BuildContext modalContext) builder,
  String? title,
  String? subtitle,
  IconData? icon,
  Color? iconColor,
  double maxWidth = 560,
  double? maxHeight,
  bool isDismissible = true,
  bool scrollable = true,
  EdgeInsetsGeometry? contentPadding,
  List<Widget>? actions,
}) {
  final isDesktop =
      Breakpoints.isDesktopWidth(MediaQuery.sizeOf(context).width);

  if (isDesktop) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => _DesktopModalShell(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        isDismissible: isDismissible,
        scrollable: scrollable,
        contentPadding: contentPadding ??
            (title != null || icon != null
                ? const EdgeInsets.all(AppSpacing.lg)
                : const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md)),
        actions: actions,
        child: Builder(builder: builder),
      ),
    );
  }

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final hasHeader = title != null || icon != null;

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    showDragHandle: !hasHeader,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      final sheetTheme = Theme.of(sheetContext);
      final sheetScheme = sheetTheme.colorScheme;
      final mediaQuery = MediaQuery.of(sheetContext);
      final resolvedMaxHeight =
          maxHeight ?? mediaQuery.size.height * 0.9;

      final defaultPadding = hasHeader
          ? const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            )
          : const EdgeInsets.all(AppSpacing.md);

      final effectivePadding = contentPadding ?? defaultPadding;

      Widget content = Padding(
        padding: effectivePadding,
        child: builder(sheetContext),
      );
      if (scrollable) {
        content = SingleChildScrollView(
          child: content,
        );
      }

      return Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: resolvedMaxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasHeader)
                  _AdaptiveModalHeader(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    iconColor: iconColor,
                    showClose: isDismissible,
                    isDesktop: false,
                  ),
                Flexible(
                  child: content,
                ),
                if (actions != null && actions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: sheetScheme.surfaceContainerLow,
                      border: Border(
                        top: BorderSide(
                          color: sheetScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: AppSpacing.sm,
                      overflowSpacing: AppSpacing.xs,
                      children: actions,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Coque visuelle des modales desktop (Windows).
class _DesktopModalShell extends StatelessWidget {
  const _DesktopModalShell({
    required this.child,
    required this.maxWidth,
    required this.isDismissible,
    required this.scrollable,
    required this.contentPadding,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.maxHeight,
    this.actions,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final double maxWidth;
  final double? maxHeight;
  final bool isDismissible;
  final bool scrollable;
  final EdgeInsetsGeometry contentPadding;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mediaSize = MediaQuery.sizeOf(context);
    final resolvedMaxHeight =
        maxHeight ?? (mediaSize.height * 0.85);
    final dialogWidth = math.min(
      maxWidth,
      math.max(300.0, mediaSize.width - 48.0),
    );
    final hasHeader = title != null || icon != null;

    Widget content = Padding(
      padding: contentPadding,
      child: child,
    );
    if (scrollable) {
      content = SingleChildScrollView(
        child: content,
      );
    }

    return CallbackShortcuts(
      bindings: {
        if (isDismissible)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 24,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: dialogWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: resolvedMaxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasHeader)
                    _AdaptiveModalHeader(
                      title: title,
                      subtitle: subtitle,
                      icon: icon,
                      iconColor: iconColor,
                      showClose: isDismissible,
                      isDesktop: true,
                    )
                  else if (isDismissible)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Fermer (Échap)',
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  Flexible(
                    child: content,
                  ),
                  if (actions != null && actions!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border(
                          top: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: AppSpacing.sm,
                        overflowSpacing: AppSpacing.xs,
                        children: actions!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveModalHeader extends StatelessWidget {
  const _AdaptiveModalHeader({
    required this.showClose,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.isDesktop = true,
  });

  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool showClose;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = iconColor ?? scheme.primary;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? AppSpacing.lg : AppSpacing.md,
        isDesktop ? AppSpacing.md : AppSpacing.sm,
        AppSpacing.sm,
        isDesktop ? AppSpacing.md : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            SizedBox(width: isDesktop ? AppSpacing.md : AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (showClose)
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: isDesktop ? 'Fermer (Échap)' : 'Fermer',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Confirmation adaptée : dialogue centré ergonomique sur desktop et mobile.
Future<bool> showAdaptiveConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      final accent = destructive ? scheme.error : scheme.primary;
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: 28),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(80, 40),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: destructive ? scheme.onError : scheme.onPrimary,
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
