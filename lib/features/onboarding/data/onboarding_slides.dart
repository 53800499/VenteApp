import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Données d'une slide de présentation module.
class OnboardingSlideData {
  const OnboardingSlideData({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.headline,
    required this.description,
    required this.highlights,
    this.gradientColors,
    this.desktopBadge,
    this.desktopBenefits,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String headline;
  final String description;
  final List<String> highlights;
  final List<Color>? gradientColors;
  final String? desktopBadge;
  final List<String>? desktopBenefits;
}

const onboardingSlides = <OnboardingSlideData>[
  OnboardingSlideData(
    icon: Icons.storefront_rounded,
    accentColor: AppColors.secondary,
    title: 'ARIKE',
    headline: 'Votre cockpit commercial',
    description:
        'Conçu pour les commerces et boutiques : puissant, fluide et prêt pour le terrain.',
    highlights: ['Offline-first', 'Multi-boutiques', 'Sécurisé'],
    gradientColors: [Color(0xFF0B6E4F), Color(0xFF084A36)],
    desktopBadge: 'STATION DE VENTE WINDOWS',
    desktopBenefits: [
      'Multi-panneaux optimisé pour grand écran et double moniteur',
      'Fonctionnement 100% hors-ligne avec base SQLite locale',
      'Lancement instantané et fluidité maximale sans latence',
    ],
  ),
  OnboardingSlideData(
    icon: Icons.dashboard_customize_outlined,
    accentColor: AppColors.secondary,
    title: 'Tableau de bord',
    headline: 'Pilotez votre activité en direct',
    description:
        'Chiffre d\'affaires du jour, volume de ventes, alertes stock et accès direct à la caisse.',
    highlights: ['KPI en direct', 'Ventes récentes', 'Alertes stock'],
    gradientColors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    desktopBadge: 'SUPERVISION EN TEMPS RÉEL',
    desktopBenefits: [
      'Indicateurs actualisés instantanément à chaque encaissement',
      'Vue synthétique des marges, encaissements et dettes clients',
      'Exportation rapide des bilans périodiques en PDF et Excel',
    ],
  ),
  OnboardingSlideData(
    icon: Icons.point_of_sale_rounded,
    accentColor: Colors.white,
    title: 'Ventes & Caisse',
    headline: 'Encaissez à la vitesse de l\'éclair',
    description:
        'Catalogue tactile, panier 2 colonnes, reçus thermiques, crédit client et historique complet.',
    highlights: ['Caisse rapide', 'Reçus thermiques', 'Plein écran POS'],
    gradientColors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    desktopBadge: 'TERMINAL POINT DE VENTE',
    desktopBenefits: [
      'Vue POS 2 colonnes : Catalogue à gauche, panier et règlement direct à droite',
      'Support natif des douchettes et lecteurs codes-barres USB',
      'Impression automatique sur imprimantes thermiques 58mm / 80mm ESC/POS',
    ],
  ),
  OnboardingSlideData(
    icon: Icons.inventory_2_outlined,
    accentColor: Colors.white,
    title: 'Stock & Articles',
    headline: 'Votre stock sous contrôle absolu',
    description:
        'Catalogue articles, catégories, seuils d\'alerte rupture, lots et valorisation en temps réel.',
    highlights: ['Articles & Prix', 'Catégories', 'Alertes rupture'],
    gradientColors: [Color(0xFF00695C), Color(0xFF004D40)],
    desktopBadge: 'GESTION DES STOCKS',
    desktopBenefits: [
      'Recherche et filtrage instantanés par référence, code-barres et nom',
      'Alertes visuelles en cas d\'atteinte du seuil de réapprovisionnement',
      'Historique inaltérable de tous les mouvements et ajustements d\'inventaire',
    ],
  ),
  OnboardingSlideData(
    icon: Icons.people_alt_outlined,
    accentColor: Colors.white,
    title: 'Clients & Crédit',
    headline: 'Fidélisez et recouvrez efficacement',
    description:
        'Répertoire clients, historique d\'achats, encours de dettes, acomptes et relances WhatsApp.',
    highlights: ['Fiches clients', 'Gestion dettes', 'Relances WhatsApp'],
    gradientColors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    desktopBadge: 'RECOUVREMENT & FIDÉLISATION',
    desktopBenefits: [
      'Suivi rigoureux du solde restant dû et dates d\'échéance',
      'Reçus d\'acompte immédiats avec mise à jour automatique du solde',
      'Envoi de relances personnalisées avec récapitulatif par WhatsApp',
    ],
  ),
  OnboardingSlideData(
    icon: Icons.account_balance_wallet_outlined,
    accentColor: Colors.white,
    title: 'Finances & Caisse',
    headline: 'Maîtrisez votre rentabilité nette',
    description:
        'Dépenses de boutique, sessions de caisse avec contrôle d\'écart et analyse des bénéfices.',
    highlights: ['Dépenses', 'Sessions de caisse', 'Contrôle d\'écart'],
    gradientColors: [Color(0xFFBF360C), Color(0xFF8D2A0A)],
    desktopBadge: 'TRÉSORERIE & RENTABILITÉ',
    desktopBenefits: [
      'Ouverture et clôture sécurisées de session avec calcul d\'écart théorique',
      'Catégorisation des charges courantes (loyer, électricité, transport)',
      'Traçabilité complète des entrées et sorties d\'argent du tiroir-caisse',
    ],
  ),
  OnboardingSlideData(
    icon: Icons.groups_outlined,
    accentColor: Colors.white,
    title: 'Équipe & Boutiques',
    headline: 'Développez votre réseau commercial',
    description:
        'Gestion multi-boutiques, comptes vendeurs, permissions granulaires et journal d\'audit.',
    highlights: ['Multi-boutiques', 'Rôles & Vendeurs', 'Journal d\'audit'],
    gradientColors: [Color(0xFF37474F), Color(0xFF263238)],
    desktopBadge: 'MULTI-POSTES & MULTI-SITES',
    desktopBenefits: [
      'Bascule instantanée entre vos différentes boutiques depuis le menu latéral',
      'Contrôle d\'accès par code PIN pour restreindre les actions sensibles',
      'Journal d\'audit certifié traçant chaque annulation, remise ou modification',
    ],
  ),
  OnboardingSlideData(
    icon: Icons.cloud_sync_outlined,
    accentColor: AppColors.secondary,
    title: 'Fiabilité & Cloud',
    headline: '100% Hors-ligne, synchronisé, protégé',
    description:
        'Continuez à vendre même en coupure internet complète. Synchronisation cloud dès retour du réseau.',
    highlights: ['Hors ligne 24/7', 'Base SQLite locale', 'Sauvegarde cloud'],
    gradientColors: [Color(0xFF0B6E4F), Color(0xFF1565C0)],
    desktopBadge: 'RÉSILIENCE TOTALE',
    desktopBenefits: [
      'Zéro interruption : chaque vente est gravée immédiatement sur votre disque',
      'Chiffrement robuste de votre base de données locale SQLite',
      'Sauvegarde cloud automatique en tâche de fond dès qu\'Internet est disponible',
    ],
  ),
];
