# ADR 0002 — Choix de Drift et SQLite Chiffré pour le Moteur Offline-First

## Statut
Accepté

## Contexte
L'application doit fonctionner en totale autonomie sans réseau Internet. Nous avions le choix entre des bases NoSQL type clé-valeur (Hive, ObjectBox) ou une base relationnelle SQL typée (Drift / SQLite).

## Décision
Nous avons sélectionné **Drift (Moor) adossé à SQLite** avec l'extension de chiffrement **`sqlite3mc`** :
- **Intégrité Relationnelle Forte** : Les modèles commerciaux exigent des relations strictes (Ventes $\rightarrow$ Lignes d'articles $\rightarrow$ Produits $\rightarrow$ Catégories $\rightarrow$ Caisses).
- **Requêtes Réactives Typées (Streams Dart)** : Drift génère du code Dart fortement typé et permet d'écouter les modifications de données en temps réel (`watch()`).
- **Chiffrement Transparent au Repos (AES-256)** : Grâce au hook `sqlite3mc`, l'intégralité du fichier physique de base de données est chiffrée, protégeant le chiffre d'affaires et les dettes clients contre toute extraction pirate.

## Conséquences
- Zéro compromis sur la rigueur comptable.
- Nécessité de lancer `build_runner` lors de l'ajout ou de la modification de tables Drift.

