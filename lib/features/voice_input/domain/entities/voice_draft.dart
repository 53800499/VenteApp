import 'package:equatable/equatable.dart';

enum VoiceIntentKind {
  sale,
  expense,
  debtPayment,
  fxOperation,
  procurementOrder,
  receivePurchase,
  createProduct,
  createCategory,
  stockQuery,
  stockAdviceQuery,
  fxBalanceQuery,
  fxMarginQuery,
  expenseReportQuery,
  cashExplainQuery,
  debtCriticalQuery,
  unknown,
}

enum VoicePreviewAction { save, editForm, cancel }

/// Actions après une réponse Q&A V3.
enum VoiceAnswerAction { openScreen, anotherCommand, done }

extension VoiceIntentKindX on VoiceIntentKind {
  String get labelFr => switch (this) {
        VoiceIntentKind.sale => 'Vente',
        VoiceIntentKind.expense => 'Dépense',
        VoiceIntentKind.debtPayment => 'Paiement de dette',
        VoiceIntentKind.fxOperation => 'Bureau de change',
        VoiceIntentKind.procurementOrder => 'Commande fournisseur',
        VoiceIntentKind.receivePurchase => 'Réception commande',
        VoiceIntentKind.createProduct => 'Nouveau produit',
        VoiceIntentKind.createCategory => 'Nouvelle catégorie',
        VoiceIntentKind.stockQuery => 'Stock',
        VoiceIntentKind.stockAdviceQuery => 'Conseil stock',
        VoiceIntentKind.fxBalanceQuery => 'Solde change',
        VoiceIntentKind.fxMarginQuery => 'Marge change',
        VoiceIntentKind.expenseReportQuery => 'Dépenses du jour',
        VoiceIntentKind.cashExplainQuery => 'Explication caisse',
        VoiceIntentKind.debtCriticalQuery => 'Dettes critiques',
        VoiceIntentKind.unknown => 'Non reconnu',
      };

  bool get isQuery => switch (this) {
        VoiceIntentKind.stockQuery ||
        VoiceIntentKind.stockAdviceQuery ||
        VoiceIntentKind.fxBalanceQuery ||
        VoiceIntentKind.fxMarginQuery ||
        VoiceIntentKind.expenseReportQuery ||
        VoiceIntentKind.cashExplainQuery ||
        VoiceIntentKind.debtCriticalQuery =>
          true,
        _ => false,
      };

  /// Intents qui passent par un workflow conversationnel Phase 2.
  /// La vente est guidée sur l’écran panier (produit → qté → prix).
  bool get usesWorkflow => switch (this) {
        VoiceIntentKind.debtPayment ||
        VoiceIntentKind.fxOperation ||
        VoiceIntentKind.receivePurchase =>
          true,
        _ => false,
      };
}

/// Brouillon générique après parsing + matching.
sealed class VoiceDraft extends Equatable {
  const VoiceDraft({
    required this.transcript,
    required this.missingFields,
  });

  final String transcript;
  final List<String> missingFields;

  bool get canSave => missingFields.isEmpty;

  VoiceIntentKind get kind;
}

class VoiceSaleLine extends Equatable {
  const VoiceSaleLine({
    this.productId,
    this.productName,
    this.rawProductQuery,
    this.quantity,
    this.unitPrice,
    this.lineTotal,
    this.stockAvailable,
  });

  final int? productId;
  final String? productName;
  final String? rawProductQuery;
  final int? quantity;
  final int? unitPrice;
  final int? lineTotal;
  final int? stockAvailable;

  int? get resolvedUnitPrice {
    if (unitPrice != null && unitPrice! > 0) return unitPrice;
    if (lineTotal != null && quantity != null && quantity! > 0) {
      return (lineTotal! / quantity!).round();
    }
    return null;
  }

  bool get isComplete =>
      productId != null &&
      quantity != null &&
      quantity! > 0 &&
      resolvedUnitPrice != null &&
      resolvedUnitPrice! > 0;

  @override
  List<Object?> get props => [
        productId,
        productName,
        rawProductQuery,
        quantity,
        unitPrice,
        lineTotal,
        stockAvailable,
      ];
}

class VoiceSaleDraft extends VoiceDraft {
  const VoiceSaleDraft({
    required super.transcript,
    required super.missingFields,
    this.customerId,
    this.customerName,
    this.rawCustomerQuery,
    this.lines = const [],
  });

  final int? customerId;
  final String? customerName;
  final String? rawCustomerQuery;
  final List<VoiceSaleLine> lines;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.sale;

  /// Compat : première ligne du panier.
  int? get productId => lines.isEmpty ? null : lines.first.productId;
  String? get productName => lines.isEmpty ? null : lines.first.productName;
  String? get rawProductQuery =>
      lines.isEmpty ? null : lines.first.rawProductQuery;
  int? get quantity => lines.isEmpty ? null : lines.first.quantity;
  int? get unitPrice => lines.isEmpty ? null : lines.first.unitPrice;
  int? get lineTotal => lines.isEmpty ? null : lines.first.lineTotal;
  int? get stockAvailable =>
      lines.isEmpty ? null : lines.first.stockAvailable;

  int? get resolvedUnitPrice =>
      lines.isEmpty ? null : lines.first.resolvedUnitPrice;

  int get cartCount => lines.length;

  int? get cartTotal {
    if (lines.isEmpty) return null;
    var sum = 0;
    for (final line in lines) {
      final t = line.lineTotal ??
          ((line.resolvedUnitPrice ?? 0) * (line.quantity ?? 0));
      if (t <= 0) return null;
      sum += t;
    }
    return sum;
  }

  VoiceSaleDraft copyWith({
    List<String>? missingFields,
    int? customerId,
    String? customerName,
    String? rawCustomerQuery,
    List<VoiceSaleLine>? lines,
    bool clearCustomer = false,
  }) {
    return VoiceSaleDraft(
      transcript: transcript,
      missingFields: missingFields ?? this.missingFields,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      rawCustomerQuery:
          clearCustomer ? null : (rawCustomerQuery ?? this.rawCustomerQuery),
      lines: lines ?? this.lines,
    );
  }

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        customerId,
        customerName,
        rawCustomerQuery,
        lines,
      ];
}

class VoiceCreateProductDraft extends VoiceDraft {
  const VoiceCreateProductDraft({
    required super.transcript,
    required super.missingFields,
    this.name,
    this.priceSell,
    this.priceBuy,
    this.categoryId,
    this.categoryName,
    this.rawCategoryQuery,
    this.sku,
    this.quantity,
    this.alertThreshold,
  });

  final String? name;
  final int? priceSell;
  final int? priceBuy;
  final int? categoryId;
  final String? categoryName;
  final String? rawCategoryQuery;
  final String? sku;
  final int? quantity;
  final int? alertThreshold;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.createProduct;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        name,
        priceSell,
        priceBuy,
        categoryId,
        categoryName,
        rawCategoryQuery,
        sku,
        quantity,
        alertThreshold,
      ];
}

class VoiceCreateCategoryDraft extends VoiceDraft {
  const VoiceCreateCategoryDraft({
    required super.transcript,
    required super.missingFields,
    this.name,
    this.description,
  });

  final String? name;
  final String? description;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.createCategory;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        name,
        description,
      ];
}

class VoiceExpenseDraft extends VoiceDraft {
  const VoiceExpenseDraft({
    required super.transcript,
    required super.missingFields,
    this.title,
    this.amount,
    this.categoryId,
    this.categoryName,
    this.rawCategoryQuery,
  });

  final String? title;
  final int? amount;
  final int? categoryId;
  final String? categoryName;
  final String? rawCategoryQuery;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.expense;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        title,
        amount,
        categoryId,
        categoryName,
        rawCategoryQuery,
      ];
}

class VoiceDebtPaymentDraft extends VoiceDraft {
  const VoiceDebtPaymentDraft({
    required super.transcript,
    required super.missingFields,
    this.customerId,
    this.customerName,
    this.rawCustomerQuery,
    this.debtId,
    this.amount,
    this.amountRemaining,
    this.multipleDebts = false,
  });

  final int? customerId;
  final String? customerName;
  final String? rawCustomerQuery;
  final int? debtId;
  final int? amount;
  final int? amountRemaining;
  final bool multipleDebts;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.debtPayment;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        customerId,
        customerName,
        rawCustomerQuery,
        debtId,
        amount,
        amountRemaining,
        multipleDebts,
      ];
}

class VoiceFxDraft extends VoiceDraft {
  const VoiceFxDraft({
    required super.transcript,
    required super.missingFields,
    this.operationTypeCode,
    this.foreignCurrency,
    this.fromCurrency,
    this.toCurrency,
    this.fromAmount,
    this.toAmount,
    this.sessionId,
    this.rateLabel,
  });

  /// `sell` ou `buy`
  final String? operationTypeCode;
  final String? foreignCurrency;
  final String? fromCurrency;
  final String? toCurrency;
  final int? fromAmount;
  final int? toAmount;
  final int? sessionId;
  final String? rateLabel;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.fxOperation;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        operationTypeCode,
        foreignCurrency,
        fromCurrency,
        toCurrency,
        fromAmount,
        toAmount,
        sessionId,
        rateLabel,
      ];
}

class VoiceProcurementDraft extends VoiceDraft {
  const VoiceProcurementDraft({
    required super.transcript,
    required super.missingFields,
    this.supplierId,
    this.supplierName,
    this.rawSupplierQuery,
    this.productId,
    this.productName,
    this.rawProductQuery,
    this.quantity,
  });

  final int? supplierId;
  final String? supplierName;
  final String? rawSupplierQuery;
  final int? productId;
  final String? productName;
  final String? rawProductQuery;
  final int? quantity;

  /// V2 : pas d'enregistrement direct multi-lignes.
  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.procurementOrder;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        supplierId,
        supplierName,
        rawSupplierQuery,
        productId,
        productName,
        rawProductQuery,
        quantity,
      ];
}

/// Brouillon réception (Phase 2) — confirmation avant receiveItems.
class VoiceReceivePurchaseDraft extends VoiceDraft {
  const VoiceReceivePurchaseDraft({
    required super.transcript,
    required super.missingFields,
    this.poId,
    this.poNumber,
    this.supplierName,
    this.purchaseOrderItemId,
    this.productId,
    this.productName,
    this.quantityReceived,
    this.unitCost,
    this.remainingBefore,
  });

  final int? poId;
  final String? poNumber;
  final String? supplierName;
  final int? purchaseOrderItemId;
  final int? productId;
  final String? productName;
  final int? quantityReceived;
  final int? unitCost;
  final int? remainingBefore;

  @override
  bool get canSave =>
      missingFields.isEmpty &&
      poId != null &&
      purchaseOrderItemId != null &&
      productId != null &&
      quantityReceived != null &&
      quantityReceived! > 0 &&
      unitCost != null;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.receivePurchase;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        poId,
        poNumber,
        supplierName,
        purchaseOrderItemId,
        productId,
        productName,
        quantityReceived,
        unitCost,
        remainingBefore,
      ];
}

class VoiceUnknownDraft extends VoiceDraft {
  const VoiceUnknownDraft({
    required super.transcript,
    this.hint =
        'Essayez : « produit Sac quantité 20 », « Koffi paie », '
        '« le camion est arrivé », « échange… », « reste de… ».',
  }) : super(missingFields: const ['intention']);

  final String hint;

  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.unknown;

  @override
  List<Object?> get props => [transcript, missingFields, hint];
}

/// Question stock : « Combien me reste-t-il de ciment ? »
class VoiceStockQueryDraft extends VoiceDraft {
  const VoiceStockQueryDraft({
    required super.transcript,
    required super.missingFields,
    this.productId,
    this.productName,
    this.rawProductQuery,
    this.quantityInStock,
  });

  final int? productId;
  final String? productName;
  final String? rawProductQuery;
  final int? quantityInStock;

  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.stockQuery;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        productId,
        productName,
        rawProductQuery,
        quantityInStock,
      ];

  VoiceStockQueryDraft copyWith({
    List<String>? missingFields,
    int? productId,
    String? productName,
    String? rawProductQuery,
    int? quantityInStock,
  }) {
    return VoiceStockQueryDraft(
      transcript: transcript,
      missingFields: missingFields ?? this.missingFields,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      rawProductQuery: rawProductQuery ?? this.rawProductQuery,
      quantityInStock: quantityInStock ?? this.quantityInStock,
    );
  }
}

/// Question solde FX : « Quel est mon solde en nairas ? »
class VoiceFxBalanceQueryDraft extends VoiceDraft {
  const VoiceFxBalanceQueryDraft({
    required super.transcript,
    required super.missingFields,
    this.currencyCode,
    this.balanceAmount,
    this.hasOpenSession = false,
  });

  final String? currencyCode;
  final int? balanceAmount;
  final bool hasOpenSession;

  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.fxBalanceQuery;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        currencyCode,
        balanceAmount,
        hasOpenSession,
      ];

  VoiceFxBalanceQueryDraft copyWith({
    List<String>? missingFields,
    String? currencyCode,
    int? balanceAmount,
    bool? hasOpenSession,
  }) {
    return VoiceFxBalanceQueryDraft(
      transcript: transcript,
      missingFields: missingFields ?? this.missingFields,
      currencyCode: currencyCode ?? this.currencyCode,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      hasOpenSession: hasOpenSession ?? this.hasOpenSession,
    );
  }
}

class VoiceExpenseReportLine extends Equatable {
  const VoiceExpenseReportLine({
    required this.title,
    required this.amount,
  });

  final String title;
  final int amount;

  @override
  List<Object?> get props => [title, amount];
}

/// Rapport dépenses : « Montre les dépenses d’aujourd’hui »
class VoiceExpenseReportDraft extends VoiceDraft {
  const VoiceExpenseReportDraft({
    required super.transcript,
    required super.missingFields,
    required this.fromMs,
    required this.toMs,
    this.periodLabel = 'aujourd’hui',
    this.totalAmount = 0,
    this.count = 0,
    this.lines = const [],
  });

  final int fromMs;
  final int toMs;
  final String periodLabel;
  final int totalAmount;
  final int count;
  final List<VoiceExpenseReportLine> lines;

  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.expenseReportQuery;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        fromMs,
        toMs,
        periodLabel,
        totalAmount,
        count,
        lines,
      ];

  VoiceExpenseReportDraft copyWith({
    List<String>? missingFields,
    int? totalAmount,
    int? count,
    List<VoiceExpenseReportLine>? lines,
  }) {
    return VoiceExpenseReportDraft(
      transcript: transcript,
      missingFields: missingFields ?? this.missingFields,
      fromMs: fromMs,
      toMs: toMs,
      periodLabel: periodLabel,
      totalAmount: totalAmount ?? this.totalAmount,
      count: count ?? this.count,
      lines: lines ?? this.lines,
    );
  }
}

class VoiceStockAdviceLine extends Equatable {
  const VoiceStockAdviceLine({
    required this.productId,
    required this.name,
    required this.quantityInStock,
    required this.alertThreshold,
    required this.suggestedQty,
  });

  final int productId;
  final String name;
  final int quantityInStock;
  final int alertThreshold;
  final int suggestedQty;

  @override
  List<Object?> get props => [
        productId,
        name,
        quantityInStock,
        alertThreshold,
        suggestedQty,
      ];
}

/// Copilote stock : « Qu’est-ce que je dois commander ? »
class VoiceStockAdviceDraft extends VoiceDraft {
  const VoiceStockAdviceDraft({
    required super.transcript,
    required super.missingFields,
    this.lines = const [],
    this.enriched = false,
  });

  final List<VoiceStockAdviceLine> lines;
  final bool enriched;

  int get count => lines.length;

  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.stockAdviceQuery;

  @override
  List<Object?> get props => [transcript, missingFields, lines, enriched];

  VoiceStockAdviceDraft copyWith({
    List<String>? missingFields,
    List<VoiceStockAdviceLine>? lines,
    bool? enriched,
  }) {
    return VoiceStockAdviceDraft(
      transcript: transcript,
      missingFields: missingFields ?? this.missingFields,
      lines: lines ?? this.lines,
      enriched: enriched ?? this.enriched,
    );
  }
}

/// Copilote caisse : « Pourquoi ma caisse est faible ? »
class VoiceCashExplainDraft extends VoiceDraft {
  const VoiceCashExplainDraft({
    required super.transcript,
    required super.missingFields,
    this.hasOpenSession = false,
    this.openingCash = 0,
    this.salesCash = 0,
    this.expensesCash = 0,
    this.depositsCash = 0,
    this.withdrawalsCash = 0,
    this.saleCount = 0,
    this.expectedCash = 0,
    this.driverLines = const [],
    this.enriched = false,
  });

  final bool hasOpenSession;
  final int openingCash;
  final int salesCash;
  final int expensesCash;
  final int depositsCash;
  final int withdrawalsCash;
  final int saleCount;
  final int expectedCash;
  final List<String> driverLines;
  final bool enriched;

  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.cashExplainQuery;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        hasOpenSession,
        openingCash,
        salesCash,
        expensesCash,
        depositsCash,
        withdrawalsCash,
        saleCount,
        expectedCash,
        driverLines,
        enriched,
      ];

  VoiceCashExplainDraft copyWith({
    List<String>? missingFields,
    bool? hasOpenSession,
    int? openingCash,
    int? salesCash,
    int? expensesCash,
    int? depositsCash,
    int? withdrawalsCash,
    int? saleCount,
    int? expectedCash,
    List<String>? driverLines,
    bool? enriched,
  }) {
    return VoiceCashExplainDraft(
      transcript: transcript,
      missingFields: missingFields ?? this.missingFields,
      hasOpenSession: hasOpenSession ?? this.hasOpenSession,
      openingCash: openingCash ?? this.openingCash,
      salesCash: salesCash ?? this.salesCash,
      expensesCash: expensesCash ?? this.expensesCash,
      depositsCash: depositsCash ?? this.depositsCash,
      withdrawalsCash: withdrawalsCash ?? this.withdrawalsCash,
      saleCount: saleCount ?? this.saleCount,
      expectedCash: expectedCash ?? this.expectedCash,
      driverLines: driverLines ?? this.driverLines,
      enriched: enriched ?? this.enriched,
    );
  }
}

/// Copilote FX : « Quelle est ma marge change aujourd’hui ? »
class VoiceFxMarginDraft extends VoiceDraft {
  const VoiceFxMarginDraft({
    required super.transcript,
    required super.missingFields,
    this.hasOpenSession = false,
    this.totalMarginFcfa = 0,
    this.operationCount = 0,
    this.enriched = false,
  });

  final bool hasOpenSession;
  final int totalMarginFcfa;
  final int operationCount;
  final bool enriched;

  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.fxMarginQuery;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        hasOpenSession,
        totalMarginFcfa,
        operationCount,
        enriched,
      ];

  VoiceFxMarginDraft copyWith({
    List<String>? missingFields,
    bool? hasOpenSession,
    int? totalMarginFcfa,
    int? operationCount,
    bool? enriched,
  }) {
    return VoiceFxMarginDraft(
      transcript: transcript,
      missingFields: missingFields ?? this.missingFields,
      hasOpenSession: hasOpenSession ?? this.hasOpenSession,
      totalMarginFcfa: totalMarginFcfa ?? this.totalMarginFcfa,
      operationCount: operationCount ?? this.operationCount,
      enriched: enriched ?? this.enriched,
    );
  }
}

class VoiceDebtCriticalLine extends Equatable {
  const VoiceDebtCriticalLine({
    required this.customerId,
    required this.customerName,
    required this.balanceDue,
    this.openDebtsCount,
    this.daysSinceActivity,
  });

  final int customerId;
  final String customerName;
  final int balanceDue;
  final int? openDebtsCount;
  final int? daysSinceActivity;

  @override
  List<Object?> get props => [
        customerId,
        customerName,
        balanceDue,
        openDebtsCount,
        daysSinceActivity,
      ];
}

/// Copilote : « Quelles sont les dettes critiques ? »
class VoiceDebtCriticalDraft extends VoiceDraft {
  const VoiceDebtCriticalDraft({
    required super.transcript,
    required super.missingFields,
    this.lines = const [],
    this.totalBalanceDue = 0,
    this.enriched = false,
  });

  final List<VoiceDebtCriticalLine> lines;
  final int totalBalanceDue;
  final bool enriched;

  int get count => lines.length;

  @override
  bool get canSave => false;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.debtCriticalQuery;

  @override
  List<Object?> get props => [
        transcript,
        missingFields,
        lines,
        totalBalanceDue,
        enriched,
      ];

  VoiceDebtCriticalDraft copyWith({
    List<String>? missingFields,
    List<VoiceDebtCriticalLine>? lines,
    int? totalBalanceDue,
    bool? enriched,
  }) {
    return VoiceDebtCriticalDraft(
      transcript: transcript,
      missingFields: missingFields ?? this.missingFields,
      lines: lines ?? this.lines,
      totalBalanceDue: totalBalanceDue ?? this.totalBalanceDue,
      enriched: enriched ?? this.enriched,
    );
  }
}

class VoiceMatchCandidate extends Equatable {
  const VoiceMatchCandidate({
    required this.id,
    required this.label,
    required this.score,
  });

  final int id;
  final String label;
  final double score;

  @override
  List<Object?> get props => [id, label, score];
}
