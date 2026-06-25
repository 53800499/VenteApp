import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _prefsKey = 'api_base_url';

  static String get prefsKey => _prefsKey;

  /// URL par défaut selon la plateforme (sans override utilisateur).
  static String defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3010/api';
    }
    return 'http://localhost:3010/api';
  }

  /// Résout l'URL effective : dart-define → [customUrl] → défaut plateforme.
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
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
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
