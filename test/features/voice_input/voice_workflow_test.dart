import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/debts/domain/entities/debt_entities.dart';
import 'package:venteapp/features/fx_exchange/domain/entities/fx_exchange_entities.dart';
import 'package:venteapp/features/procurement/domain/entities/procurement.dart';
import 'package:venteapp/features/voice_input/domain/entities/voice_draft.dart';
import 'package:venteapp/features/voice_input/domain/services/voice_intent_parser.dart';
import 'package:venteapp/features/voice_input/domain/services/voice_intent_router.dart';
import 'package:venteapp/features/voice_input/domain/workflows/debt_payment_workflow.dart';
import 'package:venteapp/features/voice_input/domain/workflows/fx_exchange_workflow.dart';
import 'package:venteapp/features/voice_input/domain/workflows/receive_po_workflow.dart';
import 'package:venteapp/features/voice_input/domain/workflows/sale_cart_workflow.dart';
import 'package:venteapp/features/voice_input/domain/workflows/voice_workflow.dart';

Debt _debt({
  required int id,
  required int customerId,
  required int remaining,
  String? receipt,
}) {
  return Debt(
    id: id,
    shopId: 1,
    customerId: customerId,
    receiptNumber: receipt,
    originalAmount: remaining,
    amountPaid: 0,
    amountRemaining: remaining,
    status: DebtStatus.open,
    createdAt: 1,
  );
}

PurchaseOrder _po({
  required int id,
  required String number,
  String? supplier,
  required PurchaseOrderStatus status,
  List<PurchaseOrderItem>? items,
}) {
  return PurchaseOrder(
    id: id,
    shopId: 1,
    supplierId: 1,
    supplierName: supplier,
    number: number,
    status: status,
    orderedAt: 1000 - id,
    subtotal: 0,
    discount: 0,
    tax: 0,
    total: 0,
    createdBy: 1,
    createdAt: 1,
    updatedAt: 1,
    version: 1,
    items: items,
  );
}

PurchaseOrderItem _item({
  required int id,
  required int productId,
  required int ordered,
  int received = 0,
  String name = 'Ciment',
}) {
  return PurchaseOrderItem(
    id: id,
    shopId: 1,
    purchaseOrderId: 1,
    productId: productId,
    productName: name,
    quantityOrdered: ordered,
    quantityReceived: received,
    unitCost: 5000,
    discount: 0,
    tax: 0,
    subtotal: ordered * 5000,
    version: 1,
  );
}

FxSession _session(int id) => FxSession(
      id: id,
      shopId: 1,
      openedBy: 1,
      openedByName: 'Admin',
      openedAt: 1,
      status: FxSessionStatus.open,
      totalMarginFcfa: 0,
      operationCount: 0,
      balances: const [],
    );

void main() {
  const customers = [
    VoiceCatalogCustomer(id: 10, name: 'Koffi'),
  ];

  group('Router Phase 2', () {
    const router = VoiceIntentRouter();

    test('camion arrivé → receivePurchase', () {
      expect(
        router.detect('Le camion est arrivé'),
        VoiceIntentKind.receivePurchase,
      );
    });

    test('Koffi paie → debtPayment', () {
      expect(router.detect('Koffi paie'), VoiceIntentKind.debtPayment);
    });

    test('réception ≠ commande création', () {
      expect(
        router.detect('Réception de la livraison'),
        VoiceIntentKind.receivePurchase,
      );
      expect(
        router.detect('Commande 100 tonnes de ciment chez CIMBENIN'),
        VoiceIntentKind.procurementOrder,
      );
    });
  });

  group('DebtPaymentWorkflow', () {
    test('une seule facture → prêt avec montant', () async {
      final wf = DebtPaymentWorkflow(
        customers: customers,
        loadOpenDebts: (_) async => [
          _debt(id: 1, customerId: 10, remaining: 20000, receipt: 'FAC-1'),
        ],
      );
      await wf.bootstrap('Koffi paie 10000');
      expect(wf.status, VoiceWorkflowStatus.ready);
      expect(wf.draft, isA<VoiceDebtPaymentDraft>());
      expect((wf.draft! as VoiceDebtPaymentDraft).amount, 10000);
      expect((wf.draft! as VoiceDebtPaymentDraft).debtId, 1);
    });

    test('N factures + tout → readyBatch', () async {
      final wf = DebtPaymentWorkflow(
        customers: customers,
        loadOpenDebts: (_) async => [
          _debt(id: 1, customerId: 10, remaining: 10000, receipt: 'A'),
          _debt(id: 2, customerId: 10, remaining: 5000, receipt: 'B'),
        ],
      );
      await wf.bootstrap('Koffi paie');
      expect(wf.status, VoiceWorkflowStatus.asking);
      await wf.advance('tout');
      expect(wf.status, VoiceWorkflowStatus.readyBatch);
      expect(wf.batchDrafts, hasLength(2));
    });
  });

  group('FxExchangeWorkflow', () {
    test('demande la devise si manquante', () async {
      final wf = FxExchangeWorkflow(
        shopId: 1,
        findOpenFxSession: ({required int shopId}) async => _session(7),
        previewFxOperation: ({
          required int shopId,
          required CreateFxOperationInput input,
          int? sessionId,
        }) async =>
            FxOperationPreview(
              toAmount: 1000,
              marginFcfa: 0,
              rateSnapshotId: 1,
              appliedRateNumerator: 400,
              appliedRateDenominator: 1000,
              quoteCurrency: 'NGN',
            ),
        fxRates: const [
          VoiceFxRateInfo(
            quoteCurrency: 'NGN',
            buyNumerator: 400,
            buyDenominator: 1000,
            sellNumerator: 400,
            sellDenominator: 1000,
          ),
        ],
        seed: const VoiceFxDraft(
          transcript: 'échange',
          missingFields: ['devise'],
          fromAmount: 500000,
          operationTypeCode: 'sell',
        ),
      );
      await wf.bootstrap('échange cinq cent mille');
      expect(wf.status, VoiceWorkflowStatus.asking);
      expect(wf.currentPrompt?.question, contains('devise'));
    });
  });

  group('ReceivePoWorkflow', () {
    test('sélection « la dernière »', () async {
      final older = _po(
        id: 1,
        number: 'PO-1',
        supplier: 'Alpha',
        status: PurchaseOrderStatus.sent,
      );
      final newer = _po(
        id: 2,
        number: 'PO-2',
        supplier: 'Beta',
        status: PurchaseOrderStatus.sent,
        items: [
          _item(id: 10, productId: 1, ordered: 50),
        ],
      );
      // listOrders déjà trié desc orderedAt → newer first
      final wf = ReceivePoWorkflow(
        shopId: 1,
        listOrders: () async => [newer, older],
        findOrder: (id) async {
          if (id == 2) return newer;
          return older;
        },
      );
      await wf.bootstrap('Le camion est arrivé');
      expect(wf.status, VoiceWorkflowStatus.asking);
      await wf.advance('la dernière');
      expect(wf.status, VoiceWorkflowStatus.asking);
      expect(wf.currentPrompt?.question, contains('Quantité'));
    });
  });

  group('SaleCartWorkflow', () {
    test('phrase structurée → ligne prête', () async {
      final products = [
        const VoiceCatalogProduct(
          id: 1,
          name: 'Sac',
          priceSell: 5000,
          quantityInStock: 100,
        ),
      ];
      final wf = SaleCartWorkflow(
        parser: VoiceIntentParser(),
        products: products,
        customers: const [],
      );
      await wf.bootstrap('je vends');
      expect(wf.status, VoiceWorkflowStatus.asking);

      await wf.advance('produit Sac quantité 20 prix 3000');
      expect(wf.status, VoiceWorkflowStatus.ready);
      final draft = wf.draft! as VoiceSaleDraft;
      expect(draft.lines.single.productId, 1);
      expect(draft.lines.single.quantity, 20);
      expect(draft.lines.single.unitPrice, 3000);
    });

    test('ordre prix puis quantité', () async {
      final products = [
        const VoiceCatalogProduct(
          id: 1,
          name: 'Sac',
          priceSell: 5000,
          quantityInStock: 100,
        ),
      ];
      final wf = SaleCartWorkflow(
        parser: VoiceIntentParser(),
        products: products,
        customers: const [],
      );
      await wf.bootstrap('vente');
      await wf.advance('produit Sac prix 3000 quantité 20');
      expect(wf.status, VoiceWorkflowStatus.ready);
      final draft = wf.draft! as VoiceSaleDraft;
      expect(draft.lines.single.quantity, 20);
      expect(draft.lines.single.unitPrice, 3000);
    });

    test('sans prix → prix boutique', () async {
      final products = [
        const VoiceCatalogProduct(
          id: 1,
          name: 'Sac',
          priceSell: 5000,
          quantityInStock: 100,
        ),
      ];
      final wf = SaleCartWorkflow(
        parser: VoiceIntentParser(),
        products: products,
        customers: const [],
      );
      await wf.bootstrap('vente');
      await wf.advance('produit Sac quantité 20');
      expect(wf.status, VoiceWorkflowStatus.ready);
      final draft = wf.draft! as VoiceSaleDraft;
      expect(draft.lines.single.quantity, 20);
      expect(draft.lines.single.unitPrice, 5000);
    });
  });
}
