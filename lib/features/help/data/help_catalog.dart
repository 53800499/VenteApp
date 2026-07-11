import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/entities/help_entities.dart';

/// Catalogue complet du centre d'aide ARIKE.
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
      subtitle: 'Ventes, stock, clients, crédit et calculateurs',
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
      title: 'Premiers pas dans ARIKE',
      summary:
          'Comprendre l\'interface, les 5 onglets principaux et le menu Plus.',
      icon: Icons.explore_outlined,
      color: AppColors.seed,
      keywords: ['démarrage', 'navigation', 'onglets', 'interface'],
      sections: [
        HelpSection(
          title: 'Vue d\'ensemble',
          body:
              'ARIKE est organisé autour de cinq onglets en bas de l\'écran '
              '(ou d\'une barre latérale sur tablette). Chaque onglet regroupe '
              'les actions les plus fréquentes de votre journée commerciale.',
          bullets: [
            'Accueil : tableau de bord avec indicateurs clés du jour.',
            'Ventes : historique et création de nouvelles ventes.',
            'Stock : catalogue produits, catégories et alertes.',
            'Clients : fichier client et suivi des achats.',
            'Plus : modules avancés (rapports, équipe, paramètres, aide…).',
          ],
        ),
        HelpSection(
          title: 'Première connexion — pas à pas',
          body: 'Pour ouvrir l\'application la première fois :',
          steps: [
            'Installez ARIKE et ouvrez-la.',
            'Connectez-vous via WhatsApp (code OTP reçu sur votre numéro).',
            'Créez votre boutique : nom, adresse, devise.',
            'Définissez un code PIN à 4 ou 6 chiffres pour verrouiller l\'app.',
            'Ajoutez vos premiers produits dans l\'onglet Stock.',
            'Lancez votre première vente depuis l\'accueil ou l\'onglet Ventes.',
          ],
        ),
        HelpSection(
          title: 'Naviguer dans l\'app — pas à pas',
          body: 'Pour vous déplacer entre les modules :',
          steps: [
            'Touchez un onglet en bas (Accueil, Ventes, Stock, Clients, Plus).',
            'Sur tablette, utilisez le rail latéral à gauche.',
            'Pour changer de boutique : touchez le nom en haut de l\'écran.',
            'Pour l\'aide détaillée : Plus → Aide & guides.',
            'Pour l\'état cloud : touchez l\'icône nuage en haut à droite.',
          ],
          tip:
              'Le bouton flottant « Nouvelle vente » sur l\'accueil est le raccourci le plus rapide vers la caisse.',
        ),
        HelpSection(
          title: 'Travail hors ligne',
          body:
              'ARIKE fonctionne sans internet. Une bannière indique quand vous '
              'êtes hors ligne ou quand la session cloud est en pause. Vos ventes '
              'et mouvements de stock sont enregistrés localement puis synchronisés '
              'dès que la connexion revient.',
          steps: [
            'Continuez à vendre normalement sans réseau.',
            'Vérifiez l\'icône cloud : orange = en attente, verte = synchronisé.',
            'Au retour du réseau, la sync se lance automatiquement.',
            'Si la sync reste bloquée : touchez l\'icône cloud → Relancer.',
          ],
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
          title: 'Lire le tableau de bord — pas à pas',
          steps: [
            'Ouvrez l\'onglet Accueil (premier onglet).',
            'Consultez les cartes KPI : CA du jour, ventes, panier moyen.',
            'Descendez pour voir les ventes récentes et les alertes stock.',
            'Touchez une vente récente pour ouvrir son détail.',
          ],
        ),
        HelpSection(
          title: 'Lancer une vente depuis l\'accueil — pas à pas',
          steps: [
            'Sur l\'écran Accueil, touchez le bouton flottant « Nouvelle vente ».',
            'Vous arrivez directement à l\'écran de caisse.',
          ],
          tip:
              'Consultez l\'accueil en début et fin de journée pour suivre votre performance.',
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
          title: 'Créer une vente classique — pas à pas',
          body: 'Pour enregistrer une vente avec détail produit et impact stock :',
          steps: [
            'Ouvrez l\'onglet Ventes ou touchez « Nouvelle vente » sur l\'accueil.',
            'Recherchez un produit par nom dans la barre de recherche.',
            'Touchez le produit pour l\'ajouter au panier.',
            'Ajustez la quantité avec + / − ou supprimez une ligne si besoin.',
            'Ajoutez d\'autres produits si nécessaire.',
            'Touchez « Valider » ou l\'équivalent pour passer au paiement.',
            'Choisissez le mode de paiement (espèces, mobile money, crédit…).',
            'Confirmez : la vente est enregistrée et le stock est mis à jour.',
          ],
        ),
        HelpSection(
          title: 'Vendre à crédit — pas à pas',
          body: 'Pour accorder du crédit à un client :',
          steps: [
            'Créez la vente comme d\'habitude (produits + quantités).',
            'À l\'étape paiement, sélectionnez le mode « Crédit » ou « À crédit ».',
            'Choisissez un client existant ou créez-en un nouveau (nom + téléphone).',
            'Validez la vente : une dette est créée automatiquement.',
            'Consultez la dette dans Clients → fiche client → onglet Dettes.',
          ],
          tip:
              'Vérifiez toujours l\'identité du client avant d\'accorder du crédit.',
        ),
        HelpSection(
          title: 'Consulter ou annuler une vente — pas à pas',
          body: 'Pour retrouver une vente passée :',
          steps: [
            'Ouvrez l\'onglet Ventes.',
            'Utilisez la recherche ou les filtres (date, vendeur…).',
            'Touchez une vente pour voir le détail (produits, montants, paiement).',
            'Pour le reçu : touchez « Reçu » ou l\'icône partage / PDF.',
            'Pour annuler (si autorisé) : touchez « Annuler » et confirmez.',
          ],
        ),
        HelpSection(
          title: 'Appliquer une remise',
          body:
              'Si votre rôle le permet, vous pouvez réduire le total avant validation. '
              'La remise est tracée dans le détail de la vente et visible dans les rapports.',
          steps: [
            'Dans l\'écran de caisse, touchez « Remise » ou le champ dédié.',
            'Saisissez le montant ou le pourcentage.',
            'Vérifiez le nouveau total avant de valider le paiement.',
          ],
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
          title: 'Quand utiliser la vente rapide',
          body:
              'La vente rapide enregistre un montant encaissé sans passer par le '
              'catalogue : idéal pour un service, un forfait ou une vente occasionnelle '
              'non référencée en stock.',
        ),
        HelpSection(
          title: 'Faire une vente rapide — pas à pas',
          body: 'Procédure complète :',
          steps: [
            'Ouvrez l\'onglet Ventes.',
            'Touchez « Vente rapide » (ou l\'icône éclair).',
            'Saisissez le montant encaissé.',
            'Ajoutez une note optionnelle (ex. « Réparation téléphone »).',
            'Choisissez le mode de paiement.',
            'Validez : le montant est comptabilisé au CA sans détail produit.',
          ],
        ),
        HelpSection(
          title: 'Limites importantes',
          body:
              'Cette opération n\'impacte pas les quantités en stock et ne génère '
              'pas de détail produit dans les rapports par article.',
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
          title: 'Ajouter un produit — pas à pas',
          body: 'Pour créer un article dans votre catalogue :',
          steps: [
            'Ouvrez l\'onglet Stock.',
            'Touchez le bouton + (Nouveau produit).',
            'Saisissez le nom, le prix de vente et le coût d\'achat (pour les marges).',
            'Choisissez ou créez une catégorie (ex. Boissons, Épicerie).',
            'Indiquez la quantité en stock et le seuil d\'alerte.',
            'Ajoutez une photo optionnelle.',
            'Enregistrez : le produit apparaît dans la liste et la caisse.',
          ],
        ),
        HelpSection(
          title: 'Créer une catégorie — pas à pas',
          steps: [
            'Stock → touchez « Catégories » ou le filtre catégorie.',
            'Touchez + pour ajouter une catégorie.',
            'Saisissez le nom et validez.',
            'Réassignez vos produits à cette catégorie depuis leur fiche.',
          ],
        ),
        HelpSection(
          title: 'Ajuster le stock manuellement — pas à pas',
          body: 'Pour un inventaire physique, casse ou réapprovisionnement :',
          steps: [
            'Stock → touchez le produit concerné.',
            'Ouvrez « Ajuster le stock » ou « Mouvement ».',
            'Choisissez le type : entrée (+) ou sortie (−).',
            'Saisissez la quantité et un motif (inventaire, casse, livraison…).',
            'Validez : le stock et l\'historique sont mis à jour.',
          ],
          tip:
              'Chaque vente décrémente automatiquement le stock — l\'ajustement manuel sert aux cas exceptionnels.',
        ),
        HelpSection(
          title: 'Voir les produits en rupture — pas à pas',
          steps: [
            'Ouvrez l\'onglet Stock.',
            'Activez le filtre « Stock bas » ou l\'icône alerte.',
            'Les produits sous leur seuil d\'alerte s\'affichent en premier.',
            'Touchez un produit pour le réapprovisionner via un ajustement.',
          ],
        ),
        HelpSection(
          title: 'Archiver un produit — pas à pas',
          steps: [
            'Ouvrez la fiche du produit dans Stock.',
            'Touchez « Archiver » (ou désactiver).',
            'Le produit disparaît de la caisse mais l\'historique des ventes est conservé.',
          ],
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
          title: 'Ajouter un client — pas à pas',
          body: 'Pour créer une fiche client :',
          steps: [
            'Ouvrez l\'onglet Clients.',
            'Touchez le bouton + (Nouveau client).',
            'Renseignez le nom (obligatoire) et le téléphone WhatsApp.',
            'Ajoutez l\'adresse et des notes si besoin.',
            'Enregistrez : le client est disponible à la caisse et au crédit.',
          ],
        ),
        HelpSection(
          title: 'Retrouver un client — pas à pas',
          steps: [
            'Onglet Clients → tapez le nom ou le numéro dans la recherche.',
            'La liste se filtre en temps réel.',
            'Touchez le client pour ouvrir sa fiche détaillée.',
          ],
        ),
        HelpSection(
          title: 'Consulter la fiche client — pas à pas',
          body: 'La fiche regroupe tout l\'historique du client :',
          steps: [
            'Ouvrez la fiche depuis l\'onglet Clients.',
            'Onglet Achats : toutes les ventes liées au client.',
            'Onglet Dettes : crédit en cours, partiellement payé ou soldé.',
            'Onglet Remboursées : dettes entièrement payées.',
            'Onglet Pardonnées : dettes annulées par le patron.',
            'Tirez vers le bas pour actualiser les données depuis le serveur.',
          ],
        ),
        HelpSection(
          title: 'Contacter un client — pas à pas',
          steps: [
            'Ouvrez la fiche client.',
            'Touchez l\'icône appel pour composer le numéro.',
            'Touchez l\'icône WhatsApp pour ouvrir une conversation.',
          ],
          tip:
              'Un numéro WhatsApp correct facilite les relances de crédit.',
        ),
        HelpSection(
          title: 'Modifier un client — pas à pas',
          steps: [
            'Ouvrez la fiche client.',
            'Touchez « Modifier » ou l\'icône crayon.',
            'Mettez à jour les informations et enregistrez.',
          ],
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
          title: 'Comprendre le cycle de crédit',
          body:
              'Une vente à crédit crée automatiquement une dette. Le client peut '
              'rembourser en plusieurs fois. Chaque paiement est tracé avec la date, '
              'le montant et le mode de règlement.',
        ),
        HelpSection(
          title: 'Enregistrer un remboursement — pas à pas',
          body: 'Pour encaisser tout ou partie d\'une dette :',
          steps: [
            'Clients → ouvrez la fiche du client.',
            'Onglet Dettes → touchez la dette concernée.',
            'Touchez « Enregistrer un paiement ».',
            'Saisissez le montant (partiel ou total).',
            'Choisissez le mode de règlement (espèces, mobile money…).',
            'Validez : le solde de la dette est mis à jour.',
          ],
        ),
        HelpSection(
          title: 'Pardonner une dette — pas à pas',
          body: 'Réservé au patron — pour annuler définitivement une dette :',
          steps: [
            'Ouvrez la fiche client → onglet Dettes.',
            'Touchez les trois points (…) en haut de la liste de dettes et sélectionnez "Pardonner la dette".',
            'Saisissez le motif obligatoire (cadeau, perte, geste commercial…).',
            'Confirmez : la dette passe dans l\'onglet Pardonnées.',
          ],
          tip:
              'Consultez Plus → Dettes pardonnées pour l\'historique global.',
        ),
        HelpSection(
          title: 'Consulter toutes les dettes pardonnées — pas à pas',
          steps: [
            'Ouvrez Plus → Dettes pardonnées.',
            'Consultez la liste : client, montant, motif, date, auteur.',
            'Touchez une ligne pour le détail complet.',
          ],
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
          title: 'Enregistrer une dépense — pas à pas',
          steps: [
            'Ouvrez Plus → Dépenses.',
            'Touchez + (Nouvelle dépense).',
            'Saisissez le montant et la date.',
            'Choisissez une catégorie (loyer, transport, salaires…).',
            'Ajoutez une note descriptive si besoin.',
            'Validez : la charge est comptabilisée dans vos rapports.',
          ],
          tip:
              'Saisissez les dépenses le jour même pour ne rien oublier.',
        ),
        HelpSection(
          title: 'Gérer les catégories de dépenses — pas à pas',
          steps: [
            'Plus → Dépenses → Catégories.',
            'Touchez + pour créer une catégorie.',
            'Nommez-la clairement (ex. « Électricité », « Transport »).',
            'Utilisez-la lors de chaque nouvelle saisie.',
          ],
        ),
        HelpSection(
          title: 'Modifier ou supprimer une dépense — pas à pas',
          steps: [
            'Plus → Dépenses → touchez la dépense dans la liste.',
            'Touchez « Modifier » pour corriger le montant ou la catégorie.',
            'Ou touchez « Supprimer » si la saisie est erronée.',
          ],
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
          title: 'Ouvrir une session de caisse — pas à pas',
          steps: [
            'Ouvrez Plus → Gestion de caisse.',
            'Touchez « Ouvrir la caisse ».',
            'Saisissez le fond de caisse initial (monnaie en caisse au démarrage).',
            'Confirmez : la session est active pour la journée.',
          ],
        ),
        HelpSection(
          title: 'Enregistrer un mouvement de caisse — pas à pas',
          body: 'Pour une entrée ou sortie exceptionnelle (hors vente) :',
          steps: [
            'Plus → Gestion de caisse → session ouverte.',
            'Touchez « Nouveau mouvement ».',
            'Choisissez Entrée (+) ou Sortie (−).',
            'Saisissez le montant et le motif.',
            'Validez : le solde théorique est recalculé.',
          ],
        ),
        HelpSection(
          title: 'Clôturer la caisse — pas à pas',
          steps: [
            'En fin de journée, ouvrez Plus → Gestion de caisse.',
            'Touchez « Clôturer la caisse ».',
            'Comptez l\'argent réellement présent en caisse.',
            'Saisissez le montant compté.',
            'L\'application affiche l\'écart (théorique vs réel).',
            'Ajoutez un commentaire si l\'écart est significatif.',
            'Confirmez la clôture.',
          ],
          tip:
              'Une seule session ouverte à la fois. Notez chaque sortie de caisse dans les mouvements.',
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
          title: 'Consulter les statistiques — pas à pas',
          steps: [
            'Ouvrez Plus → Statistiques.',
            'Choisissez une période : Aujourd\'hui, Semaine, Mois ou Personnalisée.',
            'Pour une plage personnalisée : touchez les dates début et fin.',
            'Consultez les KPI : CA, encaissé, crédit, panier moyen, nombre de ventes.',
          ],
        ),
        HelpSection(
          title: 'Voir le top produits — pas à pas',
          steps: [
            'Dans Statistiques, descendez à la section « Top produits ».',
            'Triez par quantité vendue ou par chiffre d\'affaires.',
            'Touchez un produit pour voir le détail des ventes.',
          ],
        ),
        HelpSection(
          title: 'Exporter en PDF — pas à pas',
          steps: [
            'Ouvrez Plus → Statistiques avec la période souhaitée.',
            'Touchez l\'icône partage ou « Exporter PDF ».',
            'Choisissez l\'application (WhatsApp, Drive, imprimante…).',
          ],
          tip:
              'Idéal pour partager avec votre comptable ou associé.',
        ),
        HelpSection(
          title: 'Vue consolidée multi-boutiques — pas à pas',
          steps: [
            'Connectez-vous en tant que propriétaire.',
            'Plus → Statistiques.',
            'Activez « Vue consolidée » si disponible.',
            'Les chiffres de la boutique racine et des sous-boutiques sont agrégés.',
          ],
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
          title: 'Accéder à l\'analyse — pas à pas',
          steps: [
            'Ouvrez Plus → Analyse des ventes.',
            'Choisissez la période en haut de l\'écran.',
            'Naviguez entre les 7 onglets d\'analyse.',
          ],
        ),
        HelpSection(
          title: 'Les 7 onglets — que regarder',
          body: 'Chaque onglet répond à une question précise :',
          bullets: [
            'Produits : quels articles se vendent le plus ?',
            'Employés : quel vendeur réalise le plus de CA ?',
            'Clients : qui sont vos meilleurs acheteurs ?',
            'Catégories : quel rayon performe le mieux ?',
            'Marges : quel est votre bénéfice par produit ?',
            'Prix : y a-t-il des écarts par rapport au catalogue ?',
            'Tendances : comment évolue le CA jour par jour ?',
          ],
        ),
        HelpSection(
          title: 'Analyser un produit en détail — pas à pas',
          steps: [
            'Onglet Produits → touchez un article.',
            'Consultez quantités, CA, marge et ventes ligne par ligne.',
            'Comparez avec une autre période en changeant les dates.',
          ],
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
          title: 'Créer une boutique — pas à pas',
          steps: [
            'Ouvrez Plus → Mes boutiques.',
            'Touchez + (Nouvelle boutique).',
            'Saisissez le nom, l\'adresse et les informations de base.',
            'Validez : la boutique est créée et disponible au changement.',
          ],
        ),
        HelpSection(
          title: 'Changer de boutique active — pas à pas',
          steps: [
            'Touchez le nom de la boutique en haut de l\'écran,',
            'Ou ouvrez Plus → Mes boutiques.',
            'Sélectionnez la boutique souhaitée dans la liste.',
            'L\'application recharge les données locales de cette boutique.',
          ],
          tip:
              'Chaque boutique a son propre stock, ses ventes et ses clients.',
        ),
        HelpSection(
          title: 'Comprendre la hiérarchie',
          body:
              'Un compte propriétaire peut gérer une boutique racine et des '
              'sous-boutiques (succursales). Seules la racine et ses enfants '
              'directs apparaissent dans vos listes.',
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
          title: 'Ajouter un membre à l\'équipe — pas à pas',
          steps: [
            'Ouvrez Plus → Équipe.',
            'Touchez + (Nouvel utilisateur).',
            'Saisissez le nom et le numéro WhatsApp.',
            'Attribuez un rôle (Vendeur, Lecteur ou personnalisé).',
            'Définissez un code PIN pour cet utilisateur.',
            'Validez : l\'utilisateur peut se connecter sur son appareil.',
          ],
        ),
        HelpSection(
          title: 'Modifier les droits d\'un utilisateur — pas à pas',
          steps: [
            'Plus → Équipe → touchez l\'utilisateur.',
            'Changez son rôle ou ajoutez des exceptions de permissions.',
            'Enregistrez les modifications.',
          ],
        ),
        HelpSection(
          title: 'Rôles prédéfinis',
          body: 'Trois profils couvrent la majorité des besoins :',
          bullets: [
            'Propriétaire : accès complet, y compris audit et sync.',
            'Vendeur : ventes, clients, lecture stock.',
            'Lecteur : consultation seule, sans modification.',
          ],
          tip:
              'Principe du moindre privilège : donnez uniquement les droits nécessaires.',
        ),
        HelpSection(
          title: 'Créer un rôle personnalisé — pas à pas',
          steps: [
            'Plus → Rôles & permissions.',
            'Touchez + (Nouveau rôle).',
            'Nommez le rôle et cochez les permissions souhaitées.',
            'Enregistrez puis assignez ce rôle à un utilisateur dans Équipe.',
          ],
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
          title: 'Modifier le code PIN — pas à pas',
          steps: [
            'Plus → Paramètres → Sécurité.',
            'Touchez « Modifier le code PIN ».',
            'Saisissez l\'ancien PIN puis le nouveau (4 à 6 chiffres).',
            'Confirmez le nouveau PIN.',
          ],
        ),
        HelpSection(
          title: 'Activer la biométrie — pas à pas',
          steps: [
            'Plus → Paramètres → Sécurité.',
            'Activez « Déverrouillage biométrique ».',
            'Suivez les instructions de l\'appareil (empreinte ou visage).',
          ],
        ),
        HelpSection(
          title: 'Sauvegarder vos données — pas à pas',
          steps: [
            'Plus → Paramètres → Sauvegarde.',
            'Touchez « Exporter une sauvegarde ».',
            'Choisissez la destination (fichier local ou Google Drive).',
            'Conservez le fichier en lieu sûr avant de changer de téléphone.',
          ],
          tip:
              'Programmez une sauvegarde hebdomadaire si le cloud n\'est pas actif.',
        ),
        HelpSection(
          title: 'Restaurer une sauvegarde — pas à pas',
          steps: [
            'Plus → Paramètres → Sauvegarde.',
            'Touchez « Restaurer ».',
            'Sélectionnez le fichier de sauvegarde.',
            'Confirmez : les données locales sont remplacées.',
          ],
        ),
        HelpSection(
          title: 'Verrouiller vs Déconnexion',
          body: 'Deux actions différentes :',
          bullets: [
            'Verrouiller (Plus) : retour à l\'écran PIN, session conservée.',
            'Déconnexion (Plus) : ferme le compte, reconnexion WhatsApp requise.',
          ],
        ),
      ],
    ),
    HelpArticle(
      id: 'sync_offline',
      categoryId: 'admin',
      title: 'Synchronisation & hors ligne',
      summary:
          'Mode offline, session cloud, conflits et synchronisation.',
      icon: Icons.cloud_sync_outlined,
      color: Color(0xFF00695C),
      keywords: ['sync', 'hors ligne', 'cloud', 'conflit'],
      sections: [
        HelpSection(
          title: 'Comprendre l\'icône cloud',
          body:
              'L\'icône nuage en haut à droite indique l\'état de la synchronisation. '
              'Touchez-la à tout moment pour voir le détail et les actions possibles.',
          bullets: [
            'Verte : données synchronisées avec le cloud.',
            'Orange / flèche : opérations en attente d\'envoi.',
            'Rouge : conflit ou synchronisation cloud bloquée.',
            'Grisée : mode local uniquement (cloud désactivé).',
          ],
        ),
        HelpSection(
          title: 'Travailler hors ligne — pas à pas',
          steps: [
            'Continuez à vendre, gérer le stock et les clients normalement.',
            'Vérifiez la bannière en haut : « Hors ligne » est normal sans réseau.',
            'Au retour du réseau, la sync démarre automatiquement.',
            'Touchez l\'icône cloud pour vérifier que tout est passé au vert.',
          ],
        ),
        HelpSection(
          title: 'Rétablir la synchronisation cloud — pas à pas',
          steps: [
            'Vérifiez internet (Wi‑Fi ou données mobiles).',
            'Si bannière orange : touchez « Réessayer » ou « Code PIN ».',
            'Touchez l\'icône cloud → « Relancer la synchronisation ».',
            'En dernier recours : Plus → Déconnexion puis reconnexion WhatsApp.',
          ],
        ),
        HelpSection(
          title: 'Résoudre un conflit — pas à pas',
          steps: [
            'Touchez l\'icône cloud → « Résoudre les conflits ».',
            'Ou ouvrez Plus → Conflits de synchronisation.',
            'Pour chaque conflit, comparez version locale et version cloud.',
            'Choisissez la version correcte et validez.',
            'Relancez la synchronisation pour confirmer.',
          ],
          tip:
              'Évitez de modifier le même produit sur deux appareils en même temps.',
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
          title: 'Consulter le journal — pas à pas',
          steps: [
            'Ouvrez Plus → Journal d\'audit (patron uniquement).',
            'Parcourez la liste chronologique des actions sensibles.',
            'Touchez une ligne pour voir le détail (qui, quoi, quand).',
          ],
        ),
        HelpSection(
          title: 'Filtrer le journal — pas à pas',
          steps: [
            'Dans le journal, touchez l\'icône filtre.',
            'Choisissez un module (ventes, stock, dettes, utilisateurs…).',
            'Choisissez une action (création, modification, annulation…).',
            'Définissez une période si besoin.',
            'Validez : la liste affiche uniquement les entrées correspondantes.',
          ],
        ),
        HelpSection(
          title: 'Exporter le journal en PDF — pas à pas',
          steps: [
            'Appliquez les filtres souhaités.',
            'Touchez l\'icône export / partage.',
            'Choisissez PDF et la destination (WhatsApp, Drive…).',
          ],
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
          title: 'Configurer les alertes — pas à pas',
          steps: [
            'Ouvrez Plus → Alertes (ou Paramètres → Notifications).',
            'Activez ou désactivez chaque type d\'alerte.',
            'Accordez la permission système si l\'appareil le demande.',
            'Pour le résumé du jour : choisissez l\'heure d\'envoi.',
          ],
        ),
        HelpSection(
          title: 'Types d\'alertes disponibles',
          body: 'Chaque alerte répond à un besoin précis :',
          bullets: [
            'Stock bas : produit sous le seuil d\'alerte.',
            'Dettes : échéances et relances clients.',
            'Résumé du jour : CA et ventes en fin de journée.',
            'Sauvegarde : rappel si aucune sauvegarde récente.',
          ],
          tip:
              'Les alertes stock évitent les ruptures sur vos produits les plus vendus.',
        ),
      ],
    ),
    HelpArticle(
      id: 'calculators',
      categoryId: 'finance',
      title: 'Calculateurs métiers',
      summary:
          'Carrelage, peinture, béton et autres calculs pour vos devis chantier.',
      icon: Icons.calculate_outlined,
      color: Color(0xFF5D4037),
      keywords: ['calculateur', 'carrelage', 'peinture', 'béton', 'devis'],
      sections: [
        HelpSection(
          title: 'Utiliser un calculateur — pas à pas',
          steps: [
            'Ouvrez Plus → Calculateurs métiers.',
            'Choisissez le type de calcul (carrelage, peinture, béton…).',
            'Saisissez les dimensions ou quantités demandées.',
            'L\'application calcule automatiquement le résultat.',
            'Exportez en PDF si besoin pour un devis client.',
          ],
        ),
        HelpSection(
          title: 'À quoi ça sert',
          body:
              'Les calculateurs aident à estimer les quantités de matériaux '
              'pour vos chantiers ou devis, sans quitter ARIKE.',
          tip:
              'Ces calculs n\'impactent pas votre stock — utilisez une vente classique pour facturer.',
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
    for (final a in visibleArticles) {
      if (a.id == id) return a;
    }
    return null;
  }

  static List<HelpArticle> articlesForCategory(String categoryId) =>
      visibleArticles.where((a) => a.categoryId == categoryId).toList();

  static List<HelpArticle> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return visibleArticles;
    return visibleArticles.where((a) {
      if (a.title.toLowerCase().contains(q)) return true;
      if (a.summary.toLowerCase().contains(q)) return true;
      for (final k in a.keywords) {
        if (k.toLowerCase().contains(q)) return true;
      }
      for (final s in a.sections) {
        if (s.title.toLowerCase().contains(q)) return true;
        if (s.body.toLowerCase().contains(q)) return true;
        for (final step in s.steps) {
          if (step.toLowerCase().contains(q)) return true;
        }
      }
      return false;
    }).toList();
  }

  static List<HelpArticle> get visibleArticles => articles;
}
