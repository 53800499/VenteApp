import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/errors/exception_mapper.dart';
import '../../core/security/production_message_policy.dart';
import 'adaptive_modal.dart';

/// Loaders, confirmations et retours utilisateur (partagé entre modules).
class ActionFeedback {
  ActionFeedback._();

  static Widget inlineLoader({double size = 20}) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ProductionMessagePolicy.sanitize(message)),
          showCloseIcon: true,
        ),
      );
  }

  static void showError(BuildContext context, Object error) {
    showErrorMessage(context, friendlyErrorMessage(error));
  }

  static void showErrorMessage(BuildContext context, String message) {
    final clean = ProductionMessagePolicy.sanitize(message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(clean),
          backgroundColor: Theme.of(context).colorScheme.error,
          showCloseIcon: true,
        ),
      );
  }

  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final clean = ProductionMessagePolicy.sanitize(message);
    return showAdaptiveAppModal<void>(
      context: context,
      title: title,
      icon: Icons.error_outline_rounded,
      iconColor: Theme.of(context).colorScheme.error,
      maxWidth: 460,
      builder: (ctx) => Text(clean, style: Theme.of(ctx).textTheme.bodyMedium),
      actions: [
        Builder(
          builder: (ctx) => FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ),
      ],
    );
  }

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool isDestructive = false,
  }) {
    return showAdaptiveConfirm(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: isDestructive,
    );
  }

  static Future<String?> confirmWithReason({
    required BuildContext context,
    required String title,
    required String hint,
    String confirmLabel = 'Confirmer',
    int minLength = 5,
  }) async {
    final controller = TextEditingController();
    String? validationError;

    final confirmed = await showAdaptiveAppModal<bool>(
      context: context,
      title: title,
      icon: Icons.edit_note_rounded,
      maxWidth: 480,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: hint,
                errorText: validationError,
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().length < minLength) {
                      setState(
                        () => validationError =
                            'Minimum $minLength caractères requis.',
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      controller.dispose();
      return null;
    }

    final reason = controller.text.trim();
    controller.dispose();
    return reason;
  }

  /// Modal de succès standard — adapté selon l'écran (Windows dialogue centré, Mobile bottom sheet).
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    String? message,
    List<Widget>? details,
    String buttonLabel = 'OK',
  }) {
    return showAdaptiveAppModal<void>(
      context: context,
      title: title,
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.success,
      maxWidth: 460,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null)
            Text(
              message,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          if (details != null && details.isNotEmpty) ...[
            if (message != null) const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: Theme.of(ctx)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < details.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    details[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx),
            child: Text(buttonLabel),
          ),
        ),
      ],
    );
  }

  /// Raccourci lorsque le titre seul suffit.
  static Future<void> showSuccessMessage(
    BuildContext context,
    String title, {
    String? message,
  }) =>
      showSuccess(context: context, title: title, message: message);

  static Future<T?> runWithBlockingLoader<T>({
    required BuildContext context,
    required Future<T> Function() action,
    String message = 'Traitement en cours…',
  }) async {
    if (!context.mounted) return null;

    var loaderOpen = false;
    NavigatorState? loaderNavigator;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        loaderOpen = true;
        loaderNavigator = Navigator.of(ctx);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                inlineLoader(),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      },
    );

    await WidgetsBinding.instance.endOfFrame;

    try {
      return await action();
    } finally {
      final nav = loaderNavigator;
      if (loaderOpen && nav != null && nav.mounted && nav.canPop()) {
        nav.pop();
      }
    }
  }
}
