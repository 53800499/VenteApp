import '../../../../core/utils/benin_period_range.dart';
import '../entities/voice_draft.dart';
import '../entities/voice_intent_detection.dart';
import 'entity_matcher.dart';
import 'voice_intent_router.dart';

class VoiceCatalogProduct {
  const VoiceCatalogProduct({
    required this.id,
    required this.name,
    required this.priceSell,
    required this.quantityInStock,
  });

  final int id;
  final String name;
  final int priceSell;
  final int quantityInStock;
}

class VoiceCatalogCustomer {
  const VoiceCatalogCustomer({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

class VoiceCatalogCategory {
  const VoiceCatalogCategory({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

class VoiceCatalogSupplier {
  const VoiceCatalogSupplier({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

class VoiceCatalogOpenDebt {
  const VoiceCatalogOpenDebt({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amountRemaining,
  });

  final int id;
  final int customerId;
  final String customerName;
  final int amountRemaining;
}

class VoiceFxRateInfo {
  const VoiceFxRateInfo({
    required this.quoteCurrency,
    required this.buyNumerator,
    required this.buyDenominator,
    required this.sellNumerator,
    required this.sellDenominator,
  });

  final String quoteCurrency;
  final int buyNumerator;
  final int buyDenominator;
  final int sellNumerator;
  final int sellDenominator;
}

/// Ligne vente dictée en une phrase structurée.
class VoiceStructuredSaleLine {
  const VoiceStructuredSaleLine({
    required this.productQuery,
    required this.quantity,
    this.unitPrice,
  });

  final String productQuery;
  final int quantity;

  /// Null → utiliser le prix de vente boutique.
  final int? unitPrice;
}

/// Produit dicté : « nom Ciment prix vente 5000 ».
class VoiceStructuredProductLine {
  const VoiceStructuredProductLine({
    required this.name,
    this.priceSell,
    this.priceBuy,
    this.categoryQuery,
    this.sku,
    this.quantity,
    this.alertThreshold,
  });

  final String name;
  final int? priceSell;
  final int? priceBuy;
  final String? categoryQuery;
  final String? sku;
  final int? quantity;
  final int? alertThreshold;
}

/// Catégorie dictée : « nom Boissons » / « catégorie Boissons ».
class VoiceStructuredCategoryLine {
  const VoiceStructuredCategoryLine({
    required this.name,
    this.description,
  });

  final String name;
  final String? description;
}

/// Parsing déterministe FR → brouillon métier.
class VoiceIntentParser {
  VoiceIntentParser({
    EntityMatcher? matcher,
    VoiceIntentRouter? router,
  })  : _matcher = matcher ?? const EntityMatcher(),
        _router = router ?? const VoiceIntentRouter();

  final EntityMatcher _matcher;
  final VoiceIntentRouter _router;

  /// Résout un produit catalogue à partir d’un nom (ou courte phrase).
  VoiceCatalogProduct? matchProductByName(
    String query,
    List<VoiceCatalogProduct> products,
  ) {
    final q = query.trim();
    if (q.isEmpty || products.isEmpty) return null;
    final match = _matcher.bestMatch(
      query: q,
      items: products.map((p) => (id: p.id, label: p.name)).toList(),
    );
    if (match == null) return null;
    for (final p in products) {
      if (p.id == match.id) return p;
    }
    return null;
  }

  /// Phrase structurée (ordre libre pour quantité / prix) :
  /// « produit Sac quantité 20 prix 3000 »
  /// « produit Sac prix 3000 quantité 20 »
  /// « produit Sac quantité 20 » (prix boutique).
  VoiceStructuredSaleLine? parseStructuredSaleLine(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    final qtyRe = RegExp(
      r'quantit[eé]\s+(\d{1,9}|un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\b',
      caseSensitive: false,
    );
    final priceRe = RegExp(
      r'prix(?:\s+unitaire)?\s+(\d{1,3}(?:[\s.\u00a0]\d{3})+|\d+)\b',
      caseSensitive: false,
    );

    final qtyMatch = qtyRe.firstMatch(lower);
    if (qtyMatch == null) return null;

    final qtyRaw = qtyMatch.group(1)!.toLowerCase();
    final qty = int.tryParse(qtyRaw) ?? _wordNumbers[qtyRaw];
    if (qty == null || qty <= 0) return null;

    final priceMatch = priceRe.firstMatch(lower);
    int? price;
    if (priceMatch != null) {
      final priceDigits =
          priceMatch.group(1)!.replaceAll(RegExp(r'[\s.\u00a0]'), '');
      price = int.tryParse(priceDigits);
      if (price == null || price <= 0) price = null;
    }

    // Nom produit : après « produit », avant le 1er champ quantité/prix.
    final firstFieldStart = priceMatch == null
        ? qtyMatch.start
        : (qtyMatch.start < priceMatch.start
            ? qtyMatch.start
            : priceMatch.start);
    var productSlice = lower.substring(0, firstFieldStart).trim();
    productSlice = productSlice
        .replaceFirst(RegExp(r'^produit\s+', caseSensitive: false), '')
        .trim();
    productSlice = productSlice
        .replaceAll(RegExp(r'[,;]+$'), '')
        .replaceAll(RegExp(r'\s+et$'), '')
        .trim();
    if (productSlice.isEmpty) return null;

    return VoiceStructuredSaleLine(
      productQuery: productSlice,
      quantity: qty,
      unitPrice: price,
    );
  }

  /// « nom Ciment prix vente 5000 » (+ optionnel prix achat, catégorie, stock…).
  VoiceStructuredProductLine? parseStructuredProductLine(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    final sellRe = RegExp(
      r'prix\s+(?:de\s+)?vente\s+(\d{1,3}(?:[\s.\u00a0]\d{3})+|\d+)\b',
      caseSensitive: false,
    );
    // Guillemets doubles : l’apostrophe dans d’achat casse une raw string '.
    final buyRe = RegExp(
      r"prix\s+(?:de\s+|d['’]?\s*)?achat\s+(\d{1,3}(?:[\s.\u00a0]\d{3})+|\d+)\b",
      caseSensitive: false,
    );
    // Sans lookbehind (non supporté ici) : « prix 5000 » seulement
    // (pas « prix vente … » / « prix achat … », déjà capturés ci-dessus).
    final plainPriceRe = RegExp(
      r'\bprix\s+(\d{1,3}(?:[\s.\u00a0]\d{3})+|\d+)\b',
      caseSensitive: false,
    );
    final catRe = RegExp(
      r'cat[eé]gorie\s+(.+?)(?=\s+(?:prix|stock|quantit|alerte|r[eé]f[eé]rence|sku)\b|$)',
      caseSensitive: false,
    );
    final stockRe = RegExp(
      r'(?:stock|quantit[eé])\s+(\d{1,9})\b',
      caseSensitive: false,
    );
    final alertRe = RegExp(
      r'alerte\s+(\d{1,9})\b',
      caseSensitive: false,
    );
    final skuRe = RegExp(
      r'(?:r[eé]f[eé]rence|sku)\s+([A-Za-z0-9][\w-]{0,40})\b',
      caseSensitive: false,
    );

    final sellMatch = sellRe.firstMatch(lower);
    final buyMatch = buyRe.firstMatch(lower);
    final plainMatch =
        sellMatch == null ? plainPriceRe.firstMatch(lower) : null;
    final catMatch = catRe.firstMatch(lower);
    final stockMatch = stockRe.firstMatch(lower);
    final alertMatch = alertRe.firstMatch(lower);
    final skuMatch = skuRe.firstMatch(lower);

    int? parseAmt(RegExpMatch? m) {
      if (m == null) return null;
      final digits = m.group(1)!.replaceAll(RegExp(r'[\s.\u00a0]'), '');
      final n = int.tryParse(digits);
      return (n != null && n > 0) ? n : null;
    }

    final priceSell = parseAmt(sellMatch) ?? parseAmt(plainMatch);
    final priceBuy = parseAmt(buyMatch);
    final quantity = stockMatch == null
        ? null
        : int.tryParse(stockMatch.group(1)!);
    final alert = alertMatch == null
        ? null
        : int.tryParse(alertMatch.group(1)!);
    final sku = skuMatch?.group(1)?.trim();
    var categoryQuery = catMatch?.group(1)?.trim();
    if (categoryQuery != null) {
      categoryQuery = categoryQuery
          .replaceAll(RegExp(r'[,;]+$'), '')
          .trim();
      if (categoryQuery.isEmpty) categoryQuery = null;
    }

    // Nom : après « nom », avant le 1er champ connu.
    final fieldStarts = <int>[
      if (sellMatch != null) sellMatch.start,
      if (buyMatch != null) buyMatch.start,
      if (plainMatch != null) plainMatch.start,
      if (catMatch != null) catMatch.start,
      if (stockMatch != null) stockMatch.start,
      if (alertMatch != null) alertMatch.start,
      if (skuMatch != null) skuMatch.start,
    ];
    final firstField =
        fieldStarts.isEmpty ? lower.length : fieldStarts.reduce((a, b) => a < b ? a : b);

    var nameSlice = text.substring(0, firstField).trim();
    nameSlice = nameSlice
        .replaceFirst(
          RegExp(
            r'^(?:nouveau\s+)?produit\s+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    nameSlice = nameSlice
        .replaceFirst(RegExp(r'^nom\s+', caseSensitive: false), '')
        .trim();
    nameSlice = nameSlice
        .replaceAll(RegExp(r'[,;]+$'), '')
        .trim();
    if (nameSlice.length < 2) return null;

    // Catégorie : conserver la casse d’origine pour le formulaire.
    String? categoryOriginal;
    if (catMatch != null) {
      categoryOriginal = text
          .substring(catMatch.start, catMatch.end)
          .replaceFirst(
            RegExp(r'^cat[eé]gorie\s+', caseSensitive: false),
            '',
          )
          .replaceAll(RegExp(r'[,;]+$'), '')
          .trim();
      if (categoryOriginal.isEmpty) categoryOriginal = null;
    }

    return VoiceStructuredProductLine(
      name: nameSlice,
      priceSell: priceSell,
      priceBuy: priceBuy,
      categoryQuery: categoryOriginal ?? categoryQuery,
      sku: sku,
      quantity: quantity,
      alertThreshold: alert,
    );
  }

  /// « nom Boissons » / « catégorie Boissons description … ».
  VoiceStructuredCategoryLine? parseStructuredCategoryLine(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    final descRe = RegExp(
      r'description\s+(.+)$',
      caseSensitive: false,
    );
    final descMatch = descRe.firstMatch(lower);
    final description = descMatch == null
        ? null
        : text
            .substring(descMatch.start)
            .replaceFirst(
              RegExp(r'^description\s+', caseSensitive: false),
              '',
            )
            .trim();

    var body = descMatch == null
        ? text
        : text.substring(0, descMatch.start).trim();
    body = body
        .replaceFirst(
          RegExp(
            r'^(?:nouvelle?\s+)?cat[eé]gorie\s+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    body = body
        .replaceFirst(RegExp(r'^nom\s+', caseSensitive: false), '')
        .trim();
    body = body.replaceAll(RegExp(r'[,;]+$'), '').trim();
    if (body.length < 2) return null;

    return VoiceStructuredCategoryLine(
      name: body,
      description: (description == null || description.isEmpty)
          ? null
          : description,
    );
  }

  static final _digitAmount = RegExp(
    r'(\d{1,3}(?:[\s.\u00a0]\d{3})+|\d+)\s*(?:fcfa|f\s*cfa|francs?|f|naira|nairas|ngn|dollar|dollars|usd|euro|euros|eur)?',
    caseSensitive: false,
  );

  static final _wordNumbers = <String, int>{
    'un': 1,
    'une': 1,
    'deux': 2,
    'trois': 3,
    'quatre': 4,
    'cinq': 5,
    'six': 6,
    'sept': 7,
    'huit': 8,
    'neuf': 9,
    'dix': 10,
    'onze': 11,
    'douze': 12,
    'treize': 13,
    'quatorze': 14,
    'quinze': 15,
    'seize': 16,
    'vingt': 20,
    'trente': 30,
    'quarante': 40,
    'cinquante': 50,
    'soixante': 60,
    'cent': 100,
    'cents': 100,
    'mille': 1000,
  };

  VoiceIntentKind detectIntent(String transcript) => _router.detect(transcript);

  VoiceIntentDetection detectDetailed(String transcript) =>
      _router.detectDetailed(transcript);

  VoiceDraft parse({
    required String transcript,
    VoiceIntentKind? expectedKind,
    List<VoiceCatalogProduct> products = const [],
    List<VoiceCatalogCustomer> customers = const [],
    List<VoiceCatalogCategory> categories = const [],
    List<VoiceCatalogSupplier> suppliers = const [],
    List<VoiceCatalogOpenDebt> openDebts = const [],
    List<VoiceFxRateInfo> fxRates = const [],
    int? fxSessionId,
  }) {
    final text = transcript.trim();
    final lower = text.toLowerCase();
    final kind = expectedKind ?? _router.detect(text);

    return switch (kind) {
      VoiceIntentKind.expense => _parseExpense(text, lower, categories),
      VoiceIntentKind.debtPayment =>
        _parseDebt(text, lower, customers, openDebts),
      VoiceIntentKind.fxOperation =>
        _parseFx(text, lower, fxRates, fxSessionId),
      VoiceIntentKind.procurementOrder =>
        _parseProcurement(text, lower, products, suppliers),
      VoiceIntentKind.receivePurchase => VoiceReceivePurchaseDraft(
          transcript: text,
          missingFields: const ['commande'],
        ),
      VoiceIntentKind.sale => _parseSale(text, lower, products, customers),
      VoiceIntentKind.createProduct =>
        _parseCreateProduct(text, lower, categories),
      VoiceIntentKind.createCategory => _parseCreateCategory(text),
      VoiceIntentKind.stockQuery => _parseStockQuery(text, lower, products),
      VoiceIntentKind.stockAdviceQuery => VoiceStockAdviceDraft(
          transcript: text,
          missingFields: const [],
        ),
      VoiceIntentKind.fxBalanceQuery => _parseFxBalanceQuery(text, lower),
      VoiceIntentKind.fxMarginQuery => VoiceFxMarginDraft(
          transcript: text,
          missingFields: const [],
        ),
      VoiceIntentKind.expenseReportQuery => _parseExpenseReport(text),
      VoiceIntentKind.cashExplainQuery => VoiceCashExplainDraft(
          transcript: text,
          missingFields: const [],
        ),
      VoiceIntentKind.debtCriticalQuery => VoiceDebtCriticalDraft(
          transcript: text,
          missingFields: const [],
        ),
      VoiceIntentKind.unknown => VoiceUnknownDraft(transcript: text),
    };
  }

  VoiceCreateProductDraft _parseCreateProduct(
    String transcript,
    String lower,
    List<VoiceCatalogCategory> categories,
  ) {
    final structured = parseStructuredProductLine(transcript);
    if (structured == null) {
      return VoiceCreateProductDraft(
        transcript: transcript,
        missingFields: const ['nom', 'prix vente'],
      );
    }
    int? categoryId;
    String? categoryName;
    if (structured.categoryQuery != null) {
      final match = _matcher.bestMatch(
        query: structured.categoryQuery!,
        items: categories.map((c) => (id: c.id, label: c.name)).toList(),
      );
      if (match != null) {
        categoryId = match.id;
        categoryName = match.label;
      }
    }
    final missing = <String>[];
    if (structured.name.trim().length < 2) missing.add('nom');
    if (structured.priceSell == null || structured.priceSell! <= 0) {
      missing.add('prix vente');
    }
    return VoiceCreateProductDraft(
      transcript: transcript,
      missingFields: missing,
      name: structured.name,
      priceSell: structured.priceSell,
      priceBuy: structured.priceBuy,
      categoryId: categoryId,
      categoryName: categoryName,
      rawCategoryQuery: structured.categoryQuery,
      sku: structured.sku,
      quantity: structured.quantity,
      alertThreshold: structured.alertThreshold,
    );
  }

  VoiceCreateCategoryDraft _parseCreateCategory(String transcript) {
    final structured = parseStructuredCategoryLine(transcript);
    if (structured == null) {
      return VoiceCreateCategoryDraft(
        transcript: transcript,
        missingFields: const ['nom'],
      );
    }
    return VoiceCreateCategoryDraft(
      transcript: transcript,
      missingFields: structured.name.trim().length < 2
          ? const ['nom']
          : const [],
      name: structured.name,
      description: structured.description,
    );
  }

  VoiceStockQueryDraft _parseStockQuery(
    String transcript,
    String lower,
    List<VoiceCatalogProduct> products,
  ) {
    var rawProduct = _extractStockProductQuery(lower, transcript);
    rawProduct ??= _extractProductQuery(lower, transcript);

    // Dernier recours : retirer les mots outils et matcher le reste
    if (rawProduct == null || rawProduct.isEmpty) {
      final cleaned = lower
          .replaceAll(
            RegExp(
              r'\b(combien|me|reste|t|il|de|du|des|le|la|les|mon|ma|mes|stock|quantit[eé]|y|a|à)\b',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length >= 2) rawProduct = _cleanPhrase(cleaned);
    }

    final productMatch = rawProduct == null
        ? null
        : _matcher.bestMatch(
            query: rawProduct,
            items: products.map((p) => (id: p.id, label: p.name)).toList(),
          );

    int? stock;
    if (productMatch != null) {
      for (final p in products) {
        if (p.id == productMatch.id) {
          stock = p.quantityInStock;
          break;
        }
      }
    }

    final missing = <String>[];
    if (productMatch == null) missing.add('produit');

    return VoiceStockQueryDraft(
      transcript: transcript,
      missingFields: missing,
      productId: productMatch?.id,
      productName: productMatch?.label ?? rawProduct,
      rawProductQuery: rawProduct,
      quantityInStock: stock,
    );
  }

  VoiceFxBalanceQueryDraft _parseFxBalanceQuery(
    String transcript,
    String lower,
  ) {
    final currency = _detectForeignCurrency(lower);
    final missing = <String>[];
    if (currency == null) missing.add('devise');

    return VoiceFxBalanceQueryDraft(
      transcript: transcript,
      missingFields: missing,
      currencyCode: currency,
    );
  }

  VoiceExpenseReportDraft _parseExpenseReport(String transcript) {
    final period = resolveReportPeriod(preset: ReportPeriodPreset.today);
    return VoiceExpenseReportDraft(
      transcript: transcript,
      missingFields: const [],
      fromMs: period.fromMs,
      toMs: period.toMs,
      periodLabel: 'aujourd’hui',
    );
  }

  String? _extractStockProductQuery(String lower, String transcript) {
    final patterns = [
      RegExp(
        r'(?:reste[- ]?t?[- ]?il|reste)\s+(?:de\s+)?(.+)$',
        caseSensitive: false,
      ),
      RegExp(r'(?:stock|quantit[eé])\s+(?:de\s+)?(.+)$', caseSensitive: false),
      RegExp(
        r'combien\s+(?:de\s+|me\s+reste[- ]?t?[- ]?il\s+(?:de\s+)?)(.+)$',
        caseSensitive: false,
      ),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(lower);
      if (m != null) {
        var q = _cleanPhrase(m.group(1)!);
        q = q.replaceAll(
          RegExp(
            r'\b(me|reste|t|il|encore|aujourd.?hui)\b',
            caseSensitive: false,
          ),
          ' ',
        );
        q = _cleanPhrase(q);
        if (q.length >= 2) return q;
      }
    }

    // Essayer sur le transcript original (casse)
    final de = RegExp(
      r'\bde\s+([A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9\s-]{1,40})$',
      caseSensitive: false,
    ).firstMatch(transcript);
    if (de != null) return _cleanPhrase(de.group(1)!);

    return null;
  }

  VoiceExpenseDraft _parseExpense(
    String transcript,
    String lower,
    List<VoiceCatalogCategory> categories,
  ) {
    final amount = _extractAmount(lower);
    String? title;
    String? rawCategory;

    final pourLe = RegExp(
      r"pour\s+(?:le|la|les|l')?\s*(.+)$",
      caseSensitive: false,
    ).firstMatch(transcript);
    if (pourLe != null) {
      title = _cleanPhrase(pourLe.group(1)!);
      rawCategory = title;
    }

    title ??= _guessExpenseTitle(lower);
    rawCategory ??= title;

    final catMatch = rawCategory == null
        ? null
        : _matcher.bestMatch(
            query: rawCategory,
            items: categories.map((c) => (id: c.id, label: c.name)).toList(),
            minScore: 0.35,
          );

    final missing = <String>[];
    if (title == null || title.length < 2) missing.add('titre');
    if (amount == null || amount <= 0) missing.add('montant');

    return VoiceExpenseDraft(
      transcript: transcript,
      missingFields: missing,
      title: title,
      amount: amount,
      categoryId: catMatch?.id,
      categoryName: catMatch?.label,
      rawCategoryQuery: rawCategory,
    );
  }

  VoiceDebtPaymentDraft _parseDebt(
    String transcript,
    String lower,
    List<VoiceCatalogCustomer> customers,
    List<VoiceCatalogOpenDebt> openDebts,
  ) {
    final amount = _extractAmount(lower);
    final rawCustomer = _extractNamedEntity(transcript, customers);

    final customerMatch = rawCustomer == null
        ? null
        : _matcher.bestMatch(
            query: rawCustomer,
            items: customers.map((c) => (id: c.id, label: c.name)).toList(),
            minScore: 0.40,
          );

    final customerId = customerMatch?.id;
    final customerDebts = customerId == null
        ? const <VoiceCatalogOpenDebt>[]
        : openDebts.where((d) => d.customerId == customerId).toList();

    int? debtId;
    int? remaining;
    var multiple = false;
    if (customerDebts.length == 1) {
      debtId = customerDebts.first.id;
      remaining = customerDebts.first.amountRemaining;
    } else if (customerDebts.length > 1) {
      multiple = true;
      final sorted = [...customerDebts]
        ..sort((a, b) => b.amountRemaining.compareTo(a.amountRemaining));
      debtId = sorted.first.id;
      remaining = sorted.first.amountRemaining;
    }

    final missing = <String>[];
    if (customerId == null) missing.add('client');
    if (debtId == null) missing.add('dette');
    final payAmount = amount ?? remaining;
    if (payAmount == null || payAmount <= 0) missing.add('montant');
    if (multiple) {
      // On peut quand même enregistrer sur la dette principale, mais on signale
    }

    return VoiceDebtPaymentDraft(
      transcript: transcript,
      missingFields: missing,
      customerId: customerId,
      customerName: customerMatch?.label ?? rawCustomer,
      rawCustomerQuery: rawCustomer,
      debtId: debtId,
      amount: payAmount,
      amountRemaining: remaining,
      multipleDebts: multiple,
    );
  }

  VoiceFxDraft _parseFx(
    String transcript,
    String lower,
    List<VoiceFxRateInfo> rates,
    int? sessionId,
  ) {
    final isBuy = RegExp(r'\b(ach[eè]te|acheter|achat)\b').hasMatch(lower);
    final op = isBuy ? 'buy' : 'sell';

    final foreign = _detectForeignCurrency(lower);
    final amount = _extractAmount(lower);

    String? fromCurrency;
    String? toCurrency;
    int? toAmount;
    String? rateLabel;

    if (foreign != null) {
      if (op == 'sell') {
        fromCurrency = 'XOF';
        toCurrency = foreign;
      } else {
        fromCurrency = foreign;
        toCurrency = 'XOF';
      }

      VoiceFxRateInfo? rate;
      for (final r in rates) {
        if (r.quoteCurrency.toUpperCase() == foreign) {
          rate = r;
          break;
        }
      }
      if (rate != null && amount != null && amount > 0) {
        if (op == 'sell') {
          toAmount =
              (amount * rate.sellDenominator) ~/ rate.sellNumerator;
          rateLabel =
              '${rate.sellDenominator} $foreign = ${rate.sellNumerator} FCFA';
        } else {
          toAmount = (amount * rate.buyNumerator) ~/ rate.buyDenominator;
          rateLabel =
              '${rate.buyDenominator} $foreign = ${rate.buyNumerator} FCFA';
        }
      }
    }

    final missing = <String>[];
    if (foreign == null) missing.add('devise');
    if (amount == null || amount <= 0) missing.add('montant');
    if (sessionId == null) missing.add('session FX');
    if (toAmount == null) missing.add('taux');

    return VoiceFxDraft(
      transcript: transcript,
      missingFields: missing,
      operationTypeCode: op,
      foreignCurrency: foreign,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      fromAmount: amount,
      toAmount: toAmount,
      sessionId: sessionId,
      rateLabel: rateLabel,
    );
  }

  VoiceProcurementDraft _parseProcurement(
    String transcript,
    String lower,
    List<VoiceCatalogProduct> products,
    List<VoiceCatalogSupplier> suppliers,
  ) {
    var quantity = _extractQuantity(lower);
    quantity ??= int.tryParse(RegExp(r'\b(\d+)\b').firstMatch(lower)?.group(1) ?? '');
    quantity ??= 1;

    String? rawSupplier;
    final chez = RegExp(
      r"\bchez\s+([A-Za-zÀ-ÿ0-9][\wÀ-ÿ0-9'-]{1,40})",
      caseSensitive: false,
    ).firstMatch(transcript);
    if (chez != null) rawSupplier = chez.group(1);

    for (final s in suppliers) {
      if (RegExp(
        r'\b' + RegExp.escape(s.name) + r'\b',
        caseSensitive: false,
      ).hasMatch(transcript)) {
        rawSupplier = s.name;
        break;
      }
    }

    String? rawProduct = _extractProductQuery(lower, transcript);
    final cmd = RegExp(
      r'commande(?:r)?\s+(?:\d+\s+)?(?:tonnes?\s+de\s+|sacs?\s+de\s+)?([a-z0-9à-ÿ\s-]{2,40})',
      caseSensitive: false,
    ).firstMatch(lower);
    if (rawProduct == null && cmd != null) {
      rawProduct = _cleanPhrase(cmd.group(1)!);
    }

    final supplierMatch = rawSupplier == null
        ? null
        : _matcher.bestMatch(
            query: rawSupplier,
            items: suppliers.map((s) => (id: s.id, label: s.name)).toList(),
            minScore: 0.35,
          );

    final productMatch = rawProduct == null
        ? null
        : _matcher.bestMatch(
            query: rawProduct,
            items: products.map((p) => (id: p.id, label: p.name)).toList(),
          );

    final missing = <String>[];
    if (productMatch == null) missing.add('produit');
    if (quantity <= 0) missing.add('quantité');

    return VoiceProcurementDraft(
      transcript: transcript,
      missingFields: missing,
      supplierId: supplierMatch?.id,
      supplierName: supplierMatch?.label ?? rawSupplier,
      rawSupplierQuery: rawSupplier,
      productId: productMatch?.id,
      productName: productMatch?.label ?? rawProduct,
      rawProductQuery: rawProduct,
      quantity: quantity,
    );
  }

  VoiceSaleDraft _parseSale(
    String transcript,
    String lower,
    List<VoiceCatalogProduct> products,
    List<VoiceCatalogCustomer> customers,
  ) {
    final amount = _extractAmount(lower);

    String? rawCustomer = _extractNamedEntity(transcript, customers);
    if (rawCustomer == null) {
      final aClient = RegExp(
        r"(?:à|a)\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ'-]{1,40})(?=\s+(?:à|a)\s+\d|\s+franc|\s*$)",
        caseSensitive: false,
      ).firstMatch(transcript);
      if (aClient != null) {
        final candidate = aClient.group(1)!;
        if (!RegExp(
          r'^(sacs?|boites?|kg|tonnes?|francs?|fcfa)$',
          caseSensitive: false,
        ).hasMatch(candidate)) {
          rawCustomer = candidate;
        }
      }
    }
    final clientNamed = RegExp(
      r"\bclient\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ'-]{1,40})",
      caseSensitive: false,
    ).firstMatch(transcript);
    if (clientNamed != null) {
      rawCustomer = clientNamed.group(1);
    }

    final customerMatch = rawCustomer == null
        ? null
        : _matcher.bestMatch(
            query: rawCustomer,
            items: customers.map((c) => (id: c.id, label: c.name)).toList(),
            minScore: 0.40,
          );

    var body = lower;
    if (rawCustomer != null) {
      body = body.replaceAll(
        RegExp(
          r"(?:à|a|client)\s+" + RegExp.escape(rawCustomer.toLowerCase()),
          caseSensitive: false,
        ),
        ' ',
      );
    }
    body = body.replaceAll(
      RegExp(
        r'(\d{1,3}(?:[\s.\u00a0]\d{3})+|\d+)\s*(?:fcfa|f\s*cfa|francs?|f)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    body = body.replaceAll(RegExp(r'\s+'), ' ').trim();

    final segments = _splitSaleLineSegments(body);
    final lines = <VoiceSaleLine>[];
    for (var i = 0; i < segments.length; i++) {
      final line = _parseSaleLineSegment(
        segments[i],
        products,
        sharedAmount: amount,
        applySharedAmount: segments.length == 1,
      );
      if (line.rawProductQuery != null ||
          line.productId != null ||
          (line.quantity != null && line.quantity! > 0)) {
        lines.add(line);
      }
    }

    if (lines.isEmpty) {
      final fallback = _parseSaleLineSegment(
        body,
        products,
        sharedAmount: amount,
        applySharedAmount: true,
      );
      lines.add(fallback);
    }

    final missing = <String>[];
    if (lines.every((l) => l.productId == null)) {
      missing.add('produit');
    } else {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.productId == null) {
          missing.add('produit${lines.length > 1 ? ' ${i + 1}' : ''}');
        }
        if (l.quantity == null || l.quantity! <= 0) {
          missing.add('quantité${lines.length > 1 ? ' ${i + 1}' : ''}');
        }
        if (l.resolvedUnitPrice == null || l.resolvedUnitPrice! <= 0) {
          missing.add('prix${lines.length > 1 ? ' ${i + 1}' : ''}');
        }
      }
    }

    return VoiceSaleDraft(
      transcript: transcript,
      missingFields: missing,
      customerId: customerMatch?.id,
      customerName: customerMatch?.label ?? rawCustomer,
      rawCustomerQuery: rawCustomer,
      lines: lines,
    );
  }

  /// Découpe « 5 sacs de ciment et 2 sacs de riz ».
  List<String> _splitSaleLineSegments(String lower) {
    final re = RegExp(
      r'\s+(?:et|puis|avec)\s+(?=(?:\d+|un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\b)|,\s*(?=\d+\b)',
      caseSensitive: false,
    );
    final parts =
        lower.split(re).map((s) => s.trim()).where((s) => s.isNotEmpty);
    return parts.toList();
  }

  VoiceSaleLine _parseSaleLineSegment(
    String segment,
    List<VoiceCatalogProduct> products, {
    int? sharedAmount,
    required bool applySharedAmount,
  }) {
    final quantity = _extractQuantity(segment) ?? 1;
    var rawProduct = _extractProductQuery(segment, segment);
    if (rawProduct == null || rawProduct.isEmpty) {
      var q = segment;
      q = q.replaceFirst(
        RegExp(
          r'^(?:je\s+)?(?:vends?|vendre|vendu|vendue|facture|facturer|achete|acheter|donne|donner|sors|sortir)\s+',
          caseSensitive: false,
        ),
        '',
      );
      q = q.replaceFirst(
        RegExp(
          r'^(?:\d+|un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\s+',
          caseSensitive: false,
        ),
        '',
      );
      q = q.replaceFirst(
        RegExp(
          r'^(?:sacs?|boites?|kg|tonnes?|unites?|unités?|pieces?|pièces?)\s+(?:de\s+)?',
          caseSensitive: false,
        ),
        '',
      );
      q = _cleanPhrase(q);
      if (q.isNotEmpty) rawProduct = q;
    }

    final productMatch = rawProduct == null
        ? null
        : _matcher.bestMatch(
            query: rawProduct,
            items: products.map((p) => (id: p.id, label: p.name)).toList(),
          );

    int? unitPrice;
    int? lineTotal;
    int? stock;
    VoiceCatalogProduct? catalog;
    if (productMatch != null) {
      for (final p in products) {
        if (p.id == productMatch.id) {
          catalog = p;
          stock = p.quantityInStock;
          break;
        }
      }
    }

    if (applySharedAmount && sharedAmount != null) {
      if (catalog != null &&
          (sharedAmount - catalog.priceSell).abs() <=
              (catalog.priceSell * 0.15).round().clamp(500, 50000)) {
        unitPrice = sharedAmount;
        lineTotal = sharedAmount * quantity;
      } else if (quantity > 1) {
        lineTotal = sharedAmount;
        unitPrice = (sharedAmount / quantity).round();
      } else {
        unitPrice = sharedAmount;
        lineTotal = sharedAmount;
      }
    } else if (catalog != null) {
      unitPrice = catalog.priceSell;
      lineTotal = catalog.priceSell * quantity;
    }

    return VoiceSaleLine(
      productId: productMatch?.id,
      productName: productMatch?.label ?? rawProduct,
      rawProductQuery: rawProduct,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      stockAvailable: stock,
    );
  }

  String? _extractNamedEntity(
    String transcript,
    List<VoiceCatalogCustomer> customers,
  ) {
    for (final c in customers) {
      if (RegExp(
        r'\b' + RegExp.escape(c.name) + r'\b',
        caseSensitive: false,
      ).hasMatch(transcript)) {
        return c.name;
      }
    }
    return null;
  }

  String? _detectForeignCurrency(String lower) {
    if (RegExp(r'\b(naira|nairas|ngn)\b').hasMatch(lower)) return 'NGN';
    if (RegExp(r'\b(dollar|dollars|usd)\b').hasMatch(lower)) return 'USD';
    if (RegExp(r'\b(euro|euros|eur)\b').hasMatch(lower)) return 'EUR';
    if (RegExp(r'\b(cedi|cedis|ghs)\b').hasMatch(lower)) return 'GHS';
    return null;
  }

  String? _extractProductQuery(String lower, String transcript) {
    final vends = RegExp(
      r'(?:vends?|vendre|vendu|vendue|vente\s+de|facture(?:r)?|achete|acheter|donne|donner|commande(?:r)?)\s+(?:\d+|un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix|[a-z-]+)\s+(?:sacs?\s+de\s+|boites?\s+de\s+|kg\s+de\s+|tonnes?\s+de\s+)?(.+?)(?:\s+(?:a|à|chez)\s+|$)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (vends != null) {
      var q = vends.group(1)!;
      q = q.replaceAll(
        RegExp(r"\s+(?:a|à|chez)\s+[a-zà-ÿ'-]+.*$", caseSensitive: false),
        '',
      );
      q = q.replaceAll(
        RegExp(r'\s+(?:a|à)\s+\d.*$', caseSensitive: false),
        '',
      );
      q = _cleanPhrase(q);
      if (q.isNotEmpty) return q;
    }

    final de = RegExp(
      r'\b(?:sacs?|boites?|kg|tonnes?)\s+de\s+([a-z0-9à-ÿ\s-]{2,40})',
      caseSensitive: false,
    ).firstMatch(lower);
    if (de != null) return _cleanPhrase(de.group(1)!);

    return null;
  }

  String? _guessExpenseTitle(String lower) {
    for (final hint in [
      'transport',
      'loyer',
      'salaire',
      'carburant',
      'electricite',
      'électricité',
      'eau',
      'fourniture',
      'maintenance',
    ]) {
      if (lower.contains(hint)) {
        return hint[0].toUpperCase() + hint.substring(1);
      }
    }
    return null;
  }

  int? _extractAmount(String lower) {
    final matches = _digitAmount.allMatches(lower).toList();
    if (matches.isNotEmpty) {
      int? best;
      for (final m in matches) {
        final raw = m.group(1)!.replaceAll(RegExp(r'[\s.\u00a0]'), '');
        final n = int.tryParse(raw);
        if (n == null) continue;
        if (n >= 100 && (best == null || n > best)) best = n;
      }
      if (best != null) return best;
      final raw =
          matches.last.group(1)!.replaceAll(RegExp(r'[\s.\u00a0]'), '');
      return int.tryParse(raw);
    }

    final mille = RegExp(
      r'((?:[a-z-]+\s*){1,6})mille',
      caseSensitive: false,
    ).firstMatch(lower);
    if (mille != null) {
      final prefix = _parseWordNumber(mille.group(1)!.trim());
      if (prefix != null) return prefix * 1000;
      return 1000;
    }

    return null;
  }

  int? _extractQuantity(String lower) {
    final digitQty = RegExp(
      r'\b(\d+)\s+(?:sacs?|boites?|unites?|unités?|kg|pieces?|pièces?|tonnes?)\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (digitQty != null) return int.tryParse(digitQty.group(1)!);

    final wordQty = RegExp(
      r'\b(un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix|onze|douze|quinze|vingt)\s+(?:sacs?|boites?|unites?|unités?|kg|pieces?|pièces?|tonnes?)?\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (wordQty != null) {
      return _wordNumbers[wordQty.group(1)!.toLowerCase()];
    }

    final vendsN = RegExp(
      r'(?:vends?|vendre|commande(?:r)?)\s+(\d+)\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (vendsN != null) return int.tryParse(vendsN.group(1)!);

    final vendsW = RegExp(
      r'(?:vends?|vendre)\s+(un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (vendsW != null) {
      return _wordNumbers[vendsW.group(1)!.toLowerCase()];
    }

    return null;
  }

  int? _parseWordNumber(String phrase) {
    final parts = phrase
        .toLowerCase()
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && p != 'et')
        .toList();
    if (parts.isEmpty) return null;

    var total = 0;
    var current = 0;
    for (final p in parts) {
      final v = _wordNumbers[p];
      if (v == null) continue;
      if (v == 100) {
        current = (current == 0 ? 1 : current) * 100;
      } else if (v == 1000) {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
      } else {
        current += v;
      }
    }
    total += current;
    return total > 0 ? total : null;
  }

  String _cleanPhrase(String input) {
    var s = input.trim();
    s = s.replaceAll(
      RegExp(
        r'\b(?:fcfa|francs?|f|naira|nairas|ngn|dollar|dollars|usd|euro|euros|eur)\b',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(RegExp(r'\d[\d\s.]*'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(
      RegExp(
        r"^(le|la|les|du|de|des|un|une|d')\s+",
        caseSensitive: false,
      ),
      '',
    );
    return s.trim();
  }
}
