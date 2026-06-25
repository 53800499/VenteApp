/// File d'attente de synchronisation — implémentation V2/V3.
class SyncService {
  const SyncService();

  Future<void> processQueue() async {
    // Traitement asynchrone hors thread UI (offline-first).
  }
}
