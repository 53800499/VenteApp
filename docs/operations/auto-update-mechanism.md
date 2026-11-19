# Mécanisme de Mise à Jour Automatique Côté Client

Ce document décrit le fonctionnement du service de mise à jour automatique (`AppUpdateService`) intégré dans l'application cliente Flutter.

---

## 1. Déroulement de la Vérification au Démarrage

1. Lors du lancement de l'application (ou manuellement depuis les Paramètres $\rightarrow$ *"Vérifier les mises à jour"*), `AppUpdateService` effectue un appel GET vers l'API backend :
   ```http
   GET /api/v1/app-updates/check?platform=android&current_version=1.0.1
   ```
2. Si `has_update == true`, l'application compare les numéros de version semver (ex : `1.0.2` > `1.0.1`).
3. L'application affiche la boîte de dialogue `AppUpdateDialog` présentant :
   - Le numéro de la nouvelle version.
   - Les notes de version (Changelog en français).
   - Le caractère obligatoire ou optionnel.

---

## 2. Téléchargement Sécurisé & Installation Native

1. **Téléchargement avec Jauge de Progression** :
   Utilisation de `dio.download()` pour afficher la progression en pourcentage et les mégaoctets téléchargés dans le dialogue.
2. **Contrôle d'Intégrité SHA-256** :
   L'application calcule le hash SHA-256 du fichier téléchargé et le compare à la signature fournie par l'API. Si les empreintes diffèrent (fichier tronqué ou corrompu), l'installation est refusée.
3. **Déclenchement de l'Installeur Natif** :
   - **Sous Android** : Déclenchement de l'intention `ACTION_VIEW` avec le type MIME `application/vnd.android.package-archive` via le FileProvider sécurisé.
   - **Sous Windows** : Lancement de l'installeur silencieux ou interactif via `Process.start()`.

