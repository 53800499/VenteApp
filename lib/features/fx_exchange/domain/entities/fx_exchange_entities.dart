import 'package:equatable/equatable.dart';

const fxBaseCurrency = 'XOF';
const fxModuleCode = 'FX_EXCHANGE';

enum FxSessionStatus {
  open,
  closed;

  String get code => name;

  static FxSessionStatus fromCode(String code) => switch (code) {
        'closed' => FxSessionStatus.closed,
        _ => FxSessionStatus.open,
      };

  String get label => switch (this) {
        FxSessionStatus.open => 'Ouverte',
        FxSessionStatus.closed => 'Clôturée',
      };
}

enum FxOperationType {
  buy,
  sell,
  adjustment;

  String get code => name;

  static FxOperationType fromCode(String code) => switch (code) {
        'buy' => FxOperationType.buy,
        'adjustment' => FxOperationType.adjustment,
        _ => FxOperationType.sell,
      };

  String get label => switch (this) {
        FxOperationType.buy => 'Achat devise',
        FxOperationType.sell => 'Vente devise',
        FxOperationType.adjustment => 'Ajustement',
      };
}

enum FxMovementType {
  deposit,
  withdrawal,
  adjustment;

  String get code => name;

  static FxMovementType fromCode(String code) => switch (code) {
        'withdrawal' => FxMovementType.withdrawal,
        'adjustment' => FxMovementType.adjustment,
        _ => FxMovementType.deposit,
      };

  String get label => switch (this) {
        FxMovementType.deposit => 'Dépôt',
        FxMovementType.withdrawal => 'Retrait',
        FxMovementType.adjustment => 'Ajustement',
      };
}

class FxCurrency extends Equatable {
  const FxCurrency({
    required this.code,
    required this.label,
    required this.symbol,
    required this.minorUnit,
    required this.sortOrder,
  });

  final String code;
  final String label;
  final String symbol;
  final int minorUnit;
  final int sortOrder;

  @override
  List<Object?> get props => [code, label, symbol, minorUnit, sortOrder];
}

class FxShopCurrency extends Equatable {
  const FxShopCurrency({
    required this.id,
    required this.shopId,
    required this.currencyCode,
    required this.enabled,
    required this.sortOrder,
  });

  final int id;
  final int shopId;
  final String currencyCode;
  final bool enabled;
  final int sortOrder;

  @override
  List<Object?> get props => [id, shopId, currencyCode, enabled, sortOrder];
}

class FxRateSnapshot extends Equatable {
  const FxRateSnapshot({
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

  @override
  List<Object?> get props => [
        id,
        shopId,
        quoteCurrency,
        buyRateNumerator,
        buyRateDenominator,
        sellRateNumerator,
        sellRateDenominator,
        effectiveAt,
      ];
}

class FxSessionBalance extends Equatable {
  const FxSessionBalance({
    required this.id,
    required this.sessionId,
    required this.shopId,
    required this.currencyCode,
    required this.openingBalance,
    this.expectedBalance,
    this.countedBalance,
    this.difference,
  });

  final int id;
  final int sessionId;
  final int shopId;
  final String currencyCode;
  final int openingBalance;
  final int? expectedBalance;
  final int? countedBalance;
  final int? difference;

  @override
  List<Object?> get props =>
      [id, sessionId, currencyCode, openingBalance, expectedBalance];
}

class FxSession extends Equatable {
  const FxSession({
    required this.id,
    required this.shopId,
    required this.openedBy,
    required this.openedByName,
    this.closedBy,
    this.closedByName,
    required this.openedAt,
    this.closedAt,
    required this.status,
    this.closingNote,
    required this.totalMarginFcfa,
    required this.operationCount,
    required this.balances,
  });

  final int id;
  final int shopId;
  final int openedBy;
  final String openedByName;
  final int? closedBy;
  final String? closedByName;
  final int openedAt;
  final int? closedAt;
  final FxSessionStatus status;
  final String? closingNote;
  final int totalMarginFcfa;
  final int operationCount;
  final List<FxSessionBalance> balances;

  bool get isOpen => status == FxSessionStatus.open;

  @override
  List<Object?> get props => [id, shopId, status, openedAt, closedAt];
}

class FxSessionListRow extends Equatable {
  const FxSessionListRow({
    required this.id,
    required this.openedAt,
    this.closedAt,
    required this.openedByName,
    required this.status,
    required this.totalMarginFcfa,
    required this.operationCount,
  });

  final int id;
  final int openedAt;
  final int? closedAt;
  final String openedByName;
  final FxSessionStatus status;
  final int totalMarginFcfa;
  final int operationCount;

  @override
  List<Object?> get props => [id, openedAt, status];
}

class FxOperation extends Equatable {
  const FxOperation({
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
    this.note,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  final int id;
  final int shopId;
  final int sessionId;
  final FxOperationType operationType;
  final String fromCurrency;
  final int fromAmount;
  final String toCurrency;
  final int toAmount;
  final int? rateSnapshotId;
  final int marginFcfa;
  final String? note;
  final int createdBy;
  final String createdByName;
  final int createdAt;

  @override
  List<Object?> get props => [id, operationType, fromCurrency, toCurrency, createdAt];
}

class FxMovement extends Equatable {
  const FxMovement({
    required this.id,
    required this.shopId,
    required this.sessionId,
    required this.currencyCode,
    required this.movementType,
    required this.amount,
    this.note,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  final int id;
  final int shopId;
  final int sessionId;
  final String currencyCode;
  final FxMovementType movementType;
  final int amount;
  final String? note;
  final int createdBy;
  final String createdByName;
  final int createdAt;

  @override
  List<Object?> get props => [id, currencyCode, movementType, amount, createdAt];
}

class OpenFxSessionInput {
  const OpenFxSessionInput({required this.openingBalances});

  final Map<String, int> openingBalances;
}

class CloseFxSessionInput {
  const CloseFxSessionInput({
    required this.countedBalances,
    this.closingNote,
  });

  final Map<String, int> countedBalances;
  final String? closingNote;
}

class CreateFxRateInput {
  const CreateFxRateInput({
    required this.quoteCurrency,
    required this.buyRateNumerator,
    required this.buyRateDenominator,
    required this.sellRateNumerator,
    required this.sellRateDenominator,
  });

  final String quoteCurrency;
  final int buyRateNumerator;
  final int buyRateDenominator;
  final int sellRateNumerator;
  final int sellRateDenominator;
}

class CreateFxOperationInput {
  const CreateFxOperationInput({
    required this.operationType,
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
    required this.toAmount,
    this.note,
  });

  final FxOperationType operationType;
  final String fromCurrency;
  final int fromAmount;
  final String toCurrency;
  final int toAmount;
  final String? note;
}

class CreateFxMovementInput {
  const CreateFxMovementInput({
    required this.currencyCode,
    required this.movementType,
    required this.amount,
    this.note,
  });

  final String currencyCode;
  final FxMovementType movementType;
  final int amount;
  final String? note;
}

class FxOperationPreview {
  const FxOperationPreview({
    required this.toAmount,
    required this.marginFcfa,
    required this.rateSnapshotId,
    required this.appliedRateNumerator,
    required this.appliedRateDenominator,
    required this.quoteCurrency,
  });

  final int toAmount;
  final int marginFcfa;
  final int rateSnapshotId;
  final int appliedRateNumerator;
  final int appliedRateDenominator;
  final String quoteCurrency;
}

class FxDailyReport extends Equatable {
  const FxDailyReport({
    required this.session,
    required this.operations,
    required this.movements,
    required this.liveBalances,
    required this.volumeByCurrency,
  });

  final FxSession session;
  final List<FxOperation> operations;
  final List<FxMovement> movements;
  final Map<String, int> liveBalances;
  final Map<String, int> volumeByCurrency;

  @override
  List<Object?> get props => [session.id, operations.length, movements.length];
}

class UpsertFxShopCurrencyInput {
  const UpsertFxShopCurrencyInput({
    required this.currencyCode,
    required this.enabled,
    required this.sortOrder,
  });

  final String currencyCode;
  final bool enabled;
  final int sortOrder;
}
