# Sécurité Matérielle & Authentification Biométrique

Ce document détaille l'utilisation des capteurs biométriques et la protection matérielle sur les terminaux clients ARIKE.

---

## 1. Authentification Biométrique (`local_auth`)

L'application permet d'associer le capteur d'empreinte digitale ou la reconnaissance faciale du smartphone :

```dart
final LocalAuthentication auth = LocalAuthentication();
final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;

if (canAuthenticateWithBiometrics) {
  final bool didAuthenticate = await auth.authenticate(
    localizedReason: 'Scannez votre empreinte pour déverrouiller ARIKE',
    options: const AuthenticationOptions(
      biometricOnly: true,
      stickyAuth: true,
    ),
  );
}
```

---

## 2. Règle du Démarrage à Froid du PIN (`PinColdStartPolicy`)

Au démarrage complet de l'application (Cold Start) ou après un redémarrage du smartphone :
- L'utilisation exclusive de l'empreinte digitale est temporairement insuffisante.
- L'utilisateur doit obligatoirement saisir son code PIN gérant ou son mot de passe de compte une première fois pour déverrouiller la clé maîtresse dans le Keystore.
- Ce mécanisme protège le commerçant contre toute tentative de déverrouillage forcé pendant son sommeil ou sous la contrainte.

