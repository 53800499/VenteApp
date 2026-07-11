/// Niveau fonctionnel ARIKE (SFD / BDD).
///
/// - [v1] : 100 % local, `cloudSyncEnabled = false`, une boutique
/// - [v2] : sync cloud activée, file `sync_queue`, une boutique
/// - [v3] : multi-boutiques (`shop_id` sur toutes les tables), sync par boutique active
enum AppReleaseTier {
  v1,
  v2,
  v3,
}

extension AppReleaseTierX on AppReleaseTier {
  bool get supportsCloudSync => this == AppReleaseTier.v2 || this == AppReleaseTier.v3;

  bool get supportsSyncQueue => supportsCloudSync;

  bool get isMultiShop => this == AppReleaseTier.v3;

  String get label => switch (this) {
        AppReleaseTier.v1 => 'V1 — local',
        AppReleaseTier.v2 => 'V2 — cloud',
        AppReleaseTier.v3 => 'V3 — multi-boutiques',
      };
}
