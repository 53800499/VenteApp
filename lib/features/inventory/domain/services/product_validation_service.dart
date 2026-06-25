import '../../../../core/errors/failures.dart';
import '../entities/inventory_entities.dart';

class ProductValidationService {
  const ProductValidationService();

  static const defaultAlertThreshold = 5;

  void validateName(String name) {
    if (name.trim().length < 2) {
      throw const ValidationFailure('Le nom doit comporter au moins 2 caractères.');
    }
  }

  void validatePrices({required int priceSell, int? priceBuy}) {
    if (priceSell <= 0) {
      throw const ValidationFailure('Le prix de vente doit être supérieur à 0 FCFA.');
    }
    if (priceBuy != null) {
      if (priceBuy <= 0) {
        throw const ValidationFailure(
          'Le prix d\'achat doit être supérieur à 0 FCFA.',
        );
      }
      if (priceBuy >= priceSell) {
        throw const ValidationFailure(
          'Le prix d\'achat doit être inférieur au prix de vente.',
        );
      }
    }
  }

  void validateInitialQuantity(int quantity) {
    if (quantity < 0) {
      throw const ValidationFailure('La quantité initiale doit être >= 0.');
    }
  }

  int resolveAlertThreshold(int? threshold, {int shopDefault = defaultAlertThreshold}) {
    if (threshold == null) return shopDefault;
    if (threshold < 0) {
      throw const ValidationFailure('Le seuil d\'alerte doit être >= 0.');
    }
    return threshold;
  }

  ({int quantityBefore, int quantityAfter}) validateStockAdjustment({
    required StockAdjustmentType type,
    required int currentStock,
    required int quantityChange,
    String? reason,
  }) {
    if (type == StockAdjustmentType.adjustment ||
        type == StockAdjustmentType.loss) {
      if ((reason?.trim().length ?? 0) < 3) {
        throw const ValidationFailure(
          'Un motif d\'au moins 3 caractères est obligatoire pour cet ajustement.',
        );
      }
    }

    final quantityAfter = currentStock + quantityChange;
    if (quantityAfter < 0) {
      throw ValidationFailure(
        'Stock insuffisant. Stock actuel : $currentStock.',
      );
    }

    return (quantityBefore: currentStock, quantityAfter: quantityAfter);
  }
}
