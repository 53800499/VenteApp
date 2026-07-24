import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/voice_input/domain/entities/voice_draft.dart';
import 'package:venteapp/features/voice_input/domain/services/entity_matcher.dart';
import 'package:venteapp/features/voice_input/domain/services/voice_intent_parser.dart';
import 'package:venteapp/features/voice_input/domain/services/voice_intent_router.dart';

void main() {
  late VoiceIntentParser parser;
  late VoiceIntentRouter router;

  const products = [
    VoiceCatalogProduct(
      id: 1,
      name: 'Ciment 50 kg',
      priceSell: 5000,
      quantityInStock: 100,
    ),
    VoiceCatalogProduct(
      id: 2,
      name: 'Riz 25 kg',
      priceSell: 12000,
      quantityInStock: 50,
    ),
  ];

  const customers = [
    VoiceCatalogCustomer(id: 10, name: 'Koffi'),
  ];

  const categories = [
    VoiceCatalogCategory(id: 1, name: 'Transport'),
  ];

  const suppliers = [
    VoiceCatalogSupplier(id: 5, name: 'CIMBENIN'),
  ];

  setUp(() {
    router = const VoiceIntentRouter();
    parser = VoiceIntentParser(
      matcher: const EntityMatcher(),
      router: router,
    );
  });

  group('VoiceIntentRouter', () {
    test('détecte vente', () {
      expect(
        router.detect('Vends cinq sacs de ciment à Koffi'),
        VoiceIntentKind.sale,
      );
    });

    test('variantes vente → même intent', () {
      for (final phrase in [
        'Vends cinq sacs de ciment à Koffi',
        'J’ai vendu deux sacs de riz',
        'On a vendu trois sacs de ciment',
        'Koffi achète cinq sacs de ciment',
        'Facture trois sacs de ciment à Ama',
        'Faire une vente de ciment',
        'Nouvelle vente cinq sacs',
        'Je donne cinq sacs de ciment à Koffi',
      ]) {
        expect(
          router.detect(phrase),
          VoiceIntentKind.sale,
          reason: phrase,
        );
      }
    });

    test('détecte dépense', () {
      expect(
        router.detect('Ajoute une dépense de 25000 francs pour le transport'),
        VoiceIntentKind.expense,
      );
    });

    test('détecte dette', () {
      expect(
        router.detect('Rembourse 10000 francs de la dette de Koffi'),
        VoiceIntentKind.debtPayment,
      );
    });

    test('détecte change', () {
      expect(
        router.detect('Échanger cinq cent mille francs CFA en nairas'),
        VoiceIntentKind.fxOperation,
      );
    });

    test('détecte commande', () {
      expect(
        router.detect('Commande 100 tonnes de ciment chez CIMBENIN'),
        VoiceIntentKind.procurementOrder,
      );
    });

    test('unknown', () {
      expect(router.detect('bonjour'), VoiceIntentKind.unknown);
    });

    test('V3 stock query', () {
      expect(
        router.detect('Combien me reste-t-il de ciment ?'),
        VoiceIntentKind.stockQuery,
      );
    });

    test('V3 fx balance query (pas opération)', () {
      expect(
        router.detect('Quel est mon solde en nairas ?'),
        VoiceIntentKind.fxBalanceQuery,
      );
    });

    test('V3 dépenses du jour (pas création)', () {
      expect(
        router.detect('Montre les dépenses d\'aujourd\'hui'),
        VoiceIntentKind.expenseReportQuery,
      );
    });

    test('V3 vente reste une vente', () {
      expect(
        router.detect('Vends 2 sacs de ciment'),
        VoiceIntentKind.sale,
      );
    });

    test('Phase 2 camion → receivePurchase', () {
      expect(
        router.detect('Le camion est arrivé'),
        VoiceIntentKind.receivePurchase,
      );
    });

    test('Phase 2 Koffi paie → debtPayment', () {
      expect(router.detect('Koffi paie'), VoiceIntentKind.debtPayment);
    });

    test('Phase 3 conseil stock', () {
      expect(
        router.detect('Qu’est-ce que je dois commander ?'),
        VoiceIntentKind.stockAdviceQuery,
      );
    });

    test('Phase 3 stock query reste stock', () {
      expect(
        router.detect('Combien me reste-t-il de ciment ?'),
        VoiceIntentKind.stockQuery,
      );
    });

    test('Phase 3 explication caisse', () {
      expect(
        router.detect('Pourquoi ma caisse est faible ?'),
        VoiceIntentKind.cashExplainQuery,
      );
    });

    test('Phase 3 marge FX du jour', () {
      expect(
        router.detect('Quelle est ma marge change aujourd’hui ?'),
        VoiceIntentKind.fxMarginQuery,
      );
    });

    test('Phase 3 solde FX ≠ marge', () {
      expect(
        router.detect('Quel est mon solde en nairas ?'),
        VoiceIntentKind.fxBalanceQuery,
      );
    });

    test('Phase 3 dettes critiques', () {
      expect(
        router.detect('Quelles sont les dettes critiques ?'),
        VoiceIntentKind.debtCriticalQuery,
      );
    });

    test('Phase 3 paiement reste dette', () {
      expect(router.detect('Koffi paie'), VoiceIntentKind.debtPayment);
    });

    test('variantes réception → même intent', () {
      for (final phrase in [
        'Le camion est arrivé',
        'Le camion est là',
        'On a reçu la livraison',
        'Le fournisseur est arrivé',
        'La marchandise est reçue',
      ]) {
        expect(
          router.detect(phrase),
          VoiceIntentKind.receivePurchase,
          reason: phrase,
        );
      }
    });

    test('variantes stock → stockQuery', () {
      expect(
        router.detect('Il me reste combien de ciment ?'),
        VoiceIntentKind.stockQuery,
      );
      expect(
        router.detect('Quel stock de ciment ?'),
        VoiceIntentKind.stockQuery,
      );
    });

    test('confiance élevée camion, pas de clarification', () {
      final d = router.detectDetailed('Le camion est arrivé');
      expect(d.kind, VoiceIntentKind.receivePurchase);
      expect(d.confidence, greaterThanOrEqualTo(0.4));
      expect(d.needsClarification, isFalse);
    });

    test('bonjour → unknown', () {
      final d = router.detectDetailed('bonjour');
      expect(d.kind, VoiceIntentKind.unknown);
      expect(d.needsClarification, isFalse);
    });
  });

  group('VoiceIntentParser V2', () {
    test('vente complète', () {
      final draft = parser.parse(
        transcript: 'Vends cinq sacs de ciment à Koffi à 95 000 francs',
        products: products,
        customers: customers,
      );
      expect(draft, isA<VoiceSaleDraft>());
      expect((draft as VoiceSaleDraft).productId, 1);
      expect(draft.customerId, 10);
      expect(draft.canSave, isTrue);
    });

    test('vente multi-lignes ciment et riz', () {
      final draft = parser.parse(
        transcript: 'Vends 5 sacs de ciment et 2 sacs de riz à Koffi',
        products: products,
        customers: customers,
      );
      expect(draft, isA<VoiceSaleDraft>());
      final sale = draft as VoiceSaleDraft;
      expect(sale.lines.length, 2);
      expect(sale.lines[0].productId, 1);
      expect(sale.lines[0].quantity, 5);
      expect(sale.lines[1].productId, 2);
      expect(sale.lines[1].quantity, 2);
      expect(sale.customerId, 10);
      expect(sale.canSave, isTrue);
    });

    test('phrase structurée produit quantité prix', () {
      final line = parser.parseStructuredSaleLine(
        'produit ciment quantité 20 prix 3000',
      );
      expect(line, isNotNull);
      expect(line!.productQuery, 'ciment');
      expect(line.quantity, 20);
      expect(line.unitPrice, 3000);

      final withUnit = parser.parseStructuredSaleLine(
        'produit riz quantité 5 prix unitaire 2500',
      );
      expect(withUnit?.productQuery, 'riz');
      expect(withUnit?.quantity, 5);
      expect(withUnit?.unitPrice, 2500);

      final priceFirst = parser.parseStructuredSaleLine(
        'produit Sac prix 3000 quantité 20',
      );
      expect(priceFirst?.productQuery, 'sac');
      expect(priceFirst?.quantity, 20);
      expect(priceFirst?.unitPrice, 3000);

      final noPrice = parser.parseStructuredSaleLine(
        'produit Sac quantité 20',
      );
      expect(noPrice?.productQuery, 'sac');
      expect(noPrice?.quantity, 20);
      expect(noPrice?.unitPrice, isNull);
    });

    test('fx naira', () {
      final draft = parser.parse(
        transcript: 'Échanger 500000 francs CFA en nairas',
        fxRates: const [
          VoiceFxRateInfo(
            quoteCurrency: 'NGN',
            buyNumerator: 400,
            buyDenominator: 1000,
            sellNumerator: 400,
            sellDenominator: 1000,
          ),
        ],
        fxSessionId: 1,
      );
      expect(draft, isA<VoiceFxDraft>());
      final fx = draft as VoiceFxDraft;
      expect(fx.foreignCurrency, 'NGN');
      expect(fx.fromAmount, 500000);
      expect(fx.toAmount, isNotNull);
      expect(fx.canSave, isTrue);
    });

    test('commande fournisseur', () {
      final draft = parser.parse(
        transcript: 'Commande 100 tonnes de ciment chez CIMBENIN',
        products: products,
        suppliers: suppliers,
      );
      expect(draft, isA<VoiceProcurementDraft>());
      final po = draft as VoiceProcurementDraft;
      expect(po.productId, 1);
      expect(po.supplierId, 5);
      expect(po.quantity, 100);
      expect(po.canSave, isFalse);
    });

    test('dette paiement', () {
      final draft = parser.parse(
        transcript: 'Rembourse 20000 francs pour Koffi',
        customers: customers,
        openDebts: const [
          VoiceCatalogOpenDebt(
            id: 99,
            customerId: 10,
            customerName: 'Koffi',
            amountRemaining: 50000,
          ),
        ],
      );
      expect(draft, isA<VoiceDebtPaymentDraft>());
      final d = draft as VoiceDebtPaymentDraft;
      expect(d.customerId, 10);
      expect(d.debtId, 99);
      expect(d.amount, 20000);
      expect(d.canSave, isTrue);
    });
  });

  group('VoiceIntentParser V3 Q&A', () {
    test('stock query ciment', () {
      final draft = parser.parse(
        transcript: 'Combien me reste-t-il de ciment ?',
        products: products,
      );
      expect(draft, isA<VoiceStockQueryDraft>());
      final s = draft as VoiceStockQueryDraft;
      expect(s.productId, 1);
      expect(s.quantityInStock, 100);
      expect(s.canSave, isFalse);
    });

    test('fx balance nairas', () {
      final draft = parser.parse(
        transcript: 'Quel est mon solde en nairas ?',
      );
      expect(draft, isA<VoiceFxBalanceQueryDraft>());
      final fx = draft as VoiceFxBalanceQueryDraft;
      expect(fx.currencyCode, 'NGN');
      expect(fx.canSave, isFalse);
    });

    test('expense report today', () {
      final draft = parser.parse(
        transcript: 'Montre les dépenses d\'aujourd\'hui',
      );
      expect(draft, isA<VoiceExpenseReportDraft>());
      final r = draft as VoiceExpenseReportDraft;
      expect(r.fromMs, lessThan(r.toMs));
      expect(r.canSave, isFalse);
    });

    test('phrase structurée nouveau produit', () {
      final line = parser.parseStructuredProductLine(
        'nom Ciment prix vente 5000',
      );
      expect(line, isNotNull);
      expect(line!.name, 'Ciment');
      expect(line.priceSell, 5000);
      expect(line.priceBuy, isNull);

      final full = parser.parseStructuredProductLine(
        'nom Riz prix 12000 catégorie Alimentation stock 50 alerte 5',
      );
      expect(full?.name, 'Riz');
      expect(full?.priceSell, 12000);
      expect(full?.categoryQuery, 'Alimentation');
      expect(full?.quantity, 50);
      expect(full?.alertThreshold, 5);

      final withBuy = parser.parseStructuredProductLine(
        'nom Sac prix vente 3000 prix achat 2500',
      );
      expect(withBuy?.priceSell, 3000);
      expect(withBuy?.priceBuy, 2500);
    });

    test('phrase structurée nouvelle catégorie', () {
      final simple = parser.parseStructuredCategoryLine('nom Boissons');
      expect(simple, isNotNull);
      expect(simple!.name, 'Boissons');
      expect(simple.description, isNull);

      final withDesc = parser.parseStructuredCategoryLine(
        'catégorie Alimentation description Produits alimentaires',
      );
      expect(withDesc?.name, 'Alimentation');
      expect(withDesc?.description, 'Produits alimentaires');
    });
  });
}
