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
}
