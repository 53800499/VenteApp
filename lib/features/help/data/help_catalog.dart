import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/entities/help_entities.dart';

/// Catalogue complet du centre d'aide VenteApp.
abstract final class HelpCatalog {
  static const categories = <HelpCategory>[
    HelpCategory(
      id: 'start',
      title: 'Démarrage',
      subtitle: 'Navigation, accueil et premiers pas',
      icon: Icons.rocket_launch_outlined,
      color: AppColors.seed,
    ),
    HelpCategory(
      id: 'commerce',
      title: 'Commerce',
      subtitle: 'Ventes, stock, clients et crédit',
      icon: Icons.storefront_outlined,
      color: Color(0xFF1565C0),
    ),
    HelpCategory(
      id: 'finance',
      title: 'Finances',
      subtitle: 'Caisse, dépenses, rapports et marges',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF6A1B9A),
    ),
    HelpCategory(
      id: 'admin',
      title: 'Administration',
      subtitle: 'Boutiques, équipe, sécurité et sync',
      icon: Icons.admin_panel_settings_outlined,
      color: Color(0xFFBF360C),
    ),
  ];

  static const articles = <HelpArticle>[
    // ── Démarrage ──────────────────────────────────────────────
    HelpArticle(
      id: 'getting_started',
      categoryId: 'start',
      title: 'Premiers pas dans VenteApp',
      summary:
          'Comprendre l\'interface, les 5 onglets principaux et le menu Plus.',
      icon: Icons.explore_outlined,
      color: AppColors.seed,
      keywords: ['démarrage', 'navigation', 'onglets', 'interface'],
      sections: [
        HelpSection(
          title: 'Vue d\'ensemble',
          body:
              'VenteApp est organisé autour de cinq onglets en bas de l\'écran '
              '(ou d\'une barre latérale sur tablette) : Accueil, Ventes, Stock, '
              'Clients et Plus. Chaque onglet regroupe les actions les plus '
              'fréquentes de votre journée commerciale.',
          bullets: [
            'Accueil : tableau de bord avec indicateurs clés du jour.',
            'Ventes : historique et création de nouvelles ventes.',
            'Stock : catalogue produits, catégories et alertes.',
            'Clients : fichier client et suivi des achats.',
            'Plus : modules avancés (rapports, équipe, paramètres, aide…).',
          ],
        ),
        HelpSection(
          title: 'Comment naviguer',
          body:
              'Sur téléphone, utilisez la barre de navigation inférieure. '
              'Sur tablette, un rail latéral affiche les mêmes destinations '
              'avec plus d\'espace pour le contenu. Le bouton flottant « Nouvelle vente » '
              'apparaît sur l\'accueil pour accéder rapidement à la caisse.',
          tip:
              'Touchez le nom de la boutique en haut pour changer de boutique '
              'si vous en gérez plusieurs.',
        ),
        HelpSection(
          title: 'Travail hors ligne',
          body:
              'VenteApp fonctionne sans internet. Une bannière discrète indique '
              'quand vous êtes hors ligne ou quand la session cloud est en pause. '
              'Vos ventes et mouvements de stock sont enregistrés localement puis '
              'synchronisés dès que la connexion revient.',
        ),
      ],
    ),
    HelpArticle(
      id: 'dashboard',
      categoryId: 'start',
      title: 'Tableau de bord',
      summary:
          'KPI du jour, ventes récentes, alertes stock et accès rapide à la caisse.',
      icon: Icons.dashboard_outlined,
      color: AppColors.secondary,
      keywords: ['accueil', 'kpi', 'indicateurs', 'tableau de bord'],
      sections: [
        HelpSection(
          title: 'Ce que vous voyez',
          body:
              'L\'écran d\'accueil résume l\'activité de la boutique active : '
              'chiffre d\'affaires du jour, nombre de ventes, panier moyen, '
              'alertes stock et rappels importants.',
          bullets: [
            'Cartes KPI avec icônes colorées pour une lecture rapide.',
            'Liste des ventes récentes avec accès au détail en un toucher.',
            'Indicateurs financiers réservés aux profils autorisés.',
          ],
        ),
        HelpSection(
          title: 'Actions rapides',
          body:
              'Depuis l\'accueil, lancez une nouvelle vente via le bouton flottant '
              'ou consultez une vente récente. Les données se mettent à jour '
              'automatiquement à chaque retour sur cet écran.',
          tip:
              'Consultez l\'accueil en début et fin de journée pour suivre '
              'votre performance en temps réel.',
        ),
      ],
    ),

    // ── Commerce ─────────────────────────────────────────────────
    HelpArticle(
      id: 'sales',
      categoryId: 'commerce',
      title: 'Ventes & caisse',
      summary:
          'Créer une vente, choisir les produits, encaisser, crédit client et reçus.',
      icon: Icons.point_of_sale_outlined,
      color: Color(0xFF1565C0),
      keywords: ['vente', 'caisse', 'encaissement', 'reçu', 'panier'],
      sections: [
        HelpSection(
          title: 'Créer une vente',
          body:
              'Depuis l\'onglet Ventes ou le bouton « Nouvelle vente », vous accédez '
              'à l\'écran de caisse. Recherchez un produit par nom, touchez pour '
              'l\'ajouter au panier, ajustez les quantités puis validez.',
          bullets: [
            'Recherche instantanée dans le catalogue.',
            'Modification des quantités et suppression de lignes.',
            'Application d\'une remise si votre rôle le permet.',
            'Choix du mode de paiement : espèces, mobile money, crédit…',
          ],
        ),
        HelpSection(
          title: 'Vente à crédit',
          body:
              'Pour vendre à crédit, sélectionnez un client existant ou créez-en un '
              'à la volée. Le montant impayé est enregistré comme dette et visible '
              'dans la fiche client.',
          tip:
              'Vérifiez toujours l\'identité du client avant d\'accorder du crédit.',
        ),
        HelpSection(
          title: 'Historique & annulation',
          body:
              'La liste des ventes permet de filtrer, rechercher et ouvrir le détail '
              'd\'une transaction. Selon vos droits, vous pouvez annuler une vente '
              'ou consulter le reçu PDF pour l\'imprimer ou le partager.',
        ),
      ],
    ),
    HelpArticle(
      id: 'quick_sale',
      categoryId: 'commerce',
      title: 'Vente rapide',
      summary:
          'Encaissement express sans détail produit ni impact sur le stock.',
      icon: Icons.flash_on_outlined,
      color: Color(0xFF0277BD),
      keywords: ['vente rapide', 'express', 'encaissement'],
      sections: [
        HelpSection(
          title: 'Quand l\'utiliser',
          body:
              'La vente rapide sert à enregistrer un montant encaissé sans passer '
              'par le catalogue : idéal pour un service, un forfait ou une vente '
              'occasionnelle non référencée en stock.',
        ),
        HelpSection(
          title: 'Limites importantes',
          body:
              'Cette opération n\'impacte pas les quantités en stock et ne génère '
              'pas de détail produit dans les rapports par article. Utilisez-la '
              'avec parcimonie pour ne pas fausser vos statistiques.',
          tip:
              'Préférez une vente classique dès qu\'un produit existe dans votre catalogue.',
        ),
      ],
    ),
    HelpArticle(
      id: 'inventory',
      categoryId: 'commerce',
      title: 'Inventaire & stock',
      summary:
          'Produits, catégories, prix, alertes stock et ajustements.',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF2E7D32),
      keywords: ['produit', 'stock', 'inventaire', 'catégorie', 'alerte'],
      sections: [
        HelpSection(
          title: 'Gérer le catalogue',
          body:
              'L\'onglet Stock liste tous vos produits avec photo, prix, quantité '
              'et catégorie. Créez un produit via le bouton +, renseignez le nom, '
              'le prix de vente, le coût d\'achat (pour les marges) et le seuil d\'alerte.',
          bullets: [
            'Catégories : organisez votre rayon (boissons, épicerie…).',
            'Filtre « stock bas » : produits sous le seuil d\'alerte.',
            'Archivage : masquez un produit sans supprimer l\'historique.',
          ],
        ),
        HelpSection(
          title: 'Mouvements de stock',
          body:
              'Chaque vente décrémente automatiquement le stock. Pour un inventaire '
              'physique, un casse ou un réapprovisionnement, utilisez l\'ajustement '
              'manuel depuis la fiche produit.',
          tip:
              'Définissez un seuil d\'alerte réaliste pour être prévenu avant la rupture.',
        ),
        HelpSection(
          title: 'Permissions',
          body:
              'La lecture du stock est ouverte aux vendeurs. La création, modification '
              'et ajustement nécessitent le droit « inventaire : écriture » ou '
              '« inventaire : ajustement ».',
        ),
      ],
    ),
    HelpArticle(
      id: 'customers',
      categoryId: 'commerce',
      title: 'Clients',
      summary:
          'Fichier client, coordonnées, historique d\'achats et suivi.',
      icon: Icons.people_outline,
      color: Color(0xFF00838F),
      keywords: ['client', 'fichier', 'contact', 'whatsapp'],
      sections: [
        HelpSection(
          title: 'Créer et retrouver un client',
          body:
              'L\'onglet Clients affiche votre fichier trié par nom. Créez un client '
              'avec nom, téléphone (WhatsApp), adresse et notes. La recherche filtre '
              'en temps réel.',
        ),
        HelpSection(
          title: 'Fiche client détaillée',
          body:
              'Ouvrez une fiche pour voir l\'historique des ventes, les dettes ouvertes, '
              'les dettes pardonnées et les actions rapides (appel, WhatsApp, paiement).',
          bullets: [
            'Onglet Achats : toutes les ventes liées au client.',
            'Onglet Dettes : crédit en cours et remboursements.',
            'Enregistrer un paiement partiel ou total sur une dette.',
          ],
          tip:
              'Un numéro WhatsApp correct facilite les relances de crédit.',
        ),
      ],
    ),
    HelpArticle(
      id: 'debts',
      categoryId: 'commerce',
      title: 'Dettes & crédit client',
      summary:
          'Suivi des impayés, remboursements, pardon de dette et recouvrement.',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFFAD1457),
      keywords: ['dette', 'crédit', 'impayé', 'remboursement', 'pardon'],
      sections: [
        HelpSection(
          title: 'Comprendre le cycle',
          body:
              'Une vente à crédit crée automatiquement une dette. Le client peut '
              'rembourser en plusieurs fois. Chaque paiement est tracé avec la date, '
              'le montant et le mode de règlement.',
        ),
        HelpSection(
          title: 'Pardonner une dette',
          body:
              'Le patron peut annuler définitivement une dette (cadeau, perte, geste '
              'commercial). Le motif est obligatoire et visible dans l\'historique '
              'des dettes pardonnées.',
          tip:
              'Consultez régulièrement le rapport de recouvrement dans Statistiques.',
        ),
      ],
    ),

    // ── Finances ─────────────────────────────────────────────────
    HelpArticle(
      id: 'expenses',
      categoryId: 'finance',
      title: 'Dépenses',
      summary:
          'Enregistrer les charges, catégories de dépenses et impact sur le bénéfice.',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF6A1B9A),
      keywords: ['dépense', 'charge', 'coût', 'loyer', 'électricité'],
      sections: [
        HelpSection(
          title: 'Pourquoi saisir les dépenses',
          body:
              'Les dépenses complètent le tableau financier : en les enregistrant, '
              'vous obtenez un bénéfice réel (CA − charges) et non seulement le '
              'chiffre d\'affaires brut.',
        ),
        HelpSection(
          title: 'Saisie et catégories',
          body:
              'Depuis Plus → Dépenses, ajoutez une charge avec montant, date, '
              'catégorie et note. Personnalisez les catégories (loyer, transport, '
              'salaires…) pour des rapports plus lisibles.',
          tip:
              'Saisissez les dépenses le jour même pour ne rien oublier.',
        ),
      ],
    ),
    HelpArticle(
      id: 'cash_sessions',
      categoryId: 'finance',
      title: 'Gestion de caisse',
      summary:
          'Ouverture, suivi des mouvements, écarts et clôture de caisse.',
      icon: Icons.point_of_sale_outlined,
      color: Color(0xFF4527A0),
      keywords: ['caisse', 'ouverture', 'clôture', 'fond de caisse'],
      sections: [
        HelpSection(
          title: 'Session de caisse',
          body:
              'Une session de caisse encadre une journée (ou un créneau) de travail. '
              'À l\'ouverture, saisissez le fond de caisse initial. Pendant la session, '
              'toutes les ventes et mouvements sont rattachés.',
          bullets: [
            'Ouverture : fond initial + responsable.',
            'Mouvements : entrées/sorties exceptionnelles.',
            'Clôture : comptage réel vs théorique, écart expliqué.',
          ],
        ),
        HelpSection(
          title: 'Bonnes pratiques',
          body:
              'Une seule session ouverte à la fois par boutique. Clôturez en fin de '
              'journée pour détecter les écarts et sécuriser vos encaissements.',
          tip:
              'Notez chaque sortie de caisse (achat urgent, monnaie…) dans les mouvements.',
        ),
      ],
    ),
    HelpArticle(
      id: 'reports',
      categoryId: 'finance',
      title: 'Statistiques & rapports',
      summary:
          'CA, bénéfice, top produits, périodes personnalisées et export PDF.',
      icon: Icons.insights_outlined,
      color: Color(0xFF283593),
      keywords: ['rapport', 'statistique', 'ca', 'bénéfice', 'pdf'],
      sections: [
        HelpSection(
          title: 'Périodes et filtres',
          body:
              'Choisissez une période prédéfinie (aujourd\'hui, semaine, mois) ou '
              'une plage personnalisée. Les KPI s\'adaptent : CA brut, encaissé, '
              'crédit accordé, panier moyen, nombre de ventes.',
        ),
        HelpSection(
          title: 'Top produits & recouvrement',
          body:
              'Classez les produits par quantité vendue ou par chiffre d\'affaires. '
              'La section recouvrement résume les dettes ouvertes et les paiements reçus.',
          tip:
              'Exportez en PDF pour partager avec votre comptable ou associé.',
        ),
        HelpSection(
          title: 'Vue consolidée',
          body:
              'Le propriétaire multi-boutiques peut activer la vue consolidée pour '
              'agréger les chiffres de la boutique racine et de ses sous-boutiques.',
        ),
      ],
    ),
    HelpArticle(
      id: 'sales_analysis',
      categoryId: 'finance',
      title: 'Analyse des ventes',
      summary:
          'Produits, employés, clients, marges, écarts de prix et tendances.',
      icon: Icons.analytics_outlined,
      color: Color(0xFF4A148C),
      keywords: ['analyse', 'marge', 'prix', 'tendance', 'employé'],
      sections: [
        HelpSection(
          title: 'Les 7 onglets d\'analyse',
          body:
              'L\'analyse des ventes propose une exploration approfondie par période :',
          bullets: [
            'Produits : quantités et CA par article.',
            'Employés : ventes et écarts de prix par vendeur.',
            'Clients : meilleurs acheteurs de la période.',
            'Catégories : performance par rayon.',
            'Marges : CA vs coût d\'achat.',
            'Prix : écarts par rapport au catalogue.',
            'Tendances : évolution jour par jour.',
          ],
        ),
        HelpSection(
          title: 'Exploiter les données',
          body:
              'Identifiez les produits stars, détectez les remises abusives et '
              'comparez les performances entre périodes. Touchez un produit pour '
              'voir le détail ligne par ligne.',
          tip:
              'Croisez l\'analyse des marges avec les alertes stock pour optimiser vos achats.',
        ),
      ],
    ),

    // ── Administration ───────────────────────────────────────────
    HelpArticle(
      id: 'shops',
      categoryId: 'admin',
      title: 'Multi-boutiques',
      summary:
          'Créer des boutiques, sous-boutiques, bascule et vue consolidée.',
      icon: Icons.store_mall_directory_outlined,
      color: Color(0xFFBF360C),
      keywords: ['boutique', 'multi', 'sous-boutique', 'changer'],
      sections: [
        HelpSection(
          title: 'Hiérarchie des boutiques',
          body:
              'Un compte propriétaire peut gérer une boutique racine et des '
              'sous-boutiques (succursales, dépôts). Seules la racine et ses '
              'enfants directs apparaissent dans vos listes — pas les boutiques '
              'd\'un autre propriétaire partageant le même numéro.',
        ),
        HelpSection(
          title: 'Changer de boutique active',
          body:
              'Touchez le nom en haut de l\'écran ou allez dans Plus → Mes boutiques. '
              'La bascule recharge les données locales de la boutique sélectionnée.',
          tip:
              'Chaque boutique a son propre stock et ses propres ventes.',
        ),
      ],
    ),
    HelpArticle(
      id: 'team_rbac',
      categoryId: 'admin',
      title: 'Équipe, rôles & permissions',
      summary:
          'Vendeurs, lecteurs, droits granulaires et exceptions par utilisateur.',
      icon: Icons.group_outlined,
      color: Color(0xFFE65100),
      keywords: ['équipe', 'rôle', 'permission', 'vendeur', 'patron'],
      sections: [
        HelpSection(
          title: 'Rôles prédéfinis',
          body:
              'Trois profils de base couvrent la majorité des besoins :',
          bullets: [
            'Propriétaire : accès complet, y compris audit et sync.',
            'Vendeur : ventes, clients, lecture stock.',
            'Lecteur : consultation seule, sans modification.',
          ],
        ),
        HelpSection(
          title: 'Permissions fines',
          body:
              'Le catalogue des rôles détaille chaque droit (ventes, inventaire, '
              'rapports financiers…). Vous pouvez créer des rôles personnalisés et '
              'accorder des exceptions à un utilisateur précis.',
          tip:
              'Principe du moindre privilège : donnez uniquement les droits nécessaires.',
        ),
      ],
    ),
    HelpArticle(
      id: 'settings_security',
      categoryId: 'admin',
      title: 'Paramètres & sécurité',
      summary:
          'PIN, biométrie, reçus, sauvegarde, localisation et verrouillage.',
      icon: Icons.shield_outlined,
      color: Color(0xFF33691E),
      keywords: ['pin', 'sécurité', 'sauvegarde', 'biométrie', 'paramètres'],
      sections: [
        HelpSection(
          title: 'Sécurité de l\'appareil',
          body:
              'Le code PIN verrouille l\'application sans détruire la session. '
              'Activez la biométrie pour un déverrouillage rapide. En cas d\'oubli, '
              'le propriétaire peut utiliser un jeton de récupération ou WhatsApp.',
          bullets: [
            'Verrouiller : depuis Plus, session conservée.',
            'Déconnexion : ferme le compte, reconnexion WhatsApp requise.',
            'Politique PIN au démarrage : configurable dans Paramètres.',
          ],
        ),
        HelpSection(
          title: 'Sauvegarde & restauration',
          body:
              'Exportez une sauvegarde chiffrée de votre boutique vers le stockage '
              'local ou Google Drive. Indispensable avant de changer de téléphone.',
          tip:
              'Programmez une sauvegarde hebdomadaire si vous n\'activez pas le cloud.',
        ),
      ],
    ),
    HelpArticle(
      id: 'sync_offline',
      categoryId: 'admin',
      title: 'Synchronisation & hors ligne',
      summary:
          'Mode offline, session cloud, conflits et connexion serveur.',
      icon: Icons.cloud_sync_outlined,
      color: Color(0xFF00695C),
      keywords: ['sync', 'hors ligne', 'cloud', 'conflit', 'serveur'],
      sections: [
        HelpSection(
          title: 'Fonctionnement offline-first',
          body:
              'Toutes les opérations courantes (ventes, stock, clients) fonctionnent '
              'sans réseau. Les données sont stockées sur l\'appareil puis envoyées '
              'au serveur cloud quand la connexion est disponible.',
        ),
        HelpSection(
          title: 'Session cloud & grâce',
          body:
              'Si le jeton cloud expire, l\'application continue en local pendant '
              'environ 25 minutes avant de vous proposer une reconnexion. Vous ne '
              'perdez aucune vente enregistrée pendant cette période.',
        ),
        HelpSection(
          title: 'Résolution des conflits',
          body:
              'En cas de modification simultanée sur deux appareils, le propriétaire '
              'voit les conflits dans Plus → Conflits de synchronisation et choisit '
              'la version à conserver.',
          tip:
              'Configurez l\'URL du serveur dans Plus → Connexion serveur si besoin.',
        ),
      ],
    ),
    HelpArticle(
      id: 'audit',
      categoryId: 'admin',
      title: 'Journal d\'audit',
      summary:
          'Traçabilité des actions sensibles : ventes, stock, dettes, utilisateurs.',
      icon: Icons.fact_check_outlined,
      color: Color(0xFF37474F),
      keywords: ['audit', 'journal', 'traçabilité', 'historique'],
      sections: [
        HelpSection(
          title: 'À quoi ça sert',
          body:
              'Le journal d\'audit enregistre qui a fait quoi et quand : annulation '
              'de vente, ajustement de stock, pardon de dette, changement de rôle… '
              'Réservé au patron pour la transparence et la sécurité.',
        ),
        HelpSection(
          title: 'Filtres et export',
          body:
              'Filtrez par module, action et période. Exportez en PDF pour archivage '
              'ou contrôle interne. Depuis une fiche (dette, produit…), accédez à '
              'l\'historique complet de l\'entité.',
        ),
      ],
    ),
    HelpArticle(
      id: 'notifications',
      categoryId: 'admin',
      title: 'Alertes & notifications',
      summary:
          'Stock bas, dettes, résumé du jour et rappels de sauvegarde.',
      icon: Icons.notifications_outlined,
      color: Color(0xFFF57F17),
      keywords: ['notification', 'alerte', 'stock', 'rappel'],
      sections: [
        HelpSection(
          title: 'Types d\'alertes',
          body:
              'Configurez les notifications push et locales selon vos besoins :',
          bullets: [
            'Stock bas : produit sous le seuil d\'alerte.',
            'Dettes : échéances et relances.',
            'Résumé du jour : CA et ventes en fin de journée.',
            'Sauvegarde : rappel si aucune sauvegarde récente.',
          ],
        ),
        HelpSection(
          title: 'Configuration',
          body:
              'Depuis Plus → Alertes ou Paramètres → Notifications, activez '
              'chaque type et accordez la permission système si demandée.',
          tip:
              'Les alertes stock évitent les ruptures sur vos produits les plus vendus.',
        ),
      ],
    ),
  ];

  static HelpCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static HelpArticle? articleById(String id) {
    for (final a in articles) {
      if (a.id == id) return a;
    }
    return null;
  }

  static List<HelpArticle> articlesForCategory(String categoryId) =>
      articles.where((a) => a.categoryId == categoryId).toList();

  static List<HelpArticle> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return articles;
    return articles.where((a) {
      if (a.title.toLowerCase().contains(q)) return true;
      if (a.summary.toLowerCase().contains(q)) return true;
      for (final k in a.keywords) {
        if (k.toLowerCase().contains(q)) return true;
      }
      for (final s in a.sections) {
        if (s.title.toLowerCase().contains(q)) return true;
        if (s.body.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }
}
