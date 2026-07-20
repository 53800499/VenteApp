import '../entities/stock_transfer.dart';

/// Règles d'affichage des actions transfert lorsque la sync cloud est active.
abstract final class StockTransferCloudGate {
  static bool canValidate({
    required StockTransfer transfer,
    required bool cloudSyncEnabled,
  }) {
    return StockTransferStatus.canValidate(transfer.status);
  }

  static bool canShip({
    required StockTransfer transfer,
    required bool cloudSyncEnabled,
  }) {
    if (!StockTransferStatus.canShip(transfer.status)) return false;
    if (!cloudSyncEnabled) return true;
    return transfer.isCreateSynced &&
        !transfer.hasPendingCreate &&
        !transfer.hasPendingValidate;
  }

  static String? validateBlockedMessage(StockTransfer transfer) {
    if (transfer.hasPendingCreate || !transfer.isCreateSynced) {
      return 'Synchronisation du transfert en cours. '
          'La validation sera disponible une fois le transfert enregistré dans le cloud.';
    }
    return null;
  }

  static String? shipBlockedMessage(StockTransfer transfer) {
    if (transfer.hasPendingCreate || !transfer.isCreateSynced) {
      return 'Synchronisation du transfert en cours. '
          'L\'expédition sera disponible une fois le transfert enregistré dans le cloud.';
    }
    if (transfer.hasPendingValidate) {
      return 'Validation en cours de synchronisation avec le cloud. '
          'L\'expédition sera disponible une fois confirmée par le serveur.';
    }
    return null;
  }

  static bool isAwaitingCloudConfirmation(StockTransfer transfer) =>
      transfer.hasPendingCreate ||
      transfer.hasPendingValidate ||
      transfer.hasPendingReceive;

  /// En attente d'expédition cloud (n'empêche pas une nouvelle expédition partielle).
  static bool canReceive({
    required StockTransfer transfer,
    required bool cloudSyncEnabled,
  }) {
    return StockTransferStatus.canReceive(transfer.status);
  }

  static String? receiveBlockedMessage(StockTransfer transfer) {
    if (!StockTransferStatus.canReceive(transfer.status)) {
      return 'Le transfert n\'est pas encore expédiable côté source.';
    }
    return null;
  }

  /// En attente d'expédition cloud (n'empêche pas une nouvelle expédition partielle).
  static bool isShipSyncPending(StockTransfer transfer) => transfer.hasPendingShip;
}
