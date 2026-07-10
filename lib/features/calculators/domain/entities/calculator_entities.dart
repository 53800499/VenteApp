class TenantModule {
  const TenantModule({
    required this.id,
    required this.shopId,
    required this.moduleCode,
    required this.enabled,
    required this.createdAt,
  });

  final int id;
  final int shopId;
  final String moduleCode;
  final bool enabled;
  final int createdAt;
}

class CalculatorProductData {
  const CalculatorProductData({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.calculatorType,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.serverId,
  });

  final int id;
  final int shopId;
  final int productId;
  final String calculatorType;
  final Map<String, dynamic> metadata;
  final int createdAt;
  final int updatedAt;
  final int version;
  final String? serverId;

  CalculatorProductData copyWith({
    int? id,
    int? shopId,
    int? productId,
    String? calculatorType,
    Map<String, dynamic>? metadata,
    int? createdAt,
    int? updatedAt,
    int? version,
    String? serverId,
  }) {
    return CalculatorProductData(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      productId: productId ?? this.productId,
      calculatorType: calculatorType ?? this.calculatorType,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      serverId: serverId ?? this.serverId,
    );
  }
}

class CalculatorHistoryEntry {
  const CalculatorHistoryEntry({
    required this.id,
    required this.shopId,
    required this.calculatorType,
    required this.input,
    required this.result,
    required this.isFavorite,
    this.label,
    required this.createdAt,
    required this.createdBy,
    this.version = 1,
    this.serverId,
  });

  final int id;
  final int shopId;
  final String calculatorType;
  final Map<String, dynamic> input;
  final Map<String, dynamic> result;
  final bool isFavorite;
  final String? label;
  final int createdAt;
  final int createdBy;
  final int version;
  final String? serverId;

  CalculatorHistoryEntry copyWith({
    int? id,
    int? shopId,
    String? calculatorType,
    Map<String, dynamic>? input,
    Map<String, dynamic>? result,
    bool? isFavorite,
    String? label,
    int? createdAt,
    int? createdBy,
    int? version,
    String? serverId,
  }) {
    return CalculatorHistoryEntry(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      calculatorType: calculatorType ?? this.calculatorType,
      input: input ?? this.input,
      result: result ?? this.result,
      isFavorite: isFavorite ?? this.isFavorite,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      version: version ?? this.version,
      serverId: serverId ?? this.serverId,
    );
  }
}
