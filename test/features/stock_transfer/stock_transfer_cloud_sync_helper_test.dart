import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/stock_transfer/data/utils/stock_transfer_cloud_sync_helper.dart';
import 'package:venteapp/features/stock_transfer/domain/entities/stock_transfer.dart';

void main() {
  group('StockTransferCloudSyncHelper ship clamp', () {
    final mapping = [
      {'localItemId': 1, 'remoteItemId': 10},
      {'localItemId': 2, 'remoteItemId': 20},
    ];
    final remoteItems = [
      {
        'id': 10,
        'quantityRequested': 5,
        'quantityShipped': 5,
      },
      {
        'id': 20,
        'quantityRequested': 8,
        'quantityShipped': 3,
      },
    ];

    test('clamp réduit aux pending cloud', () {
      final clamped =
          StockTransferCloudSyncHelper.clampShipQuantitiesToRemotePending(
        quantitiesByLocalItemId: {1: 5, 2: 10},
        mapping: mapping,
        remoteItems: remoteItems,
      );
      expect(clamped, {2: 5});
    });

    test('remoteAlreadyCovers quand pending à 0', () {
      expect(
        StockTransferCloudSyncHelper.remoteAlreadyCoversShipQuantities(
          quantitiesByLocalItemId: {1: 5},
          mapping: mapping,
          remoteItems: remoteItems,
        ),
        isTrue,
      );
      expect(
        StockTransferCloudSyncHelper.remoteAlreadyCoversShipQuantities(
          quantitiesByLocalItemId: {1: 5, 2: 2},
          mapping: mapping,
          remoteItems: remoteItems,
        ),
        isFalse,
      );
    });

    test('détecte erreur quantité trop élevée', () {
      expect(
        StockTransferCloudSyncHelper.isShipQuantityTooHighError(
          'Quantité expédiée trop élevée pour « Teste ».',
        ),
        isTrue,
      );
    });

    test('clamp receive au pending cloud', () {
      final mapping = [
        {'localItemId': 1, 'remoteItemId': 10},
      ];
      final remoteItems = [
        {
          'id': 10,
          'quantityShipped': 5,
          'quantityReceived': 5,
        },
      ];
      expect(
        StockTransferCloudSyncHelper.clampReceiveQuantitiesToRemotePending(
          quantitiesByLocalItemId: {1: 5},
          mapping: mapping,
          remoteItems: remoteItems,
        ),
        isEmpty,
      );
      expect(
        StockTransferCloudSyncHelper.remoteAlreadyCoversReceiveQuantities(
          quantitiesByLocalItemId: {1: 5},
          mapping: mapping,
          remoteItems: remoteItems,
        ),
        isTrue,
      );
    });
  });

  group('StockTransferCloudSyncHelper discrepancy', () {
    test('open qty = shipped - received - resolved', () {
      final open = StockTransferCloudSyncHelper.openDiscrepancyQtyOnRemoteItem(
        remoteItem: {
          'id': 10,
          'quantityShipped': 10,
          'quantityReceived': 7,
        },
        discrepancies: [
          {'transferItemId': 10, 'quantity': 1},
          {'transferItemId': 99, 'quantity': 5},
        ],
        remoteItemId: 10,
      );
      expect(open, 2);
    });

    test('statuts résolution', () {
      expect(
        StockTransferCloudSyncHelper.canResolveDiscrepancyOnRemote(
          StockTransferStatus.shipped,
        ),
        isTrue,
      );
      expect(
        StockTransferCloudSyncHelper.canResolveDiscrepancyOnRemote(
          StockTransferStatus.validated,
        ),
        isFalse,
      );
      expect(
        StockTransferCloudSyncHelper.isTerminalClosedStatus(
          StockTransferStatus.closedWithException,
        ),
        isTrue,
      );
    });
  });
}
