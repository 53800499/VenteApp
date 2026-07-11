/// Configuration OAuth Google (Drive).
///
/// Android exige un **client OAuth Web** via [serverClientId] (erreur ApiException:10
/// sinon). Créez-le dans Google Cloud Console → Identifiants → OAuth 2.0 (Web),
/// puis ajoutez aussi un client Android (SHA-1 + `com.venteapp`).
///
/// Surcharge possible à la compilation :
/// `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com`
///
/// Important : le flag doit être `NOM=VALEUR`, pas seulement l'ID client.
abstract final class GoogleOAuthConfig {
  /// Client OAuth Web ARIKE (public — identique à la console Google).
  static const defaultWebClientId =
      '102635823631-ng5d3or7895o66l3bc1qh8k8jvheic8d.apps.googleusercontent.com';

  static const _fromEnv = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static String get serverClientId =>
      _fromEnv.isNotEmpty ? _fromEnv : defaultWebClientId;

  static bool get isConfigured => serverClientId.isNotEmpty;
}
