# ADR 0003 — Choix du Pattern BLoC et de la Clean Architecture

## Statut
Accepté

## Contexte
La gestion des états dans une application de caisse est particulièrement complexe (panier dynamique, calculs d'écarts de caisse, synchronisation en tâche de fond, changements de boutique, alertes de solde). Une mauvaise gestion d'état entraînerait des incohérences de calculs et des blocages de l'interface graphique.

## Décision
Nous avons adopté le pattern **BLoC (Business Logic Component)** combiné à la **Clean Architecture** (Uncle Bob) :
- **Prévisibilité et Unidirectionnalité** : Les actions de l'utilisateur émettent des événements (`Event`), traités par le BLoC qui produit des états immuables (`State`).
- **Indépendance de la Logique Métier** : La couche Domaine (`domain/`) ne dépend d'aucune bibliothèque graphique Flutter. Elle peut être testée unitairement avec une rapidité extrême.
- **Séparation des Effets de Bord** : Utilisation de `BlocListener` pour les actions uniques (afficher un SnackBar, ouvrir une boîte de dialogue, imprimer un reçu) et de `BlocBuilder` pour le rendu visuel.

## Conséquences
- Architecture robuste, maintenable et standardisée sur l'ensemble des modules.
- Structure de code uniforme et facilement transmissible à de nouveaux développeurs.

