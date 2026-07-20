import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/stock_transfer.dart';
import '../datasources/stock_transfer_local_datasource.dart';
import '../datasources/stock_transfer_remote_datasource.dart';

class StockTransferCloudSyncResult {
  const StockTransferCloudSyncResult({
    required this.ok,
    this.remote,
    this.deferReason,
    this.alreadyComplete = false,
  });

  final bool ok;
  final Map<String, dynamic>? remote;
  final String? deferReason;
  final bool alreadyComplete;
}

/// Validation / expédition cloud des transferts (boutique source).
class StockTransferCloudSyncHelper {
  StockTransferCloudSyncHelper({
    required StockTransferLocalDatasource local,
    required StockTransferRemoteDatasource remote,
  })  : _local = local,
        _remote = remote;

  final StockTransferLocalDatasource _local;
  final StockTransferRemoteDatasource _remote;

  static bool isShippableStatus(String status) =>
      status == StockTransferStatus.validated ||
      status == StockTransferStatus.partiallyShipped;

  static bool isPostShipStatus(String status) =>
      status == StockTransferStatus.shipped ||
      status == StockTransferStatus.partiallyReceived ||
      status == StockTransferStatus.received;

  static bool isNotReadyToShipError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('ne peut pas être expédi') ||
        lower.contains('ne peut pas etre expedi');
  }

  static bool isAlreadyValidatedError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('brouillon') && lower.contains('valid');
  }

  static bool isInsufficientStockError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('stock insuffisant') || lower.contains('stock insuff');
  }

  Future<int?> resolveSourceServerShopId(StockTransfer transfer) =>
      _local.resolveShopServerId(transfer.sourceShopId);

  Future<T?> runOnSourceShop<T>({
    required StockTransfer transfer,
    required Future<T> Function() action,
  }) async {
    final sourceServerId = await resolveSourceServerShopId(transfer);
    if (sourceServerId == null) return null;
    return ApiClient.runScopedToServerShop(sourceServerId, action);
  }

  Future<StockTransferCloudSyncResult> ensureValidatedOnServer({
    required int localTransferId,
    required int serverTransferId,
    bool requireShippable = false,
  }) async {
    final transfer = await _local.findTransfer(localTransferId);
    if (transfer == null) {
      return const StockTransferCloudSyncResult(
        ok: false,
        deferReason: 'Transfert introuvable.',
      );
    }

    final scoped = await runOnSourceShop(
      transfer: transfer,
      action: () => _ensureValidatedOnServerScoped(
        localTransferId: localTransferId,
        serverTransferId: serverTransferId,
        requireShippable: requireShippable,
      ),
    );

    return scoped ??
        const StockTransferCloudSyncResult(
          ok: false,
          deferReason: 'Boutique source non synchronisée.',
        );
  }

  Future<StockTransferCloudSyncResult> _ensureValidatedOnServerScoped({
    required int localTransferId,
    required int serverTransferId,
    required bool requireShippable,
  }) async {
    Future<void> syncLocalReservations() async {
      final transfer = await _local.findTransfer(localTransferId);
      if (transfer == null) return;
      await _local.ensureTransferItemReservations(
        sourceShopId: transfer.sourceShopId,
        transferId: localTransferId,
      );
    }

    var remote = await _remote.fetchTransfer(serverTransferId);
    var status = remote['status'] as String? ?? StockTransferStatus.draft;

    if (isShippableStatus(status)) {
      await _local.applyRemoteStockTransferSnapshot(localTransferId, remote);
      await syncLocalReservations();
      return StockTransferCloudSyncResult(ok: true, remote: remote);
    }

    if (requireShippable && isPostShipStatus(status)) {
      await _local.applyRemoteStockTransferSnapshot(localTransferId, remote);
      await syncLocalReservations();
      return StockTransferCloudSyncResult(
        ok: true,
        remote: remote,
        alreadyComplete: true,
      );
    }

    if (status == StockTransferStatus.pendingApproval) {
      try {
        remote = await _remote.approveTransfer(serverTransferId);
        status = remote['status'] as String? ?? StockTransferStatus.validated;
        await _local.applyRemoteStockTransferSnapshot(localTransferId, remote);
        await syncLocalReservations();
        if (requireShippable && !isShippableStatus(status)) {
          return StockTransferCloudSyncResult(
            ok: false,
            remote: remote,
            deferReason:
                'Approbation cloud effectuée mais le transfert n\'est pas prêt '
                'à être expédié (statut « ${StockTransferStatus.label(status)} »).',
          );
        }
        return StockTransferCloudSyncResult(ok: true, remote: remote);
      } on Failure catch (error) {
        if (isAlreadyValidatedError(error.message)) {
          remote = await _remote.fetchTransfer(serverTransferId);
          status = remote['status'] as String? ?? '';
          if (isShippableStatus(status)) {
            await _local.applyRemoteStockTransferSnapshot(localTransferId, remote);
            await syncLocalReservations();
            return StockTransferCloudSyncResult(ok: true, remote: remote);
          }
        }
        rethrow;
      }
    }

    if (status != StockTransferStatus.draft) {
      await _local.applyRemoteStockTransferSnapshot(localTransferId, remote);
      await syncLocalReservations();
      if (requireShippable) {
        return StockTransferCloudSyncResult(
          ok: false,
          remote: remote,
          deferReason:
              'Le transfert côté serveur est en statut « ${StockTransferStatus.label(status)} » '
              'et ne peut pas être expédié. Actualisez la fiche transfert.',
        );
      }
      return StockTransferCloudSyncResult(ok: true, remote: remote);
    }

    try {
      remote = await _remote.validateTransfer(serverTransferId);
      status = remote['status'] as String? ?? StockTransferStatus.draft;
      await _local.applyRemoteStockTransferSnapshot(localTransferId, remote);
      await syncLocalReservations();

      if (requireShippable && !isShippableStatus(status)) {
        return StockTransferCloudSyncResult(
          ok: false,
          remote: remote,
          deferReason:
              'Validation cloud effectuée mais le transfert n\'est pas prêt à être expédié '
              '(statut « ${StockTransferStatus.label(status)} »).',
        );
      }

      return StockTransferCloudSyncResult(ok: true, remote: remote);
    } on Failure catch (error) {
      if (isAlreadyValidatedError(error.message)) {
        remote = await _remote.fetchTransfer(serverTransferId);
        status = remote['status'] as String? ?? '';
        if (isShippableStatus(status) ||
            (!requireShippable && status != StockTransferStatus.draft) ||
            (requireShippable && isPostShipStatus(status))) {
          await _local.applyRemoteStockTransferSnapshot(localTransferId, remote);
          await syncLocalReservations();
          return StockTransferCloudSyncResult(
            ok: true,
            remote: remote,
            alreadyComplete: requireShippable && isPostShipStatus(status),
          );
        }
      }
      if (isInsufficientStockError(error.message)) {
        return StockTransferCloudSyncResult(
          ok: false,
          deferReason:
              '${error.message} Synchronisez le stock produits/lots cloud '
              'depuis la boutique source puis réessayez.',
        );
      }
      rethrow;
    }
  }
}
