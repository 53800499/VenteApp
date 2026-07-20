import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/inventory_lot_entities.dart';

class StockLotTile extends StatelessWidget {
  const StockLotTile({super.key, required this.lot, required this.fifoRank});

  final InventoryLot lot;
  final int fifoRank;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.seed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '#$fifoRank',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.seed,
                ),
          ),
        ),
      ),
      title: Text(
        '${lot.quantityRemaining} restant(s) · '
        'achat ${formatFcfa(lot.unitCost)}/u',
      ),
      subtitle: Text(
        [
          _labelForSource(lot.sourceType),
          _formatTime(lot.receivedAt),
          if (lot.batchNumber != null && lot.batchNumber!.isNotEmpty)
            'Lot ${lot.batchNumber}',
        ].join(' · '),
      ),
      trailing: Text(
        '${lot.quantityReceived}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _labelForSource(String sourceType) {
    return switch (sourceType) {
      InventoryLotSourceType.initialMigration => 'Migration initiale',
      InventoryLotSourceType.procurementReceipt => 'Réception achat',
      InventoryLotSourceType.directProcurement => 'Approvisionnement direct',
      InventoryLotSourceType.stockTransferIn => 'Transfert entrant',
      InventoryLotSourceType.manualRestock => 'Réappro manuel',
      InventoryLotSourceType.saleCancelRestore => 'Restauration vente',
      _ => sourceType,
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
