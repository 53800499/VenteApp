import '../../../../core/sync/remote_sync_port.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/debts/domain/repositories/debt_repository.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/sales/domain/repositories/sale_repository.dart';

class CustomerRemoteSyncAdapter implements RemoteSyncPort {
  CustomerRemoteSyncAdapter(this._repository);

  final CustomerRepository _repository;

  @override
  String get moduleName => 'customers';

  @override
  Future<void> syncFromRemote({required int shopId}) {
    return _repository.syncFromRemote(shopId: shopId);
  }
}

class InventoryRemoteSyncAdapter implements RemoteSyncPort {
  InventoryRemoteSyncAdapter(this._repository);

  final InventoryRepository _repository;

  @override
  String get moduleName => 'inventory';

  @override
  Future<void> syncFromRemote({required int shopId}) {
    return _repository.syncFromRemote(shopId: shopId);
  }
}

class SalesRemoteSyncAdapter implements RemoteSyncPort {
  SalesRemoteSyncAdapter(this._repository);

  final SaleRepository _repository;

  @override
  String get moduleName => 'sales';

  @override
  Future<void> syncFromRemote({required int shopId}) {
    return _repository.syncFromRemote(shopId: shopId);
  }
}

class DebtsRemoteSyncAdapter implements RemoteSyncPort {
  DebtsRemoteSyncAdapter(this._repository);

  final DebtRepository _repository;

  @override
  String get moduleName => 'debts';

  @override
  Future<void> syncFromRemote({required int shopId}) {
    return _repository.syncFromRemote(shopId: shopId);
  }
}
