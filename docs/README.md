# Documentation Technique & Métier Frontend — ARIKE (Flutter)

Bienvenue dans la documentation officielle et exhaustive de l'application cliente **ARIKE**, l'ERP de poche populaire, infaillible et **100% Offline-First**, développé avec **Flutter 3.x** pour les terminaux **Android** (smartphones, tablettes, terminaux POS tactiles) et **Windows Desktop** (PC de caisse, ordinateurs de gestion).

---

## 1. Vue d'Ensemble & Mission de l'Application

ARIKE a été conçue pour résoudre les défis réels du commerce en Afrique subsaharienne :
1. **Fonctionnement Sans Connexion (Offline-First)** : L'application n'attend jamais le réseau pour enregistrer une vente, créer un article, ouvrir une caisse ou délivrer un ticket. Toutes les lectures et écritures se font d'abord dans la base de données locale chiffrée (Drift / SQLite).
2. **Encaissement Ultra-Rapide** : Vente finalisée en moins de 3 secondes avec impression thermique immédiate (Bluetooth ESC/POS) ou partage de reçu par WhatsApp / SMS.
3. **Sécurité Financière & Zéro Tricherie** : Contrôle des sessions de caisse avec détection automatique des écarts, blocage par code PIN gérant, et journal d'audit local inaltérable.
4. **Recouvrement Facilité des Crédits** : Fiches clients avec soldes débiteurs et bouton de relance automatique pré-rempli pour WhatsApp.

---

## 2. Table des Matières de la Documentation Frontend

### 2.1 Guides Généraux, Commandes, Manuel & Mises à Jour
- **[01-architecture-clean-code-et-bloc.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/01-architecture-clean-code-et-bloc.md)** : Clean Architecture (Domain, Data, Presentation), gestion d'état BLoC, injection de dépendances GetIt.
- **[02-base-de-donnees-locale-drift.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/02-base-de-donnees-locale-drift.md)** : Modèle de données local, tables Drift, DAOs, chiffrement `sqlite3mc`, stockage sécurisé des clés.
- **[03-moteur-synchronisation-et-resolution-conflits.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/03-moteur-synchronisation-et-resolution-conflits.md)** : File d'attente d'envoi (`SyncQueue`), détection réseau, fusion des deltas, écran de résolution des conflits.
- **[04-modules-et-parcours-fonctionnels.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/04-modules-et-parcours-fonctionnels.md)** : Caisses, Ventes POS, Dettes & WhatsApp, Gestion des stocks, Sauvegarde Google Drive chiffrée, Saisie vocale.
- **[05-integrations-materielles-et-peripheriques.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/05-integrations-materielles-et-peripheriques.md)** : Imprimantes thermiques Bluetooth/USB (ESC/POS), douchettes et scanners caméra de codes-barres, biométrie.
- **[06-systeme-de-theme-et-ui-responsive.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/06-systeme-de-theme-et-ui-responsive.md)** : Charte visuelle émeraude & or, adaptation mobile vs desktop, contrôleur de mise à l'échelle d'interface.
- **[07-compilation-deploiement-et-auto-update.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/07-compilation-deploiement-et-auto-update.md)** : Génération de l'APK signé Android, installeur Windows, système de mise à jour automatique intégrée.
- **[08-guide-commandes-et-scripts.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/08-guide-commandes-et-scripts.md)** : **Toutes les commandes CLI du client** (`flutter pub`, `build_runner`, `flutter build apk`, `flutter build windows`, `adb`).
- **[09-manuel-utilisation-plateforme.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/09-manuel-utilisation-plateforme.md)** : **Manuel pratique d'utilisation quotidienne** (ouverture caisse, encaissement 3s, relance WhatsApp, sauvegarde Google Drive, raccourcis PC).
- **[10-guide-mises-a-jour-clients-et-auto-update.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/10-guide-mises-a-jour-clients-et-auto-update.md)** : **Guide de publication et d'auto-update** (incrément de version `pubspec.yaml`, compilation, contrôle d'intégrité SHA-256, installation native Android/Windows et gestion offline).

### 2.2 Dossiers Spécialisés
- **Dossier `adr/` (Architecture Decision Records)** :
  - **[0001-choix-flutter-cross-platform.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/adr/0001-choix-flutter-cross-platform.md)**
  - **[0002-choix-drift-sqlite-offline-first.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/adr/0002-choix-drift-sqlite-offline-first.md)**
  - **[0003-choix-bloc-pattern-clean-architecture.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/adr/0003-choix-bloc-pattern-clean-architecture.md)**
- **Dossier `architecture/`** :
  - **[client-architecture.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/architecture/client-architecture.md)**
  - **[state-management.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/architecture/state-management.md)**
- **Dossier `database/`** :
  - **[local-schema-reference.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/database/local-schema-reference.md)**
  - **[encryption-and-storage.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/database/encryption-and-storage.md)**
- **Dossier `deployment/`** :
  - **[android-build-guide.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/deployment/android-build-guide.md)**
  - **[windows-packaging.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/deployment/windows-packaging.md)**
- **Dossier `operations/`** :
  - **[auto-update-mechanism.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/operations/auto-update-mechanism.md)**
  - **[telemetry-and-diagnostics.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/operations/telemetry-and-diagnostics.md)**
- **Dossier `security/`** :
  - **[device-security-and-biometrics.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/security/device-security-and-biometrics.md)**
  - **[app-lock-and-session.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/security/app-lock-and-session.md)**
- **Dossier `testing/`** :
  - **[testing-guide.md](file:///c:/Sikirou/eskay/VenteApp/frontend/docs/testing/testing-guide.md)**

---

## 3. Démarrage Rapide

```bash
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```
