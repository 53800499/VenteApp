/// Point d'extension pour la synchronisation descendante d'un module métier.
abstract class RemoteSyncPort {
  String get moduleName;

  Future<void> syncFromRemote({required int shopId});
}
