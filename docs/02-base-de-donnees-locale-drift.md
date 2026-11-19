# 02 — Base de Données Locale Chiffrée (Drift / SQLite)

Ce document décrit le moteur de stockage local de **ARIKE**, basé sur **Drift** (ORM typé pour Dart/Flutter) et **SQLite**, intégrant le chiffrement au repos via **`sqlite3mc`** (Multiple Ciphers).

---

## 1. Pourquoi Drift & SQLite ?

L'application ARIKE doit manipuler des milliers d'articles, des dizaines de milliers de lignes de vente et des historiques complets de mouvements de caisse avec une fluidité absolue à 60/120 images par seconde :

1. **Performances Requêtes Relationnelles** : Jointures SQL complexes (ex : total des ventes du jour par catégorie ou bénéfice net par article) exécutées en moins de 10 millisecondes en local.
2. **Réactivité Native (Streams)** : Grâce aux méthodes `.watch()` de Drift, l'interface utilisateur se met à jour automatiquement dès qu'une modification survient en base (ex : décrémentation du stock visible instantanément sur le catalogue).
3. **Sécurité & Confidentialité des Données** : Chiffrement intégral de la base de données au repos (AES-256) pour protéger les données du commerçant en cas de vol ou de perte du smartphone.

---

## 2. Chiffrement de la Base au Repos (`sqlite3mc`)

La base de données locale est protégée par un chiffrement transparent au niveau bloc :

```mermaid
flowchart LR
    A[Génération Clé Aléatoire 256 bits] --> B[Stockage Sécurisé: flutter_secure_storage]
    B --> C[Android Keystore / Windows DPAPI]
    C --> D[Déchiffrement Clé au démarrage de l'app]
    D --> E[Ouverture de la base Drift avec PRAGMA key]
    E --> F[Fichier SQLite Chiffré sur le disque]
```

- **Clé de Chiffrement** : Générée cryptographiquement lors du premier lancement de l'application (`DatabaseKeyStorage`).
- **Stockage Matériel** : Stockée dans le Keystore sécurisé matériel sous Android (TEE/SE) et via le Windows Credential Manager / DPAPI sous Windows.
- **Résistance à l'Extraction** : Même en cas de dump de la mémoire flash ou d'accès root au smartphone, le fichier `.sqlite` brut est illisible sans la clé maîtresse.

---

## 3. Schéma des Tables Locales Majeures

Les tables Drift sont déclarées dans `lib/core/database/tables/` :

### 3.1 Table `CashSessionsTable`
```dart
class CashSessionsTable extends Table {
  TextColumn get id => text()(); // UUID local
  TextColumn get shopId => text()();
  TextColumn get userId => text()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  RealColumn get openingCashAmount => real()();
  RealColumn get expectedCashAmount => real().nullable()();
  RealColumn get actualCashAmount => real().nullable()();
  RealColumn get discrepancyAmount => real().nullable()();
  TextColumn get discrepancyReason => text().nullable()();
  TextColumn get status => text()(); // OPEN, CLOSED, PENDING_APPROVAL
  TextColumn get verifiedByUserId => text().nullable()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 3.2 Table `SyncQueueTable` (File d'Attente de Synchronisation)
Chaque mutation locale génère un enregistrement dans cette table :
```dart
class SyncQueueTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'sale', 'cash_session', 'product'
  TextColumn get entityId => text()();
  TextColumn get action => text()(); // 'CREATE', 'UPDATE', 'DELETE'
  TextColumn get payload => text()(); // JSON sérialisé
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}
```

---

## 4. Requêtes Réactives vs Requêtes Ponctuelles

### Requête Réactive (Stream)
Utilisée pour alimenter les listes en temps réel dans l'interface :
```dart
// Écoute les modifications de la session de caisse active
Stream<CashSessionEntity?> watchCurrentCashSession(String shopId) {
  return (select(cashSessionsTable)
        ..where((tbl) => tbl.shopId.equals(shopId) & tbl.status.equals('OPEN')))
      .watchSingleOrNull()
      .map((row) => row?.toDomain());
}
```

### Requête Ponctuelle (One-Shot)
Utilisée pour les calculs de clôture ou les vérifications transactionnelles :
```dart
Future<double> getLiveCashTotal(String sessionId) async {
  final query = selectOnly(cashMovementsTable)
    ..addColumns([cashMovementsTable.amount.sum()])
    ..where(cashMovementsTable.sessionId.equals(sessionId));
  return await query.map((row) => row.read(cashMovementsTable.amount.sum())).getSingle() ?? 0.0;
}
```

