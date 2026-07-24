import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/sales_orders/domain/entities/sales_order.dart';
import 'package:venteapp/features/sales_orders/domain/sales_order_sync_rules.dart';

void main() {
  SalesOrderItem item({
    required int ordered,
    int delivered = 0,
    int refused = 0,
    int replaced = 0,
  }) {
    return SalesOrderItem(
      id: 1,
      salesOrderId: 1,
      productId: 10,
      productName: 'Ciment',
      quantityOrdered: ordered,
      quantityDelivered: delivered,
      quantityRefused: refused,
      quantityReplaced: replaced,
      unitPrice: 5000,
      lineTotal: ordered * 5000,
    );
  }

  group('SalesOrderItem.quantityRemaining', () {
    test('reste = commandé − livré − refusé − remplacé', () {
      expect(
        item(ordered: 200, delivered: 100, refused: 5, replaced: 20)
            .quantityRemaining,
        75,
      );
    });

    test('reste ne descend pas sous 0', () {
      expect(
        item(ordered: 10, delivered: 8, refused: 5).quantityRemaining,
        0,
      );
    });
  });

  group('SalesOrder.statusAfterFulfillment', () {
    test('première livraison partielle → partially_delivered', () {
      final status = SalesOrder.statusAfterFulfillment(
        items: [item(ordered: 200, delivered: 120)],
        current: SalesOrderStatus.preparing,
      );
      expect(status, SalesOrderStatus.partiallyDelivered);
    });

    test('tout livré / refusé / remplacé → delivered', () {
      final status = SalesOrder.statusAfterFulfillment(
        items: [item(ordered: 200, delivered: 150, refused: 20, replaced: 30)],
        current: SalesOrderStatus.partiallyDelivered,
      );
      expect(status, SalesOrderStatus.delivered);
    });

    test('confirmée sans livraison reste preparing après transition', () {
      final status = SalesOrder.statusAfterFulfillment(
        items: [item(ordered: 200)],
        current: SalesOrderStatus.confirmed,
      );
      expect(status, SalesOrderStatus.preparing);
    });

    test('closed / cancelled inchangés', () {
      expect(
        SalesOrder.statusAfterFulfillment(
          items: [item(ordered: 10, delivered: 10)],
          current: SalesOrderStatus.closed,
        ),
        SalesOrderStatus.closed,
      );
    });
  });

  group('SalesOrderRefusalReason', () {
    test('nouveaux motifs ont des codes stables', () {
      expect(SalesOrderRefusalReason.wrongOrder.code, 'wrong_order');
      expect(SalesOrderRefusalReason.clientAbsent.code, 'client_absent');
      expect(SalesOrderRefusalReason.clientRefused.code, 'client_refused');
      expect(SalesOrderRefusalReason.expired.code, 'expired');
      expect(
        SalesOrderRefusalReason.fromCode('wrong_order'),
        SalesOrderRefusalReason.wrongOrder,
      );
    });
  });

  group('SalesOrderRemainingReason', () {
    test('round-trip codes', () {
      expect(
        SalesOrderRemainingReason.fromCode('truck_full'),
        SalesOrderRemainingReason.truckFull,
      );
      expect(SalesOrderRemainingReason.postponed.code, 'postponed');
      expect(SalesOrderRemainingReason.stockShort.labelFr, 'Stock insuffisant');
    });
  });

  group('SalesOrderHistoryAction', () {
    test('codes stables + fromCode', () {
      expect(SalesOrderHistoryAction.created.code, 'created');
      expect(SalesOrderHistoryAction.delivered.code, 'delivered');
      expect(SalesOrderHistoryAction.replacement.labelFr, 'Remplacement');
      expect(
        SalesOrderHistoryAction.fromCode('confirmed'),
        SalesOrderHistoryAction.confirmed,
      );
      expect(
        SalesOrderHistoryAction.fromCode('confirm'),
        SalesOrderHistoryAction.confirmed,
      );
    });
  });

  group('SalesOrderHistoryEntry.payload', () {
    test('payload JSON métier exposé via actionEnum', () {
      const entry = SalesOrderHistoryEntry(
        id: 1,
        action: 'delivered',
        performedBy: 2,
        performedAt: 0,
        details: 'Livraison DL-0001',
        payload: {
          'deliveryNumber': 'DL-0001',
          'remainingReason': 'truck_full',
        },
      );
      expect(entry.actionEnum, SalesOrderHistoryAction.delivered);
      expect(entry.payload?['deliveryNumber'], 'DL-0001');
    });
  });

  group('SalesOrder.version stamp fields', () {
    test('version / updatedBy / deviceId sur l’entité', () {
      final order = SalesOrder(
        id: 1,
        shopId: 1,
        customerId: 1,
        customerName: 'Client',
        number: 'SO-00001',
        status: SalesOrderStatus.confirmed,
        orderedAt: 0,
        subtotal: 1000,
        discount: 0,
        tax: 0,
        total: 1000,
        createdBy: 1,
        createdAt: 0,
        updatedAt: 0,
        items: const [],
        version: 3,
        updatedBy: 9,
        deviceId: 'dev-abc',
      );
      expect(order.version, 3);
      expect(order.updatedBy, 9);
      expect(order.deviceId, 'dev-abc');
    });
  });

  group('shouldSkipSalesOrderRemoteUpsert', () {
    test('skip si local.version >= remote.version', () {
      expect(
        shouldSkipSalesOrderRemoteUpsert(
          localVersion: 5,
          remoteVersion: 5,
          force: false,
        ),
        isTrue,
      );
      expect(
        shouldSkipSalesOrderRemoteUpsert(
          localVersion: 6,
          remoteVersion: 5,
          force: false,
        ),
        isTrue,
      );
    });

    test('applique si remote plus récent', () {
      expect(
        shouldSkipSalesOrderRemoteUpsert(
          localVersion: 4,
          remoteVersion: 5,
          force: false,
        ),
        isFalse,
      );
    });

    test('force écrase même si local >= remote', () {
      expect(
        shouldSkipSalesOrderRemoteUpsert(
          localVersion: 9,
          remoteVersion: 2,
          force: true,
        ),
        isFalse,
      );
    });

    test('sans version locale → pas de skip', () {
      expect(
        shouldSkipSalesOrderRemoteUpsert(
          localVersion: null,
          remoteVersion: 1,
          force: false,
        ),
        isFalse,
      );
    });
  });
}
