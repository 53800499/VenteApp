import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../domain/entities/sale_entities.dart';

/// Loaders, confirmations et retours utilisateur pour le module ventes.
class SaleFeedback {
  SaleFeedback._();

  static Widget inlineLoader({double size = 20}) =>
      ActionFeedback.inlineLoader(size: size);

  static void showInfo(BuildContext context, String message) =>
      ActionFeedback.showInfo(context, message);

  static void showError(BuildContext context, Object error) =>
      ActionFeedback.showError(context, error);

  static void showErrorMessage(BuildContext context, String message) =>
      ActionFeedback.showErrorMessage(context, message);

  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      ActionFeedback.showErrorDialog(
        context,
        title: title,
        message: message,
      );

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool isDestructive = false,
  }) =>
      ActionFeedback.confirm(
        context: context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      );

  static Future<String?> confirmWithReason({
    required BuildContext context,
    required String title,
    required String hint,
    String confirmLabel = 'Confirmer',
    int minLength = 5,
  }) =>
      ActionFeedback.confirmWithReason(
        context: context,
        title: title,
        hint: hint,
        confirmLabel: confirmLabel,
        minLength: minLength,
      );

  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    String? message,
    List<Widget>? details,
  }) =>
      ActionFeedback.showSuccess(
        context: context,
        title: title,
        message: message,
        details: details,
      );

  static Future<void> showSaleRegistered(
    BuildContext context, {
    required Sale sale,
  }) {
    return showSuccess(
      context: context,
      title: 'Vente enregistrée',
      details: [
        if (sale.receiptNumber != null)
          Text('Reçu : ${sale.receiptNumber}')
        else
          Text('Vente #${sale.id}'),
        Text('Total : ${formatFcfa(sale.totalAmount)}'),
        Text('Paiement : ${sale.paymentMethod.label}'),
      ],
    );
  }

  static Future<T?> runWithBlockingLoader<T>({
    required BuildContext context,
    required Future<T> Function() action,
    String message = 'Traitement en cours…',
  }) =>
      ActionFeedback.runWithBlockingLoader(
        context: context,
        action: action,
        message: message,
      );
}
