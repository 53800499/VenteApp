import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/errors/exception_mapper.dart';

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
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static void showError(BuildContext context, Object error) {
    showErrorMessage(context, friendlyErrorMessage(error));
  }

  static void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.error_outline, color: Theme.of(ctx).colorScheme.error),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
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
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Theme.of(ctx).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
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

  /// Modal de succès standard — à utiliser après toute opération réussie.
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    String? message,
    List<Widget>? details,
    String buttonLabel = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 48,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null)
                Text(message, textAlign: TextAlign.center),
              if (details != null) ...[
                if (message != null) const SizedBox(height: AppSpacing.md),
                ...details,
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(buttonLabel),
          ),
        ],
      ),
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
