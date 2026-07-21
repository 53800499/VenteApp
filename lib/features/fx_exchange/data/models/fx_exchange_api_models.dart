class FxModuleStatusDto {
  FxModuleStatusDto({required this.enabled});

  factory FxModuleStatusDto.fromJson(Map<String, dynamic> json) {
    return FxModuleStatusDto(enabled: json['enabled'] as bool? ?? false);
  }

  final bool enabled;
}

class FxCurrencyDto {
  FxCurrencyDto({
    required this.code,
    required this.label,
    required this.symbol,
    required this.minorUnit,
    required this.sortOrder,
  });

  factory FxCurrencyDto.fromJson(Map<String, dynamic> json) {
    return FxCurrencyDto(
      code: json['code'] as String,
      label: json['label'] as String,
      symbol: json['symbol'] as String,
      minorUnit: (json['minorUnit'] as num?)?.toInt() ??
          (json['minor_unit'] as num?)?.toInt() ??
          0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ??
          (json['sort_order'] as num?)?.toInt() ??
          0,
    );
  }

  final String code;
  final String label;
  final String symbol;
  final int minorUnit;
  final int sortOrder;
}

class FxShopCurrencyDto {
  FxShopCurrencyDto({
    required this.id,
    required this.shopId,
    required this.currencyCode,
    required this.enabled,
    required this.sortOrder,
  });

  factory FxShopCurrencyDto.fromJson(Map<String, dynamic> json) {
    return FxShopCurrencyDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num?)?.toInt() ??
          (json['shop_id'] as num).toInt(),
      currencyCode: json['currencyCode'] as String? ??
          json['currency_code'] as String,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ??
          (json['sort_order'] as num?)?.toInt() ??
          0,
    );
  }

  final int id;
  final int shopId;
  final String currencyCode;
  final bool enabled;
  final int sortOrder;
}

class FxRateSnapshotDto {
  FxRateSnapshotDto({
    required this.id,
    required this.shopId,
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.buyRateNumerator,
    required this.buyRateDenominator,
    required this.sellRateNumerator,
    required this.sellRateDenominator,
    required this.effectiveAt,
    required this.createdBy,
    required this.createdAt,
  });

  factory FxRateSnapshotDto.fromJson(Map<String, dynamic> json) {
    return FxRateSnapshotDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num?)?.toInt() ??
          (json['shop_id'] as num).toInt(),
      baseCurrency: json['baseCurrency'] as String? ??
          json['base_currency'] as String? ??
          'XOF',
      quoteCurrency: json['quoteCurrency'] as String? ??
          json['quote_currency'] as String,
      buyRateNumerator: (json['buyRateNumerator'] as num?)?.toInt() ??
          (json['buy_rate_numerator'] as num).toInt(),
      buyRateDenominator: (json['buyRateDenominator'] as num?)?.toInt() ??
          (json['buy_rate_denominator'] as num).toInt(),
      sellRateNumerator: (json['sellRateNumerator'] as num?)?.toInt() ??
          (json['sell_rate_numerator'] as num).toInt(),
      sellRateDenominator: (json['sellRateDenominator'] as num?)?.toInt() ??
          (json['sell_rate_denominator'] as num).toInt(),
      effectiveAt: (json['effectiveAt'] as num?)?.toInt() ??
          (json['effective_at'] as num).toInt(),
      createdBy: (json['createdBy'] as num?)?.toInt() ??
          (json['created_by'] as num).toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          (json['created_at'] as num).toInt(),
    );
  }

  final int id;
  final int shopId;
  final String baseCurrency;
  final String quoteCurrency;
  final int buyRateNumerator;
  final int buyRateDenominator;
  final int sellRateNumerator;
  final int sellRateDenominator;
  final int effectiveAt;
  final int createdBy;
  final int createdAt;
}

class FxSessionBalanceDto {
  FxSessionBalanceDto({
    required this.currencyCode,
    required this.openingBalance,
    this.expectedBalance,
    this.countedBalance,
    this.difference,
  });

  factory FxSessionBalanceDto.fromJson(Map<String, dynamic> json) {
    return FxSessionBalanceDto(
      currencyCode: json['currencyCode'] as String? ??
          json['currency_code'] as String,
      openingBalance: (json['openingBalance'] as num?)?.toInt() ??
          (json['opening_balance'] as num?)?.toInt() ??
          0,
      expectedBalance: (json['expectedBalance'] as num?)?.toInt() ??
          (json['expected_balance'] as num?)?.toInt(),
      countedBalance: (json['countedBalance'] as num?)?.toInt() ??
          (json['counted_balance'] as num?)?.toInt(),
      difference: (json['difference'] as num?)?.toInt(),
    );
  }

  final String currencyCode;
  final int openingBalance;
  final int? expectedBalance;
  final int? countedBalance;
  final int? difference;
}

class FxSessionDto {
  FxSessionDto({
    required this.id,
    required this.shopId,
    required this.openedBy,
    this.closedBy,
    required this.openedAt,
    this.closedAt,
    required this.status,
    this.closingNote,
    required this.totalMarginFcfa,
    required this.operationCount,
    this.balances = const [],
    this.sessionRates = const [],
  });

  factory FxSessionDto.fromJson(Map<String, dynamic> json) {
    final balancesJson = json['balances'] as List<dynamic>?;
    final ratesJson = json['sessionRates'] as List<dynamic>? ??
        json['session_rates'] as List<dynamic>?;
    return FxSessionDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num?)?.toInt() ??
          (json['shop_id'] as num).toInt(),
      openedBy: (json['openedBy'] as num?)?.toInt() ??
          (json['opened_by'] as num).toInt(),
      closedBy: (json['closedBy'] as num?)?.toInt() ??
          (json['closed_by'] as num?)?.toInt(),
      openedAt: (json['openedAt'] as num?)?.toInt() ??
          (json['opened_at'] as num).toInt(),
      closedAt: (json['closedAt'] as num?)?.toInt() ??
          (json['closed_at'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'open',
      closingNote: json['closingNote'] as String? ?? json['closing_note'] as String?,
      totalMarginFcfa: (json['totalMarginFcfa'] as num?)?.toInt() ??
          (json['total_margin_fcfa'] as num?)?.toInt() ??
          0,
      operationCount: (json['operationCount'] as num?)?.toInt() ??
          (json['operation_count'] as num?)?.toInt() ??
          0,
      balances: balancesJson
              ?.map(
                (e) => FxSessionBalanceDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      sessionRates: ratesJson
              ?.map(
                (e) => FxSessionRateDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  final int id;
  final int shopId;
  final int openedBy;
  final int? closedBy;
  final int openedAt;
  final int? closedAt;
  final String status;
  final String? closingNote;
  final int totalMarginFcfa;
  final int operationCount;
  final List<FxSessionBalanceDto> balances;
  final List<FxSessionRateDto> sessionRates;
}

class FxSessionRateDto {
  FxSessionRateDto({
    required this.quoteCurrency,
    required this.rateSnapshotId,
    required this.appliedAt,
    this.id,
  });

  factory FxSessionRateDto.fromJson(Map<String, dynamic> json) {
    return FxSessionRateDto(
      id: (json['id'] as num?)?.toInt(),
      quoteCurrency: json['quoteCurrency'] as String? ??
          json['quote_currency'] as String,
      rateSnapshotId: (json['rateSnapshotId'] as num?)?.toInt() ??
          (json['rate_snapshot_id'] as num).toInt(),
      appliedAt: (json['appliedAt'] as num?)?.toInt() ??
          (json['applied_at'] as num?)?.toInt() ??
          0,
    );
  }

  final int? id;
  final String quoteCurrency;
  final int rateSnapshotId;
  final int appliedAt;
}

class FxOpenSessionStateDto {
  FxOpenSessionStateDto({
    this.session,
    this.liveBalances = const {},
  });

  factory FxOpenSessionStateDto.fromJson(Map<String, dynamic> json) {
    final sessionJson = json['session'];
    final live = json['liveBalances'] as Map<String, dynamic>? ??
        json['live_balances'] as Map<String, dynamic>?;
    return FxOpenSessionStateDto(
      session: sessionJson == null
          ? null
          : FxSessionDto.fromJson(sessionJson as Map<String, dynamic>),
      liveBalances: live?.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ??
          const {},
    );
  }

  final FxSessionDto? session;
  final Map<String, int> liveBalances;
}

class FxOperationDto {
  FxOperationDto({
    required this.id,
    required this.shopId,
    required this.sessionId,
    required this.operationType,
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
    required this.toAmount,
    this.rateSnapshotId,
    required this.marginFcfa,
    this.customerId,
    this.note,
    required this.createdBy,
    required this.createdAt,
  });

  factory FxOperationDto.fromJson(Map<String, dynamic> json) {
    return FxOperationDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num?)?.toInt() ??
          (json['shop_id'] as num).toInt(),
      sessionId: (json['sessionId'] as num?)?.toInt() ??
          (json['session_id'] as num).toInt(),
      operationType: json['operationType'] as String? ??
          json['operation_type'] as String,
      fromCurrency: json['fromCurrency'] as String? ??
          json['from_currency'] as String,
      fromAmount: (json['fromAmount'] as num?)?.toInt() ??
          (json['from_amount'] as num).toInt(),
      toCurrency:
          json['toCurrency'] as String? ?? json['to_currency'] as String,
      toAmount: (json['toAmount'] as num?)?.toInt() ??
          (json['to_amount'] as num).toInt(),
      rateSnapshotId: (json['rateSnapshotId'] as num?)?.toInt() ??
          (json['rate_snapshot_id'] as num?)?.toInt(),
      marginFcfa: (json['marginFcfa'] as num?)?.toInt() ??
          (json['margin_fcfa'] as num?)?.toInt() ??
          0,
      customerId: (json['customerId'] as num?)?.toInt() ??
          (json['customer_id'] as num?)?.toInt(),
      note: json['note'] as String?,
      createdBy: (json['createdBy'] as num?)?.toInt() ??
          (json['created_by'] as num).toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          (json['created_at'] as num).toInt(),
    );
  }

  final int id;
  final int shopId;
  final int sessionId;
  final String operationType;
  final String fromCurrency;
  final int fromAmount;
  final String toCurrency;
  final int toAmount;
  final int? rateSnapshotId;
  final int marginFcfa;
  final int? customerId;
  final String? note;
  final int createdBy;
  final int createdAt;
}

class FxMovementDto {
  FxMovementDto({
    required this.id,
    required this.shopId,
    required this.sessionId,
    required this.currencyCode,
    required this.movementType,
    required this.amount,
    this.note,
    required this.createdBy,
    required this.createdAt,
  });

  factory FxMovementDto.fromJson(Map<String, dynamic> json) {
    return FxMovementDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num?)?.toInt() ??
          (json['shop_id'] as num).toInt(),
      sessionId: (json['sessionId'] as num?)?.toInt() ??
          (json['session_id'] as num).toInt(),
      currencyCode: json['currencyCode'] as String? ??
          json['currency_code'] as String,
      movementType: json['movementType'] as String? ??
          json['movement_type'] as String,
      amount: (json['amount'] as num).toInt(),
      note: json['note'] as String?,
      createdBy: (json['createdBy'] as num?)?.toInt() ??
          (json['created_by'] as num).toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          (json['created_at'] as num).toInt(),
    );
  }

  final int id;
  final int shopId;
  final int sessionId;
  final String currencyCode;
  final String movementType;
  final int amount;
  final String? note;
  final int createdBy;
  final int createdAt;
}

class ToggleFxModuleRequest {
  ToggleFxModuleRequest({required this.enabled});

  final bool enabled;

  Map<String, dynamic> toJson() => {'enabled': enabled};
}

class CreateFxRateRequest {
  CreateFxRateRequest({
    required this.quoteCurrency,
    required this.buyRateNumerator,
    required this.buyRateDenominator,
    required this.sellRateNumerator,
    required this.sellRateDenominator,
    this.applyMode = 'next_session',
  });

  final String quoteCurrency;
  final int buyRateNumerator;
  final int buyRateDenominator;
  final int sellRateNumerator;
  final int sellRateDenominator;
  final String applyMode;

  Map<String, dynamic> toJson() => {
        'quoteCurrency': quoteCurrency,
        'buyRateNumerator': buyRateNumerator,
        'buyRateDenominator': buyRateDenominator,
        'sellRateNumerator': sellRateNumerator,
        'sellRateDenominator': sellRateDenominator,
        'applyMode': applyMode,
      };
}

class OpenFxSessionRequest {
  OpenFxSessionRequest({required this.openingBalances});

  final List<Map<String, dynamic>> openingBalances;

  Map<String, dynamic> toJson() => {'openingBalances': openingBalances};
}

class CloseFxSessionRequest {
  CloseFxSessionRequest({
    required this.countedBalances,
    this.closingNote,
  });

  final List<Map<String, dynamic>> countedBalances;
  final String? closingNote;

  Map<String, dynamic> toJson() => {
        'countedBalances': countedBalances,
        if (closingNote != null) 'closingNote': closingNote,
      };
}

class CreateFxOperationRequest {
  CreateFxOperationRequest({
    required this.operationType,
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
    required this.toAmount,
    this.customerId,
    this.note,
  });

  final String operationType;
  final String fromCurrency;
  final int fromAmount;
  final String toCurrency;
  final int toAmount;
  final int? customerId;
  final String? note;

  Map<String, dynamic> toJson() => {
        'operationType': operationType,
        'fromCurrency': fromCurrency,
        'fromAmount': fromAmount,
        'toCurrency': toCurrency,
        'toAmount': toAmount,
        if (customerId != null) 'customerId': customerId,
        if (note != null) 'note': note,
      };
}

class CreateFxMovementRequest {
  CreateFxMovementRequest({
    required this.currencyCode,
    required this.movementType,
    required this.amount,
    this.note,
  });

  final String currencyCode;
  final String movementType;
  final int amount;
  final String? note;

  Map<String, dynamic> toJson() => {
        'currencyCode': currencyCode,
        'movementType': movementType,
        'amount': amount,
        if (note != null) 'note': note,
      };
}

class PreviewFxOperationRequest {
  PreviewFxOperationRequest({
    required this.operationType,
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
  });

  final String operationType;
  final String fromCurrency;
  final int fromAmount;
  final String toCurrency;

  Map<String, dynamic> toJson() => {
        'operationType': operationType,
        'fromCurrency': fromCurrency,
        'fromAmount': fromAmount,
        'toCurrency': toCurrency,
      };
}

class FxOperationPreviewDto {
  FxOperationPreviewDto({
    required this.toAmount,
    required this.marginFcfa,
    required this.rateSnapshotId,
    required this.appliedRateNumerator,
    required this.appliedRateDenominator,
  });

  factory FxOperationPreviewDto.fromJson(Map<String, dynamic> json) {
    final applied = json['appliedRate'] as Map<String, dynamic>?;
    return FxOperationPreviewDto(
      toAmount: (json['toAmount'] as num?)?.toInt() ??
          (json['to_amount'] as num).toInt(),
      marginFcfa: (json['marginFcfa'] as num?)?.toInt() ??
          (json['margin_fcfa'] as num?)?.toInt() ??
          0,
      rateSnapshotId: (json['rateSnapshotId'] as num?)?.toInt() ??
          (json['rate_snapshot_id'] as num).toInt(),
      appliedRateNumerator: (applied?['numerator'] as num?)?.toInt() ??
          (json['appliedRateNumerator'] as num?)?.toInt() ??
          0,
      appliedRateDenominator: (applied?['denominator'] as num?)?.toInt() ??
          (json['appliedRateDenominator'] as num?)?.toInt() ??
          1,
    );
  }

  final int toAmount;
  final int marginFcfa;
  final int rateSnapshotId;
  final int appliedRateNumerator;
  final int appliedRateDenominator;
}
