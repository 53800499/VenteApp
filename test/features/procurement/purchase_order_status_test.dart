import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/procurement/domain/entities/procurement.dart';

void main() {
  PurchaseOrderItem item({
    required int ordered,
    int received = 0,
    int refused = 0,
  }) {
    return PurchaseOrderItem(
      id: 1,
      shopId: 1,
      purchaseOrderId: 1,
      productId: 10,
      productName: 'Ciment',
      quantityOrdered: ordered,
      quantityReceived: received,
      quantityRefused: refused,
      unitCost: 5000,
      discount: 0,
      tax: 0,
      subtotal: ordered * 5000,
      version: 1,
    );
  }

  group('PurchaseOrderItem.quantityRemaining', () {
    test('reste = commandé − reçu − refusé', () {
      expect(
        item(ordered: 100, received: 95, refused: 5).quantityRemaining,
        0,
      );
      expect(
        item(ordered: 100, received: 80, refused: 5).quantityRemaining,
        15,
      );
    });

    test('reste ne descend pas sous 0', () {
      expect(
        item(ordered: 10, received: 8, refused: 5).quantityRemaining,
        0,
      );
    });
  });

  group('PurchaseOrder.statusAfterReceipt', () {
    test('première réception partielle → partiallyReceived', () {
      final status = PurchaseOrder.statusAfterReceipt(
        items: [item(ordered: 100, received: 50)],
        current: PurchaseOrderStatus.sent,
      );
      expect(status, PurchaseOrderStatus.partiallyReceived);
    });

    test('accepté + refusé couvrent la commande → received', () {
      final status = PurchaseOrder.statusAfterReceipt(
        items: [item(ordered: 100, received: 95, refused: 5)],
        current: PurchaseOrderStatus.partiallyReceived,
      );
      expect(status, PurchaseOrderStatus.received);
    });

    test('100 % refusé → received (reliquat 0)', () {
      final status = PurchaseOrder.statusAfterReceipt(
        items: [item(ordered: 20, refused: 20)],
        current: PurchaseOrderStatus.sent,
      );
      expect(status, PurchaseOrderStatus.received);
    });

    test('aucune ligne traitée → statut inchangé', () {
      expect(
        PurchaseOrder.statusAfterReceipt(
          items: [item(ordered: 100)],
          current: PurchaseOrderStatus.sent,
        ),
        PurchaseOrderStatus.sent,
      );
    });

    test('cancelled / draft inchangés', () {
      expect(
        PurchaseOrder.statusAfterReceipt(
          items: [item(ordered: 10, received: 10)],
          current: PurchaseOrderStatus.cancelled,
        ),
        PurchaseOrderStatus.cancelled,
      );
    });
  });
}
