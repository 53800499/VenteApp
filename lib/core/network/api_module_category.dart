/// Catégories de connectivité par module (règle produit VenteApp).
///
/// | Catégorie | Modules | Lecture offline | Écriture offline |
/// |-----------|---------|-----------------|------------------|
/// | [onlinePreferred] | Paramètres, Alertes, Équipe, Boutiques | Cache / Drift local | Bloquée (message clair) |
/// | [offlineFirst] | Ventes, Stock, Clients, Dettes | Toujours locale | Locale + file sync |
/// | [hybridRead] | Dashboard, Rapports | Locale | Refresh serveur si online |
enum ApiModuleCategory {
  /// Serveur préféré : afficher le cache local en lecture, pas de déconnexion réseau.
  onlinePreferred,

  /// Offline-first : jamais de déconnexion sur panne réseau.
  offlineFirst,

  /// Lecture hybride : local par défaut, enrichissement serveur si possible.
  hybridRead,
}
