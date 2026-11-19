# Télémétrie, Diagnostics & Journalisation Locale

Ce document décrit les outils de diagnostic intégrés à l'application Flutter pour assister les commerçants en cas de dysfonctionnement.

---

## 1. Diagnostics Réseau & État de Connectivité

L'application intègre un écran de diagnostic (`DiagnosticPage` ou vue dans `SyncCenterPage`) affichant :
- **État Réseau** : WiFi, Données Mobiles (4G/3G), ou Déconnecté (`connectivity_plus`).
- **Ping Serveur** : Temps de réponse en millisecondes vers l'API ARIKE.
- **Taille de la File d'Attente Locale** : Nombre d'opérations en attente de synchronisation (`SyncQueueTable.count()`).
- **Dernière Synchronisation Réussie** : Horodatage précis du dernier cycle d'échange.

---

## 2. Capture des Exceptions Non Gérées

Dans `main.dart`, les erreurs d'exécution Dart et Flutter sont interceptées par :
- `FlutterError.onError` pour les erreurs de rendu UI.
- `PlatformDispatcher.instance.onError` pour les exceptions asynchrones non capturées.
- Les erreurs sont écrites dans un fichier tournant local `arike_crash.log` et affichées sous forme d'alerte conviviale à l'utilisateur plutôt que d'afficher l'écran rouge d'erreur de Flutter.

