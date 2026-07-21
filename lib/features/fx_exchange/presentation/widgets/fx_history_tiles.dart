import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../../domain/services/fx_calculation_service.dart';

String? fxAppliedRateLabel(FxOperation op) {
  const calc = FxCalculationService();
  if (op.operationType == FxOperationType.sell) {
    if (!op.hasSellRate) return null;
    final label = calc.formatRateLabel(
      op.quoteCurrency!,
      FxRateFraction(
        numerator: op.sellRateNumerator!,
        denominator: op.sellRateDenominator!,
      ),
    );
    return 'Taux vente $label';
  }
  if (op.operationType == FxOperationType.buy) {
    if (!op.hasBuyRate) return null;
    final label = calc.formatRateLabel(
      op.quoteCurrency!,
      FxRateFraction(
        numerator: op.buyRateNumerator!,
        denominator: op.buyRateDenominator!,
      ),
    );
    return 'Taux achat $label';
  }
  return null;
}

String fxFormatDateTime(int ms, {bool full = true}) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateFormat(full ? 'dd/MM/yyyy HH:mm' : 'HH:mm').format(dt);
}

class FxOperationHistoryTile extends StatelessWidget {
  const FxOperationHistoryTile({
    super.key,
    required this.operation,
    this.showFullDateTime = false,
    this.dense = false,
    this.contentPadding,
    this.asCard = true,
  });

  final FxOperation operation;
  final bool showFullDateTime;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final op = operation;
    final rateLabel = fxAppliedRateLabel(op);
    final when = fxFormatDateTime(op.createdAt, full: showFullDateTime);

    final tile = ListTile(
      contentPadding: contentPadding,
      dense: dense,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(
          op.operationType == FxOperationType.sell
              ? Icons.south_west
              : Icons.north_east,
          size: 16,
        ),
      ),
      title: Text(
        '${op.operationType.label} · '
        '${formatAmount(op.fromAmount, op.fromCurrency)} → '
        '${formatAmount(op.toAmount, op.toCurrency)}',
      ),
      subtitle: Text(
        [
          'Marge ${formatFcfa(op.marginFcfa)}',
          if (rateLabel != null) rateLabel,
          if (op.customerName != null && op.customerName!.isNotEmpty)
            op.customerName!,
          when,
        ].join(' · '),
      ),
    );

    if (!asCard) return tile;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: tile,
    );
  }
}

class FxMovementHistoryTile extends StatelessWidget {
  const FxMovementHistoryTile({
    super.key,
    required this.movement,
    this.dense = false,
    this.contentPadding,
    this.asCard = true,
  });

  final FxMovement movement;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final mv = movement;
    final when = fxFormatDateTime(mv.createdAt);

    final tile = ListTile(
      contentPadding: contentPadding,
      dense: dense,
      title: Text(
        '${mv.movementType.label} · '
        '${formatAmount(mv.amount, mv.currencyCode)}',
      ),
      subtitle: Text(
        [
          when,
          if (mv.note != null && mv.note!.isNotEmpty) mv.note!,
        ].join(' · '),
      ),
    );

    if (!asCard) return tile;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: tile,
    );
  }
}
