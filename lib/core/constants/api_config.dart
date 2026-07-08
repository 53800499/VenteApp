abstract final class ApiConfig {
  static const _prefsKey = 'api_base_url';

  /// Backend cloud (Render) — défaut hors override utilisateur.
  static const productionBaseUrl =
      'https://venteappbackend-1.onrender.com/api';

  static String get prefsKey => _prefsKey;

  /// URL par défaut : dart-define `API_BASE_URL` ou backend Render.
  static String defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return productionBaseUrl;
  }

  /// Résout l'URL effective : dart-define → [customUrl] → défaut cloud.
  static String resolveBaseUrl({String? customUrl}) {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return normalizeUrl(customUrl.trim());
    }

    return defaultBaseUrl();
  }

  static String normalizeUrl(String url) {
    var normalized = url;
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.endsWith('/api')) {
      normalized = '$normalized/api';
    }
    return normalized;
  }

  static const offlineGraceDays = 7;
  static const offlineGraceMs = offlineGraceDays * 24 * 60 * 60 * 1000;

  /// Seuil « hors ligne récent » (Niveau 1) : sous ce délai depuis le dernier
  /// contact serveur, tout fonctionne avec un simple indicateur discret.
  static const offlineRecentHours = 24;
  static const offlineRecentMs = offlineRecentHours * 60 * 60 * 1000;

  /// Fenêtre (20–30 min) pendant laquelle le cloud reste accessible après un
  /// refresh rejeté, avant dialogue et effacement des identifiants.
  static const serverAccessibleGraceMinutes = 25;
  static const serverAccessibleGraceMs =
      serverAccessibleGraceMinutes * 60 * 1000;

  @Deprecated('Utiliser serverAccessibleGraceMs')
  static const cloudSessionPromptGraceMs = serverAccessibleGraceMs;

  /// Durée pendant laquelle un PIN validé peut servir à réparer la session cloud
  /// (mémoire vive uniquement — jamais persisté).
  static const recentPinProofMinutes = 3;
  static const recentPinProofTtlMs = recentPinProofMinutes * 60 * 1000;

  /// Délai max pour un login serveur par PIN lors d'une réparation cloud.
  static const recentPinRepairTimeout = Duration(seconds: 12);

  /// Durée de la session locale (indépendante du verrouillage PIN).
  static const localSessionMaxDays = 3650;
  static const localSessionMaxMs =
      localSessionMaxDays * 24 * 60 * 60 * 1000;
}
