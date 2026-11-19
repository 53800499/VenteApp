# Chiffrement & Stockage Sécurisé Local

Ce document détaille l'implémentation du chiffrement matériel et logiciel sur les terminaux clients ARIKE.

---

## 1. Intégration de `sqlite3mc` (Multiple Ciphers)

Dans le fichier `frontend/pubspec.yaml`, le hook utilisateur configure la compilation SQLite native :

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

À l'ouverture de la base de données, la clé maîtresse est transmise via l'instruction SQL native :
```sql
PRAGMA key = 'CLE_SECRETE_AES256_BASE64';
PRAGMA cipher = 'sqlcipher';
```

---

## 2. Stockage Sécurisé avec `flutter_secure_storage`

La clé de déchiffrement de la base locale n'est jamais stockée en clair dans le système de fichiers :
- **Sous Android** : Utilisation du **KeyStore matériel Android** avec chiffrement AES-GCM 256 bits adossé au TEE (Trusted Execution Environment) du processeur.
- **Sous Windows** : Utilisation de l'API de protection des données **Windows DPAPI** (Data Protection API) liée à la session utilisateur Windows active.

