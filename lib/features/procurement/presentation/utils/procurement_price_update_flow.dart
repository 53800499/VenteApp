import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../../inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import '../../../inventory/data/datasources/local/product_pricing_local_datasource.dart';
import '../../../inventory/domain/entities/product_pricing_entities.dart';
import '../../../inventory/domain/services/product_pricing_service.dart';
import '../widgets/procurement_price_update_dialog.dart';

/// Analyse les lignes d'appro et propose la mise à jour du prix de vente.
class ProcurementPriceUpdateFlow {
  ProcurementPriceUpdateFlow({
    InventoryLocalDatasource? inventoryLocal,
    InventoryLotLocalDatasource? lotLocal,
    ProductPricingLocalDatasource? pricingLocal,
    ProductPricingService? pricingService,
  })  : _inventoryLocal = inventoryLocal ?? sl<InventoryLocalDatasource>(),
        _lotLocal = lotLocal ??
            InventoryLotLocalDatasource(sl<InventoryLocalDatasource>().database),
        _pricingLocal = pricingLocal ?? sl<ProductPricingLocalDatasource>(),
        _pricingService = pricingService ?? const ProductPricingService();

  final InventoryLocalDatasource _inventoryLocal;
  final InventoryLotLocalDatasource _lotLocal;
  final ProductPricingLocalDatasource _pricingLocal;
  final ProductPricingService _pricingService;

  /// Retourne `false` si l'utilisateur annule un dialogue.
  Future<bool> run({
    required BuildContext context,
    required int shopId,
    required List<ProcurementReceiptLineInput> lines,
  }) async {
    if (lines.isEmpty) return true;

    final checkInputs = <ProcurementCostCheckInput>[];
    for (final line in lines) {
      if (line.quantityReceived <= 0) continue;

      final product = await _inventoryLocal.findProduct(shopId, line.productId);
      if (product == null) continue;

      final referenceCost = await _lotLocal.getReferenceUnitCost(
        shopId: shopId,
        productId: line.productId,
      );

      checkInputs.add(
        ProcurementCostCheckInput(
          productId: line.productId,
          productName: line.productName ?? product.name,
          currentPriceSell: product.priceSell,
          referenceUnitCost: referenceCost,
          newUnitCost: line.unitCost,
          pricingMode: ProductPricingMode.fromDb(product.pricingMode),
          marginValue: product.marginValue,
        ),
      );
    }

    final changes = _pricingService.detectCostChanges(items: checkInputs);
    if (changes.isEmpty) return true;

    final decisions = <ProcurementPriceDecision>[];
    for (final change in changes) {
      if (!context.mounted) return false;
      final decision = await ProcurementPriceUpdateDialog.show(
        context,
        change: change,
        pricingService: _pricingService,
      );
      if (decision == null) return false;
      decisions.add(decision);
    }

    final unitCosts = {
      for (final line in lines) line.productId: line.unitCost,
    };

    await _pricingLocal.applyProcurementDecisions(
      shopId: shopId,
      decisions: decisions,
      unitCostsByProduct: unitCosts,
    );

    return true;
  }
}

class ProcurementReceiptLineInput {
  const ProcurementReceiptLineInput({
    required this.productId,
    required this.unitCost,
    required this.quantityReceived,
    this.productName,
  });

  final int productId;
  final int unitCost;
  final int quantityReceived;
  final String? productName;
}
