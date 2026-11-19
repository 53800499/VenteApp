# ADR 0001 — Choix de Flutter pour le Support Multiplateforme (Android & Windows)

## Statut
Accepté

## Contexte
ARIKE doit fonctionner sur les smartphones des commerçants sur les marchés d'Afrique (majoritairement des téléphones Android d'entrée à milieu de gamme) ainsi que sur les ordinateurs portables et PC de caisse fixes dans les magasins (Windows 10/11). Développer deux bases de code séparées (ex : Kotlin pour Android et C#/WPF pour Windows) aurait doublé le temps de développement et risqué des divergences dans les calculs comptables.

## Décision
Nous avons choisi **Flutter** (Google Dart) comme technologie client unique :
- **Base de Code Unique (Single Codebase)** : 100% de la logique métier (calculs de caisse, modèles Drift, BLoCs, cryptographie) est partagée entre Android et Windows.
- **Rendu Haute Performance à 60/120 FPS** : Grâce au moteur graphique Skia/Impeller, les listes de milliers de produits défilent avec une fluidité absolue même sur les téléphones modestes.
- **Support Natif des Périphériques POS** : Prise en charge transparente des imprimantes thermiques Bluetooth sous Android et des imprimantes USB/réseau sous Windows.

## Conséquences
- Une seule équipe de développeurs maintient l'ensemble des plateformes clientes.
- Nécessité de soigner l'adaptation responsive (formats d'écrans mobiles vs grands écrans de bureau).

