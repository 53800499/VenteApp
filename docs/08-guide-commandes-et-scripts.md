# 08 — Guide Complet des Commandes & Scripts du Frontend

Ce document recense et explique **l'intégralité des commandes CLI et scripts** utilisés pour configurer, exécuter, tester, générer le code Drift et compiler l'application **ARIKE (Flutter)** pour Android et Windows.

---

## 1. Commandes de Base & Gestion des Dépendances (`flutter pub`)

Toutes ces commandes s'exécutent depuis le dossier `frontend/` :

```bash
cd frontend
```

| Commande | Action & Rôle Technique |
| :--- | :--- |
| `flutter pub get` | Télécharge et installe l'ensemble des bibliothèques déclarées dans `pubspec.yaml`. |
| `flutter pub upgrade` | Met à jour les dépendances vers les versions compatibles les plus récentes. |
| `flutter pub outdated` | Affiche la liste des packages disposant de mises à jour majeures disponibles. |
| `flutter clean` | Supprime les répertoires de build temporaires (`build/`, `.dart_tool/`). Indispensable en cas d'erreur de compilation inexpliquée. |

---

## 2. Génération de Code Automatisée (`build_runner` / Drift)

Drift et les générateurs de code Dart ont besoin de compiler les fichiers `.g.dart` (tables de base de données, DAOs, requêtes SQL typées) :

| Commande | Action & Rôle Technique |
| :--- | :--- |
| `dart run build_runner build --delete-conflicting-outputs` | **Commande clé** : Génère l'ensemble du code Drift et SQLite en écrasant les anciens fichiers générés. À exécuter après toute modification d'une table dans `lib/core/database/tables/`. |
| `dart run build_runner watch` | Surveille les modifications de fichiers Dart en temps réel et re-génère le code à chaque sauvegarde (mode développement intensif). |

---

## 3. Commandes d'Exécution & Débogage (`flutter run`)

| Commande | Action & Cible |
| :--- | :--- |
| `flutter run` | Lance l'application sur le premier appareil ou émulateur détecté. |
| `flutter run -d windows` | Lance l'application directement sous **Windows Desktop** natif. |
| `flutter run -d <device_id>` | Lance l'application sur un terminal Android spécifique (obtenu via `flutter devices`). |
| `flutter run --release` | Exécute l'application en mode Release optimisé (sans surcoût du débogueur, pour tester les performances réelles). |

### Raccourcis Clavier Utiles pendant le `flutter run` :
- `r` : **Hot Reload** (recharge les modifications de code UI en moins d'une seconde sans perdre l'état du panier).
- `R` : **Hot Restart** (redémarre complètement l'application en réinitialisant l'état en mémoire).
- `q` : Quitte la session de débogage.

---

## 4. Tests & Qualité du Code

| Commande | Action & Rôle Technique |
| :--- | :--- |
| `flutter analyze` | Analyse statique du code Dart selon les règles définies dans `analysis_options.yaml`. |
| `flutter test` | Exécute l'ensemble des tests unitaires et de BLoC du dossier `test/`. |
| `flutter test --coverage` | Exécute les tests et génère le fichier de couverture `coverage/lcov.info`. |
| `flutter test test/features/cash_sessions/` | Exécute uniquement les tests d'un module spécifique. |

---

## 5. Commandes de Compilation de Production (Build Release)

### 5.1 Pour Android
```bash
# Option A : APK Universel (Tout-en-un, idéal pour distribution directe et WhatsApp)
flutter build apk --release

# Option B : APKs Séparés par Architecture CPU (Taille réduite : ARM64, ARMv7, x86_64)
flutter build apk --release --split-per-abi

# Option C : Android App Bundle (Pour publication sur le Google Play Store)
flutter build appbundle --release
```

### 5.2 Pour Windows Desktop
```bash
# Compilation du binaire natif 64-bit
flutter build windows --release

# Emplacement du binaire généré :
# frontend/build/windows/x64/runner/Release/ARIKE.exe
```

### 5.3 Création de l'Installeur Windows (Inno Setup)
Si Inno Setup est installé sur votre ordinateur :
```powershell
# Compiler l'installeur exécutable standalone
iscc windows/packaging/arike_setup.iss
```

---

## 6. Commandes Utiles Android Debug Bridge (ADB)

Pour tester sur un smartphone Android connecté en câble USB :

```bash
# 1. Vérifier la détection du téléphone
adb devices

# 2. Rediriger le port de l'API locale backend vers le smartphone
# Permet au téléphone d'accéder à l'API de votre PC via http://localhost:3000
adb reverse tcp:3000 tcp:3000

# 3. Installer directement l'APK compilé sur le smartphone
adb install -r build/app/outputs/flutter-apk/app-release.apk

# 4. Suivre les logs de l'application en direct
adb logcat -s flutter
```
