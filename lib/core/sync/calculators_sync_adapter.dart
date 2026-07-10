import 'remote_sync_port.dart';
import '../../features/calculators/domain/repositories/calculators_repository.dart';

class CalculatorsRemoteSyncAdapter implements RemoteSyncPort {
  CalculatorsRemoteSyncAdapter(this._repository);

  final CalculatorsRepository _repository;

  @override
  String get moduleName => 'calculators';

  @override
  Future<void> syncFromRemote({required int shopId}) {
    return _repository.syncFromRemote(shopId: shopId);
  }
}
