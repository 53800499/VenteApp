# Verrouillage Automatique d'Inactivité & Réparation de Session

Ce document décrit le contrôleur de verrouillage d'écran (`AppLockController`) et le service de réparation de session cloud (`CloudSessionRepairService`).

---

## 1. Verrouillage Automatique par Inactivité (`AppLockController`)

Pour éviter qu'un client malveillant ne touche à la caisse lorsque le vendeur tourne le dos :
- Un écouteur d'inactivité global (`Listener` ou `WidgetsBindingObserver`) réinitialise un chronomètre à chaque frappe tactile.
- Si aucune interaction n'est détectée pendant un délai paramétrable (ex : 3 ou 5 minutes), l'application passe immédiatement en mode verrouillé.
- L'écran de caisse est masqué par un rideau opaque exigeant le code PIN à 4 chiffres ou l'empreinte digitale pour reprendre la session de vente.

---

## 2. Réparation de Session Cloud par PIN (`CloudSessionRepairService`)

Lorsqu'un appareil reste hors-ligne pendant plus de 30 jours, son jeton de rafraîchissement cloud expire naturellement :
- L'application **ne déconnecte pas** l'utilisateur pour ne pas bloquer ses ventes locales.
- Dès que le réseau réapparaît, `CloudSessionGuard` détecte la péremption du jeton.
- L'application affiche la boîte de dialogue `CloudSessionPinRepairDialog`.
- La saisie du code PIN gérant permet de renégocier instantanément une nouvelle session cloud avec le backend sans avoir à se déconnecter ni retaper le mot de passe long du compte.

