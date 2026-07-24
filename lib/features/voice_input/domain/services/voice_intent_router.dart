import '../entities/voice_draft.dart';
import '../entities/voice_intent_detection.dart';
import 'voice_intent_trigger_catalog.dart';

/// Classifie une phrase FR vers un intent métier (sans LLM).
/// Les formulations varient ; l’intent reste stable via scores + catalogue.
class VoiceIntentRouter {
  const VoiceIntentRouter();

  VoiceIntentKind detect(String transcript) => detectDetailed(transcript).kind;

  /// Détection avec confiance et alternatives (pour clarification).
  VoiceIntentDetection detectDetailed(String transcript) {
    final lower = normalize(transcript);
    if (lower.isEmpty) return VoiceIntentDetection.empty;

    final scores = <VoiceIntentKind, int>{
      VoiceIntentKind.receivePurchase: _scoreReceive(lower),
      VoiceIntentKind.stockAdviceQuery: _scoreStockAdvice(lower),
      VoiceIntentKind.cashExplainQuery: _scoreCashExplain(lower),
      VoiceIntentKind.fxMarginQuery: _scoreFxMargin(lower),
      VoiceIntentKind.debtCriticalQuery: _scoreDebtCritical(lower),
      VoiceIntentKind.stockQuery: _scoreStockQuery(lower),
      VoiceIntentKind.fxBalanceQuery: _scoreFxBalanceQuery(lower),
      VoiceIntentKind.expenseReportQuery: _scoreExpenseReport(lower),
      VoiceIntentKind.createProduct: _scoreCreateProduct(lower),
      VoiceIntentKind.createCategory: _scoreCreateCategory(lower),
      VoiceIntentKind.sale: _scoreSale(lower),
      VoiceIntentKind.expense: _scoreExpense(lower),
      VoiceIntentKind.debtPayment: _scoreDebt(lower),
      VoiceIntentKind.fxOperation: _scoreFx(lower),
      VoiceIntentKind.procurementOrder: _scoreProcurement(lower),
    };

    final ranked = scores.entries
        .where((e) => e.value > 0)
        .map(
          (e) => VoiceIntentCandidate(
            kind: e.key,
            rawScore: e.value,
            confidence: (e.value / 20.0).clamp(0.0, 1.0),
          ),
        )
        .toList()
      ..sort((a, b) => b.rawScore.compareTo(a.rawScore));

    if (ranked.isEmpty || ranked.first.rawScore < 2) {
      final weak = ranked.take(3).toList();
      return VoiceIntentDetection(
        kind: VoiceIntentKind.unknown,
        confidence: weak.isEmpty ? 0 : weak.first.confidence,
        rawScore: weak.isEmpty ? 0 : weak.first.rawScore,
        alternatives: weak,
        needsClarification: weak.length >= 2,
      );
    }

    final best = ranked.first;
    final alts = ranked.skip(1).where((c) => c.rawScore >= 2).take(3).toList();
    final second = alts.isEmpty ? null : alts.first;
    final ambiguous = second != null && (best.rawScore - second.rawScore) <= 2;
    final lowConfidence =
        best.confidence < kVoiceConfidenceClarifyThreshold;
    final needsClarification =
        alts.isNotEmpty && (lowConfidence || ambiguous);

    return VoiceIntentDetection(
      kind: best.kind,
      confidence: best.confidence,
      rawScore: best.rawScore,
      alternatives: alts,
      needsClarification: needsClarification,
    );
  }

  /// Normalise accents / apostrophes pour matcher le catalogue.
  static String normalize(String input) {
    var s = input.toLowerCase().trim();
    const pairs = <List<String>>[
      ['àâäáãåā', 'a'],
      ['éèêëēėę', 'e'],
      ['îïíīįì', 'i'],
      ['ôöòóõøō', 'o'],
      ['ûüùúū', 'u'],
      ['ÿ', 'y'],
      ['ç', 'c'],
      ['ñ', 'n'],
    ];
    for (final pair in pairs) {
      for (final ch in pair[0].split('')) {
        s = s.replaceAll(ch, pair[1]);
      }
    }
    s = s.replaceAll(RegExp('[\'\u2019\u2018`]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  int _scoreStockAdvice(String lower) {
    var s = VoiceIntentTriggerCatalog.phraseBonus(
      VoiceIntentKind.stockAdviceQuery,
      lower,
    );
    if (RegExp(
      r'\b(quoi|que)\s+(je\s+)?(dois([- ]?je)?|faut([- ]?il)?)\s+commander\b',
    ).hasMatch(lower)) {
      s += 6;
    }
    if (RegExp(r'\b(dois([- ]?je)?|faut([- ]?il)?)\s+commander\b')
        .hasMatch(lower)) {
      s += 5;
    }
    if (RegExp(r'\b(stock\s+bas|stocks?\s+bas|rupture|ruptures)\b')
        .hasMatch(lower)) {
      s += 5;
    }
    if (RegExp(r'\b(a\s+commander|recommand|conseil)\b').hasMatch(lower) &&
        RegExp(r'\b(stock|produit|commander)\b').hasMatch(lower)) {
      s += 4;
    }
    if (RegExp(r'\b(surveiller|alerte)\b').hasMatch(lower) &&
        RegExp(r'\b(stock|produit)\b').hasMatch(lower)) {
      s += 3;
    }
    if (RegExp(r'\b(qu.?est[- ]ce\s+que)\b').hasMatch(lower) &&
        RegExp(r'\bcommander\b').hasMatch(lower)) {
      s += 4;
    }
    if (RegExp(r'\bchez\b').hasMatch(lower) ||
        RegExp(r'\b(fournisseur)\b').hasMatch(lower)) {
      s -= 5;
    }
    if (RegExp(r'\b(combien|reste[- ]?t?[- ]?il)\b').hasMatch(lower) &&
        !RegExp(r'\b(commander|rupture|bas)\b').hasMatch(lower)) {
      s -= 4;
    }
    return s.clamp(0, 20);
  }

  int _scoreCashExplain(String lower) {
    var s = 0;
    final hasCaisse = RegExp(r'\b(caisse)\b').hasMatch(lower);
    if (!hasCaisse) return 0;
    if (RegExp(r'\b(pourquoi)\b').hasMatch(lower)) s += 5;
    if (RegExp(r'\b(faible|basse|bas|vide|manque)\b').hasMatch(lower)) s += 4;
    if (RegExp(r'\b(explique|explication|etat|situation)\b').hasMatch(lower)) {
      s += 4;
    }
    if (RegExp(r'\bsolde\s+(de\s+)?(la\s+)?caisse\b').hasMatch(lower)) s += 5;
    if (RegExp(r'\b(caisse)\b').hasMatch(lower) &&
        RegExp(r'\b(solde|etat|explique|pourquoi)\b').hasMatch(lower)) {
      s += 2;
    }
    if (RegExp(r'\b(naira|nairas|dollar|dollars|euro|euros|change)\b')
        .hasMatch(lower)) {
      s -= 6;
    }
    return s.clamp(0, 20);
  }

  int _scoreFxMargin(String lower) {
    var s = 0;
    final hasMarge =
        RegExp(r'\b(marge|profit|benefice)\b').hasMatch(lower);
    final hasFxContext = RegExp(
      r'\b(change|changer|echange|fx|devise|naira|dollar|euro)\b',
    ).hasMatch(lower);
    final today = RegExp(r'\b(aujourd.?hui|du jour|session)\b').hasMatch(lower);

    if (hasMarge && hasFxContext) s += 6;
    if (hasMarge && today) s += 3;
    if (RegExp(r'\b(marge)\b').hasMatch(lower) &&
        RegExp(r'\b(combien|quelle|quel|mon|ma)\b').hasMatch(lower)) {
      s += 3;
    }
    if (hasMarge && !hasFxContext && !RegExp(r'\bcaisse\b').hasMatch(lower)) {
      s += 2;
    }
    if (RegExp(r'\bsolde\b').hasMatch(lower) && !hasMarge) s -= 5;
    if (RegExp(r'\b(change|changer|echange|echanger)\b').hasMatch(lower) &&
        RegExp(r'\b(\d+|francs?|fcfa)\b').hasMatch(lower) &&
        !hasMarge) {
      s -= 4;
    }
    if (RegExp(r'\bcaisse\b').hasMatch(lower)) s -= 5;
    return s.clamp(0, 20);
  }

  int _scoreDebtCritical(String lower) {
    var s = 0;
    final hasDebt =
        RegExp(r'\b(dette|dettes|credit|debiteur|debiteurs)\b').hasMatch(lower);
    final hasCritical = RegExp(
      r'\b(critique|critiques|retard|ancienn?e|anciennes|risque|impaye)\b',
    ).hasMatch(lower);
    if (hasDebt && hasCritical) s += 6;
    if (RegExp(r'\b(clients?\s+critiques?|dettes?\s+critiques?)\b')
        .hasMatch(lower)) {
      s += 6;
    }
    if (RegExp(r'\b(qui\s+me\s+doit|qui\s+doit)\b').hasMatch(lower)) s += 4;
    if (RegExp(r'\b(montre|liste|quelles?|quels?)\b').hasMatch(lower) &&
        hasDebt &&
        hasCritical) {
      s += 2;
    }
    if (RegExp(r'\b(rembourse|rembourser|paie|payer|verse|verser)\b')
        .hasMatch(lower)) {
      s -= 6;
    }
    return s.clamp(0, 20);
  }

  int _scoreReceive(String lower) {
    var s = VoiceIntentTriggerCatalog.phraseBonus(
      VoiceIntentKind.receivePurchase,
      lower,
    );
    if (RegExp(r'\b(camion|camions)\b').hasMatch(lower)) s += 4;
    if (RegExp(r'\b(arrive|arrivee|arrives|arriver|la)\b').hasMatch(lower) &&
        RegExp(r'\b(camion|fournisseur|livraison|marchandise)\b')
            .hasMatch(lower)) {
      s += 3;
    }
    if (RegExp(r'\b(reception|receptionner|livraison|livre|livree)\b')
        .hasMatch(lower)) {
      s += 4;
    }
    if (RegExp(r'\b(recu|recue|recus|recues)\b').hasMatch(lower) &&
        RegExp(r'\b(commande|marchandise|stock|camion|livraison)\b')
            .hasMatch(lower)) {
      s += 3;
    }
    if (RegExp(r'\b(fournisseur)\b').hasMatch(lower) &&
        RegExp(r'\b(arrive|arrivee|ici|la)\b').hasMatch(lower)) {
      s += 4;
    }
    if (RegExp(r'\b(commande|commander)\b').hasMatch(lower) &&
        !RegExp(r'\b(camion|arriv|reception|livr|recu)\b').hasMatch(lower)) {
      s -= 3;
    }
    return s.clamp(0, 20);
  }

  int _scoreStockQuery(String lower) {
    var s = VoiceIntentTriggerCatalog.phraseBonus(
      VoiceIntentKind.stockQuery,
      lower,
    );
    final ask = RegExp(r'\b(combien|reste|stock|quantite)\b').hasMatch(lower);
    final resteIl = RegExp(r'reste[- ]?t?[- ]?il').hasMatch(lower);
    final stockDe = RegExp(r'\bstock\s+de\b').hasMatch(lower);
    if (ask) s += 3;
    if (resteIl) s += 3;
    if (stockDe) s += 3;
    if (RegExp(r'\b(reste|stock)\b').hasMatch(lower) &&
        !RegExp(r'\b(vends?|vendre|commande|commander)\b').hasMatch(lower)) {
      s += 2;
    }
    if (RegExp(r'\b(vends?|vendre)\b').hasMatch(lower)) s -= 4;
    if (RegExp(
      r'\b(stock\s+bas|rupture|quoi\s+commander|dois[- ]?je\s+commander)\b',
    ).hasMatch(lower)) {
      s -= 5;
    }
    return s.clamp(0, 20);
  }

  int _scoreFxBalanceQuery(String lower) {
    var s = 0;
    final hasCurrency = RegExp(
      r'\b(naira|nairas|ngn|dollar|dollars|usd|euro|euros|eur|cedi|cedis|ghs)\b',
    ).hasMatch(lower);
    final hasSolde = RegExp(r'\b(solde|combien)\b').hasMatch(lower);
    if (hasSolde && hasCurrency) s += 5;
    if (RegExp(r'\bsolde\b').hasMatch(lower)) s += 2;
    if (hasCurrency &&
        RegExp(r'\b(quel|quelle|mon|mes)\b').hasMatch(lower)) {
      s += 2;
    }
    if (RegExp(r'\b(change|changer|echange|echanger|vends?|achete)\b')
        .hasMatch(lower)) {
      s -= 5;
    }
    if (RegExp(r'\bcaisse\b').hasMatch(lower)) s -= 5;
    if (RegExp(r'\b(marge|profit|benefice)\b').hasMatch(lower)) s -= 5;
    return s.clamp(0, 20);
  }

  int _scoreExpenseReport(String lower) {
    var s = 0;
    final hasDepense = RegExp(r'\b(depense|depenses)\b').hasMatch(lower);
    if (!hasDepense) return 0;
    if (RegExp(r'\b(aujourd.?hui|du jour)\b').hasMatch(lower)) s += 4;
    if (RegExp(r'\b(montre|montrer|liste|lister|voir|affiche)\b')
        .hasMatch(lower)) {
      s += 3;
    }
    if (RegExp(r'\b(combien|total|rapport|resume)\b').hasMatch(lower)) {
      s += 2;
    }
    if (RegExp(r'\b(ajoute|ajouter|nouvelle|creer|enregistre)\b')
        .hasMatch(lower)) {
      s -= 5;
    }
    if (hasDepense &&
        RegExp(r'\b(aujourd.?hui|montre|liste|combien)\b').hasMatch(lower)) {
      s += 1;
    }
    return s.clamp(0, 20);
  }

  int _scoreCreateProduct(String lower) {
    var s = VoiceIntentTriggerCatalog.phraseBonus(
      VoiceIntentKind.createProduct,
      lower,
    );
    if (RegExp(
      r'\b(nouveau\s+produit|creer?\s+(un\s+)?produit|ajoute[r]?\s+(un\s+)?produit|enregistrer?\s+(un\s+)?produit)\b',
    ).hasMatch(lower)) {
      s += 10;
    }
    if (RegExp(r'\bnom\b').hasMatch(lower) &&
        RegExp(r'\bprix\b').hasMatch(lower) &&
        !RegExp(r'\bquantit').hasMatch(lower)) {
      s += 4;
    }
    if (RegExp(r'\b(vends?|vente|vendu)\b').hasMatch(lower)) s -= 6;
    return s.clamp(0, 20);
  }

  int _scoreCreateCategory(String lower) {
    var s = VoiceIntentTriggerCatalog.phraseBonus(
      VoiceIntentKind.createCategory,
      lower,
    );
    if (RegExp(
      r'\b(nouvelle?\s+cat[eé]gorie|creer?\s+(une\s+)?cat[eé]gorie|ajoute[r]?\s+(une\s+)?cat[eé]gorie)\b',
    ).hasMatch(lower)) {
      s += 10;
    }
    if (RegExp(r'\bcat[eé]gorie\b').hasMatch(lower) &&
        RegExp(r'\b(nom|creer|ajoute|nouvelle)\b').hasMatch(lower) &&
        !RegExp(r'\b(produit|prix|vente)\b').hasMatch(lower)) {
      s += 4;
    }
    return s.clamp(0, 20);
  }

  int _scoreSale(String lower) {
    var s = VoiceIntentTriggerCatalog.phraseBonus(
      VoiceIntentKind.sale,
      lower,
    );
    // Verbes / noms de vente courants
    if (RegExp(r'\b(vends?|vendre|vente|vendu|vendue|vendus|vendues)\b')
        .hasMatch(lower)) {
      s += 3;
    }
    if (RegExp(r'\b(facturer|facture|encaisser|encaisse)\b').hasMatch(lower) &&
        !RegExp(r'\b(fournisseur|commande)\b').hasMatch(lower)) {
      s += 3;
    }
    // Point de vue acheteur en boutique (« Koffi achète… »)
    if (RegExp(r'\b(achete|acheter|achat)\b').hasMatch(lower) &&
        !RegExp(r'\b(fournisseur|chez|appro)\b').hasMatch(lower)) {
      s += 3;
    }
    // Formulations locales fréquentes
    if (RegExp(r'\b(donne|donner|sors|sortir|prend|prendre)\b')
            .hasMatch(lower) &&
        RegExp(r'\b(sacs?|boites?|produit|kg|ciment|riz|[aà]\s+\w+)\b')
            .hasMatch(lower)) {
      s += 2;
    }
    if (RegExp(r'\b(sacs?|boites?|produit|kg)\b').hasMatch(lower)) s += 1;
    if (lower.contains('client')) s += 1;
    if (RegExp(r'\b(francs?|fcfa|\d+)\b').hasMatch(lower) &&
        RegExp(r'\b(vends?|vendre|vente|vendu|facture|achete)\b')
            .hasMatch(lower)) {
      s += 1;
    }

    // Pas une vente produit
    if (RegExp(r'\b(naira|nairas|ngn|dollar|dollars|usd|euro|euros|change|echange)\b')
        .hasMatch(lower)) {
      s -= 5;
    }
    if (RegExp(r'\b(camion|reception|livraison|fournisseur\s+arrive)\b')
        .hasMatch(lower)) {
      s -= 4;
    }
    if (RegExp(r'\b(combien|reste|stock\s+de)\b').hasMatch(lower) &&
        !RegExp(r'\b(vends?|vendre|vente|vendu)\b').hasMatch(lower)) {
      s -= 4;
    }
    if (RegExp(r'\b(commande|commander)\b').hasMatch(lower) &&
        RegExp(r'\b(chez|fournisseur)\b').hasMatch(lower)) {
      s -= 4;
    }
    if (RegExp(r'\b(dette|rembourse|paie\s+sa)\b').hasMatch(lower)) s -= 3;
    return s.clamp(0, 20);
  }

  int _scoreExpense(String lower) {
    var s = VoiceIntentTriggerCatalog.phraseBonus(
      VoiceIntentKind.expense,
      lower,
    );
    if (RegExp(r'\b(depense|depenses)\b').hasMatch(lower)) s += 4;
    if (RegExp(r'\b(ajoute|ajouter)\b').hasMatch(lower) &&
        RegExp(r'\b(depense)').hasMatch(lower)) {
      s += 2;
    }
    if (RegExp(r'\b(loyer|salaire|carburant|transport)\b').hasMatch(lower) &&
        RegExp(r'\b(franc|fcfa|depense)\b').hasMatch(lower)) {
      s += 2;
    }
    if (RegExp(r'\b(aujourd.?hui|montre|liste|combien)\b').hasMatch(lower) &&
        !RegExp(r'\b(ajoute|ajouter)\b').hasMatch(lower)) {
      s -= 3;
    }
    return s.clamp(0, 20);
  }

  int _scoreDebt(String lower) {
    var s = VoiceIntentTriggerCatalog.phraseBonus(
      VoiceIntentKind.debtPayment,
      lower,
    );
    if (RegExp(r'\b(rembourse|rembourser|remboursement)\b').hasMatch(lower)) {
      s += 4;
    }
    if (RegExp(r'\b(dette|credit)\b').hasMatch(lower)) s += 3;
    if (RegExp(r'\b(paiement|paie|payer|verse|verser|regle|reglement)\b')
        .hasMatch(lower)) {
      s += 3;
    }
    if (RegExp(r'\b(paie|payer|vient\s+payer)\b').hasMatch(lower)) s += 2;
    if (RegExp(r'\b(vends?|vendre|depense)\b').hasMatch(lower)) s -= 3;
    if (RegExp(r'\b(critique|critiques|qui\s+me\s+doit)\b').hasMatch(lower) &&
        !RegExp(r'\b(paie|payer|rembourse)\b').hasMatch(lower)) {
      s -= 5;
    }
    return s.clamp(0, 20);
  }

  int _scoreFx(String lower) {
    var s = 0;
    if (RegExp(r'\b(change|changer|echange|echanger)\b').hasMatch(lower)) {
      s += 3;
    }
    if (RegExp(r'\b(naira|nairas|ngn|dollar|dollars|usd|euro|euros|eur)\b')
        .hasMatch(lower)) {
      s += 3;
    }
    if (lower.contains('devise') || lower.contains('taux')) s += 2;
    if (RegExp(r'\bsolde\b').hasMatch(lower) &&
        !RegExp(r'\b(change|changer|echange|echanger)\b').hasMatch(lower)) {
      s -= 4;
    }
    if (RegExp(r'\b(marge|profit|benefice)\b').hasMatch(lower)) s -= 5;
    return s.clamp(0, 20);
  }

  int _scoreProcurement(String lower) {
    var s = 0;
    if (RegExp(r'\b(commande|commander|appro|approvisionnement)\b')
        .hasMatch(lower)) {
      s += 4;
    }
    if (RegExp(r'\b(fournisseur|chez)\b').hasMatch(lower)) s += 2;
    if (RegExp(r'\b(camion|arriv|reception|livr)\b').hasMatch(lower)) {
      s -= 4;
    }
    if (RegExp(r'\b(quoi|que)\s+(je\s+)?(dois|faut)').hasMatch(lower) ||
        RegExp(r'\b(stock\s+bas|rupture|qu.?est[- ]ce\s+que)\b')
            .hasMatch(lower)) {
      s -= 5;
    }
    return s.clamp(0, 20);
  }
}
