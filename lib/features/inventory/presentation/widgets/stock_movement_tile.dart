import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/inventory_entities.dart';

class StockMovementTile extends StatelessWidget {
  const StockMovementTile({super.key, required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isPositive = movement.quantityChange > 0;
    final color = isPositive ? AppColors.success : AppColors.danger;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Text(_labelForType(movement.type)),
      subtitle: Text(
        [
          '${isPositive ? '+' : ''}${movement.quantityChange}',
          if (movement.reason != null) movement.reason!,
          _formatTime(movement.createdAt),
        ].join(' · '),
      ),
      trailing: Text(
        '${movement.quantityAfter}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  String _labelForType(StockMovementType type) {
    return switch (type) {
      StockMovementType.sale => 'Vente',
      StockMovementType.restock => 'Réapprovisionnement',
      StockMovementType.adjustment => 'Correction',
      StockMovementType.loss => 'Perte / vol',
      StockMovementType.return_ => 'Retour',
      StockMovementType.initial => 'Stock initial',
      StockMovementType.saleCancel => 'Annulation vente',
      StockMovementType.transferOut => 'Transfert sortant',
      StockMovementType.transferIn => 'Transfert entrant',
    };
  }

  String _formatTime(int timestampMs) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return '${time.day.toString().padLeft(2, '0')}/'
        '${time.month.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}
