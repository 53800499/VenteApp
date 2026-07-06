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
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String headline;
  final String description;
  final List<String> highlights;
  final List<Color>? gradientColors;
}

const onboardingSlides = <OnboardingSlideData>[
  OnboardingSlideData(
    icon: Icons.storefront_rounded,
    accentColor: AppColors.secondary,
    title: 'VenteApp',
    headline: 'Votre cockpit commercial',
    description:
        'Conçu pour les boutiques au Bénin : simple, rapide et prêt pour le terrain.',
    highlights: ['Offline-first', 'Multi-boutiques', 'Sécurisé'],
    gradientColors: [Color(0xFF0B6E4F), Color(0xFF084A36)],
  ),
  OnboardingSlideData(
    icon: Icons.dashboard_customize_outlined,
    accentColor: AppColors.secondary,
    title: 'Tableau de bord',
    headline: 'Pilotez votre journée',
    description:
        'CA du jour, ventes récentes, alertes stock et accès direct à la caisse.',
    highlights: ['KPI en direct', 'Ventes récentes', 'Alertes'],
    gradientColors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
  ),
  OnboardingSlideData(
    icon: Icons.point_of_sale_rounded,
    accentColor: Colors.white,
    title: 'Ventes',
    headline: 'Encaissez en quelques secondes',
    description:
        'Panier tactile, reçus PDF, crédit client et historique complet.',
    highlights: ['Caisse rapide', 'Reçus', 'Crédit'],
    gradientColors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
  ),
  OnboardingSlideData(
    icon: Icons.inventory_2_outlined,
    accentColor: Colors.white,
    title: 'Inventaire',
    headline: 'Stock toujours sous contrôle',
    description:
        'Catalogue produits, catégories, seuils d\'alerte et ajustements manuels.',
    highlights: ['Produits', 'Catégories', 'Alertes stock'],
    gradientColors: [Color(0xFF00695C), Color(0xFF004D40)],
  ),
  OnboardingSlideData(
    icon: Icons.people_alt_outlined,
    accentColor: Colors.white,
    title: 'Clients & crédit',
    headline: 'Fidélisez et recouvrez',
    description:
        'Fichier client, historique d\'achats, dettes, remboursements et relances.',
    highlights: ['Fiche client', 'Dettes', 'WhatsApp'],
    gradientColors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
  ),
  OnboardingSlideData(
    icon: Icons.account_balance_wallet_outlined,
    accentColor: Colors.white,
    title: 'Finances',
    headline: 'Maîtrisez votre rentabilité',
    description:
        'Dépenses, gestion de caisse, statistiques et analyse des marges.',
    highlights: ['Dépenses', 'Caisse', 'Rapports'],
    gradientColors: [Color(0xFFBF360C), Color(0xFF8D2A0A)],
  ),
  OnboardingSlideData(
    icon: Icons.groups_outlined,
    accentColor: Colors.white,
    title: 'Équipe & boutiques',
    headline: 'Grandissez sereinement',
    description:
        'Multi-boutiques, vendeurs, rôles personnalisés et journal d\'audit.',
    highlights: ['Sous-boutiques', 'Rôles', 'Audit'],
    gradientColors: [Color(0xFF37474F), Color(0xFF263238)],
  ),
  OnboardingSlideData(
    icon: Icons.cloud_sync_outlined,
    accentColor: AppColors.secondary,
    title: 'Toujours avec vous',
    headline: 'Hors ligne, synchronisé, protégé',
    description:
        'Vendez sans internet. PIN, biométrie, sauvegarde et sync cloud automatique.',
    highlights: ['Hors ligne', 'PIN', 'Sauvegarde'],
    gradientColors: [Color(0xFF0B6E4F), Color(0xFF1565C0)],
  ),
];
