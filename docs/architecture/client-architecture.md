# Architecture Détaillée du Client Flutter

Ce document décrit l'organisation modulaire du frontend ARIKE et l'injection des dépendances via GetIt.

---

## 1. Découpage Structurel d'une Fonctionnalité (`Feature`)

Chaque fonctionnalité dans `frontend/lib/features/` respecte l'arborescence Clean Architecture suivante :

```text
features/cash_sessions/
├── data/
│   ├── datasources/
│   │   ├── cash_sessions_local_datasource.dart    # Requêtes Drift SQLite
│   │   └── cash_sessions_remote_datasource.dart   # Appels HTTP Dio (si connecté)
│   ├── models/
│   │   └── cash_session_model.dart                # Mapping JSON & Drift Row
│   └── repositories/
│       └── cash_sessions_repository_impl.dart     # Implémentation Offline-First
│
├── domain/
│   ├── entities/
│   │   └── cash_session_entity.dart               # Objet métier pur (Equatable)
│   ├── repositories/
│   │   └── cash_sessions_repository.dart          # Interface abstraite
│   └── usecases/
│       ├── open_cash_session_usecase.dart
│       ├── close_cash_session_usecase.dart
│       └── get_current_cash_session_usecase.dart
│
└── presentation/
    ├── bloc/
    │   ├── cash_sessions_bloc.dart                # Machine à états
    │   ├── cash_sessions_event.dart               # Événements utilisateur
    │   └── cash_sessions_state.dart               # États immuables
    ├── pages/
    │   └── cash_sessions_page.dart                # Écran principal
    └── widgets/
        ├── cash_count_dialog.dart                 # Dialogue de comptage
        └── discrepancy_warning_card.dart          # Carte d'alerte écart
```

---

## 2. Règle d'Or de l'Offline-First dans les Repositories

Dans toute implémentation de dépôt (`*_repository_impl.dart`) :
1. **Écriture Locale d'Abord** : L'opération est immédiatement persistée dans Drift SQLite.
2. **Enregistrement dans la File de Synchronisation** : La mutation est ajoutée dans `SyncQueueTable`.
3. **Retour Positif Immédiat à l'Utilisateur** : L'UI confirme l'action sans attendre le réseau.
4. **Tentative de Sync Arrière-Plan** : Si le réseau est disponible, le worker d'arrière-plan envoie le lot au backend.

