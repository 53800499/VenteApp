/// Seeds de navigation / préremplissage issus de la voix.
class VoiceSaleLineSeed {
  const VoiceSaleLineSeed({
    this.productId,
    this.quantity,
    this.unitPrice,
  });

  final int? productId;
  final int? quantity;
  final int? unitPrice;
}

class VoiceSaleSeed {
  const VoiceSaleSeed({
    this.productId,
    this.quantity,
    this.unitPrice,
    this.customerId,
    this.lines = const [],
  });

  /// Compat mono-ligne (si [lines] vide).
  final int? productId;
  final int? quantity;
  final int? unitPrice;
  final int? customerId;
  final List<VoiceSaleLineSeed> lines;

  List<VoiceSaleLineSeed> get effectiveLines {
    if (lines.isNotEmpty) return lines;
    if (productId == null) return const [];
    return [
      VoiceSaleLineSeed(
        productId: productId,
        quantity: quantity,
        unitPrice: unitPrice,
      ),
    ];
  }
}

class VoiceExpenseSeed {
  const VoiceExpenseSeed({
    this.title,
    this.amount,
    this.categoryId,
  });

  final String? title;
  final int? amount;
  final int? categoryId;
}

class VoiceDebtPaymentSeed {
  const VoiceDebtPaymentSeed({
    this.amount,
  });

  final int? amount;
}

class VoiceFxSeed {
  const VoiceFxSeed({
    this.operationTypeCode,
    this.foreignCurrency,
    this.fromAmount,
  });

  final String? operationTypeCode;
  final String? foreignCurrency;
  final int? fromAmount;
}

class VoiceProductSeed {
  const VoiceProductSeed({
    this.name,
    this.priceSell,
    this.priceBuy,
    this.categoryId,
    this.sku,
    this.quantity,
    this.alertThreshold,
  });

  final String? name;
  final int? priceSell;
  final int? priceBuy;
  final int? categoryId;
  final String? sku;
  final int? quantity;
  final int? alertThreshold;

  bool get hasAny =>
      (name != null && name!.trim().isNotEmpty) ||
      priceSell != null ||
      priceBuy != null ||
      categoryId != null ||
      (sku != null && sku!.trim().isNotEmpty) ||
      quantity != null ||
      alertThreshold != null;
}

class VoiceCategorySeed {
  const VoiceCategorySeed({
    this.name,
    this.description,
  });

  final String? name;
  final String? description;

  bool get hasAny =>
      (name != null && name!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty);
}
