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

  /// Quantité d'expédition rejetée : souvent un retry alors que le cloud a déjà expédié.
  static bool isShipQuantityTooHighError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('quantité expédiée trop élevée') ||
        lower.contains('quantite expediee trop elevee');
  }

  static bool canResolveDiscrepancyOnRemote(String status) =>
      status == StockTransferStatus.partiallyShipped ||
      status == StockTransferStatus.shipped ||
      status == StockTransferStatus.partiallyReceived ||
      status == StockTransferStatus.received;

  static bool isDiscrepancyNotAllowedError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('ne peut pas recevoir de résolution') ||
        lower.contains('ne peut pas recevoir de resolution');
  }

  static bool isAlreadyValidatedError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('brouillon') && lower.contains('valid');
  }

  static bool isInsufficientStockError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('stock insuffisant') || lower.contains('stock insuff');
  }

  static bool isTerminalClosedStatus(String status) =>
      status == StockTransferStatus.cancelled ||
      status == StockTransferStatus.closed ||
      status == StockTransferStatus.closedWithException;

  /// Limite les qtés d'expédition au pending cloud (évite le retry post-ship).
  static Map<int, int> clampShipQuantitiesToRemotePending({
    required Map<int, int> quantitiesByLocalItemId,
    required List<Map<String, dynamic>> mapping,
    required List<Map<String, dynamic>> remoteItems,
  }) {
    final remoteById = <int, Map<String, dynamic>>{};
    for (final ri in remoteItems) {
      final id = StockTransferLocalDatasource.coerceRemoteInt(ri['id']);
      if (id != null) remoteById[id] = ri;
    }

    final clamped = <int, int>{};
    for (final row in mapping) {
      final localItemId = row['localItemId'] as int?;
      final remoteItemId = row['remoteItemId'] as int?;
      if (localItemId == null || remoteItemId == null) continue;
      final qty = quantitiesByLocalItemId[localItemId] ?? 0;
      if (qty <= 0) continue;
      final remote = remoteById[remoteItemId];
      if (remote == null) continue;
      final requested =
          StockTransferLocalDatasource.coerceRemoteInt(
            remote['quantityRequested'],
          ) ??
          0;
      final shipped =
          StockTransferLocalDatasource.coerceRemoteInt(
            remote['quantityShipped'],
          ) ??
          0;
      final pending = requested - shipped;
      if (pending <= 0) continue;
      clamped[localItemId] = qty > pending ? pending : qty;
    }
    return clamped;
  }

  /// True si chaque ligne à expédier a déjà un pending cloud à 0.
  static bool remoteAlreadyCoversShipQuantities({
    required Map<int, int> quantitiesByLocalItemId,
    required List<Map<String, dynamic>> mapping,
    required List<Map<String, dynamic>> remoteItems,
  }) {
    final remoteById = <int, Map<String, dynamic>>{};
    for (final ri in remoteItems) {
      final id = StockTransferLocalDatasource.coerceRemoteInt(ri['id']);
      if (id != null) remoteById[id] = ri;
    }

    var sawRequested = false;
    for (final row in mapping) {
      final localItemId = row['localItemId'] as int?;
      final remoteItemId = row['remoteItemId'] as int?;
      if (localItemId == null || remoteItemId == null) continue;
      final qty = quantitiesByLocalItemId[localItemId] ?? 0;
      if (qty <= 0) continue;
      sawRequested = true;
      final remote = remoteById[remoteItemId];
      if (remote == null) return false;
      final requested =
          StockTransferLocalDatasource.coerceRemoteInt(
            remote['quantityRequested'],
          ) ??
          0;
      final shipped =
          StockTransferLocalDatasource.coerceRemoteInt(
            remote['quantityShipped'],
          ) ??
          0;
      if (requested - shipped > 0) return false;
    }
    return sawRequested;
  }

  /// Limite les qtés de réception au pending cloud (retry post-receive).
  static Map<int, int> clampReceiveQuantitiesToRemotePending({
    required Map<int, int> quantitiesByLocalItemId,
    required List<Map<String, dynamic>> mapping,
    required List<Map<String, dynamic>> remoteItems,
    int? remoteShipmentId,
  }) {
    final remoteById = <int, Map<String, dynamic>>{};
    for (final ri in remoteItems) {
      final id = StockTransferLocalDatasource.coerceRemoteInt(ri['id']);
      if (id != null) remoteById[id] = ri;
    }

    final clamped = <int, int>{};
    for (final row in mapping) {
      final localItemId = row['localItemId'] as int?;
      final remoteItemId = row['remoteItemId'] as int?;
      if (localItemId == null || remoteItemId == null) continue;
      final qty = quantitiesByLocalItemId[localItemId] ?? 0;
      if (qty <= 0) continue;
      final remote = remoteById[remoteItemId];
      if (remote == null) continue;
      final pending = _remotePendingReceive(remote, remoteShipmentId);
      if (pending <= 0) continue;
      clamped[localItemId] = qty > pending ? pending : qty;
    }
    return clamped;
  }

  static bool remoteAlreadyCoversReceiveQuantities({
    required Map<int, int> quantitiesByLocalItemId,
    required List<Map<String, dynamic>> mapping,
    required List<Map<String, dynamic>> remoteItems,
    int? remoteShipmentId,
  }) {
    final remoteById = <int, Map<String, dynamic>>{};
    for (final ri in remoteItems) {
      final id = StockTransferLocalDatasource.coerceRemoteInt(ri['id']);
      if (id != null) remoteById[id] = ri;
    }

    var sawRequested = false;
    for (final row in mapping) {
      final localItemId = row['localItemId'] as int?;
      final remoteItemId = row['remoteItemId'] as int?;
      if (localItemId == null || remoteItemId == null) continue;
      final qty = quantitiesByLocalItemId[localItemId] ?? 0;
      if (qty <= 0) continue;
      sawRequested = true;
      final remote = remoteById[remoteItemId];
      if (remote == null) return false;
      if (_remotePendingReceive(remote, remoteShipmentId) > 0) return false;
    }
    return sawRequested;
  }

  static int _remotePendingReceive(
    Map<String, dynamic> remoteItem,
    int? remoteShipmentId,
  ) {
    if (remoteShipmentId != null) {
      final lotLines = (remoteItem['lotLines'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];
      var pending = 0;
      for (final line in lotLines) {
        final shipmentId =
            StockTransferLocalDatasource.coerceRemoteInt(line['shipmentId']);
        if (shipmentId != remoteShipmentId) continue;
        final qty =
            StockTransferLocalDatasource.coerceRemoteInt(line['quantity']) ?? 0;
        final received =
            StockTransferLocalDatasource.coerceRemoteInt(
              line['quantityReceived'],
            ) ??
            0;
        pending += qty - received;
      }
      return pending > 0 ? pending : 0;
    }
    final shipped =
        StockTransferLocalDatasource.coerceRemoteInt(
          remoteItem['quantityShipped'],
        ) ??
        0;
    final received =
        StockTransferLocalDatasource.coerceRemoteInt(
          remoteItem['quantityReceived'],
        ) ??
        0;
    final pending = shipped - received;
    return pending > 0 ? pending : 0;
  }

  static bool isReceiveQuantityTooHighError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('trop élevées') ||
        lower.contains('trop elevees') ||
        lower.contains('trop élevée') ||
        lower.contains('trop elevee');
  }

  static bool isNotReadyToReceiveError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('ne peut pas être réceptionn') ||
        lower.contains('ne peut pas etre receptionn') ||
        lower.contains('ne peut pas être recu') ||
        lower.contains('pas encore expédi');
  }

  static int openDiscrepancyQtyOnRemoteItem({
    required Map<String, dynamic> remoteItem,
    required List<Map<String, dynamic>> discrepancies,
    required int remoteItemId,
  }) {
    final shipped =
        StockTransferLocalDatasource.coerceRemoteInt(
          remoteItem['quantityShipped'],
        ) ??
        0;
    final received =
        StockTransferLocalDatasource.coerceRemoteInt(
          remoteItem['quantityReceived'],
        ) ??
        0;
    final gap = shipped - received;
    if (gap <= 0) return 0;
    var resolved = 0;
    for (final row in discrepancies) {
      final itemId = StockTransferLocalDatasource.coerceRemoteInt(
        row['transferItemId'] ?? row['itemId'],
      );
      if (itemId != remoteItemId) continue;
      resolved +=
          StockTransferLocalDatasource.coerceRemoteInt(row['quantity']) ?? 0;
    }
    final open = gap - resolved;
    return open > 0 ? open : 0;
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
