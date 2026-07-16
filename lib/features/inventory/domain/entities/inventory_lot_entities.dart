import 'package:equatable/equatable.dart';

/// Types de source d'un lot.
abstract final class InventoryLotSourceType {
  static const initialMigration = 'initial_migration';
  static const procurementReceipt = 'procurement_receipt';
  static const directProcurement = 'direct_procurement';
  static const manualRestock = 'manual_restock';
  static const saleCancelRestore = 'sale_cancel_restore';
}

abstract final class InventoryLotStatus {
  static const active = 'active';
  static const depleted = 'depleted';
}

class InventoryLot extends Equatable {
  const InventoryLot({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.sourceType,
    this.sourceId,
    this.purchaseReceiptItemId,
    this.supplierId,
    required this.unitCost,
    required this.quantityReceived,
    required this.quantityRemaining,
    this.batchNumber,
    this.expiryDate,
    required this.receivedAt,
    required this.status,
    required this.createdAt,
    required this.version,
  });

  final int id;
  final int shopId;
  final int productId;
  final String sourceType;
  final int? sourceId;
  final int? purchaseReceiptItemId;
  final int? supplierId;
  final int unitCost;
  final int quantityReceived;
  final int quantityRemaining;
  final String? batchNumber;
  final int? expiryDate;
  final int receivedAt;
  final String status;
  final int createdAt;
  final int version;

  @override
  List<Object?> get props => [
        id,
        shopId,
        productId,
        sourceType,
        sourceId,
        purchaseReceiptItemId,
        supplierId,
        unitCost,
        quantityReceived,
        quantityRemaining,
        batchNumber,
        expiryDate,
        receivedAt,
        status,
        createdAt,
        version,
      ];
}

/// Résultat d'une allocation FIFO (une tranche de lot).
class LotAllocationSlice extends Equatable {
  const LotAllocationSlice({
    required this.lotId,
    required this.quantity,
    required this.unitCost,
  });

  final int lotId;
  final int quantity;
  final int unitCost;

  @override
  List<Object?> get props => [lotId, quantity, unitCost];
}
