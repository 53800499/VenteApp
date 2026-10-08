// Dictionnaire et utilitaires de traduction des codes modules et forfaits
// pour un affichage lisible et professionnel en français pour l'utilisateur final.

String formatModuleName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  // Si c'est déjà une phrase lisible avec espaces et minuscules, la conserver
  if (trimmed.contains(' ') && trimmed != trimmed.toUpperCase()) {
    return trimmed;
  }

  final key = trimmed.toUpperCase().replaceAll('-', '_');

  return _moduleFrenchLabels[key] ??
      _moduleFrenchLabels[trimmed] ??
      _humanizeRawCode(trimmed);
}

String formatSubscriptionStatus(String status) {
  final s = status.trim().toUpperCase();
  switch (s) {
    case 'ACTIVE':
      return 'Actif';
    case 'TRIAL':
      return 'Essai gratuit';
    case 'GRACE':
      return 'Période de grâce';
    case 'PENDING_ACTIVATION':
      return 'En attente d\'activation';
    case 'EXPIRED':
      return 'Expiré';
    case 'REVOKED':
      return 'Accès révoqué';
    case 'SUSPENDED':
      return 'Suspendu';
    case 'INACTIVE':
      return 'Inactif';
    case 'PAID':
    case 'SUCCESS':
    case 'COMPLETED':
      return 'Payé';
    case 'PENDING':
    case 'PROCESSING':
      return 'En attente';
    case 'FAILED':
      return 'Échoué';
    case 'CANCELLED':
    case 'CANCELED':
      return 'Annulé';
    case 'NONE':
    case '':
      return 'Aucun forfait';
    default:
      return status;
  }
}

String formatPlanName(String? planCode) {
  if (planCode == null || planCode.trim().isEmpty) return 'Aucun forfait actif';
  final code = planCode.trim().toUpperCase();
  switch (code) {
    case 'FREE':
    case 'STARTER':
      return 'ARIKE Gratuit (Local)';
    case 'ESSENTIEL':
      return 'ARIKE Essentiel';
    case 'PRO':
      return 'ARIKE Pro';
    case 'BUSINESS':
      return 'ARIKE Business';
    case 'ENTERPRISE':
      return 'ARIKE Enterprise';
    case 'NONE':
      return 'Aucun forfait';
    default:
      if (planCode.toLowerCase().startsWith('arike')) {
        return planCode;
      }
      return 'ARIKE $planCode';
  }
}

String _humanizeRawCode(String raw) {
  // Convertit FOO_BAR en "Foo bar"
  final clean = raw.replaceAll('_', ' ').toLowerCase();
  if (clean.isEmpty) return '';
  return clean[0].toUpperCase() + clean.substring(1);
}

const _moduleFrenchLabels = <String, String>{
  // Modules principaux
  'SALES': 'Ventes & Caisse enregistreuse',
  'sales': 'Ventes & Caisse enregistreuse',
  'INVENTORY': 'Gestion du stock & Alertes rupture',
  'inventory': 'Gestion du stock & Alertes rupture',
  'CUSTOMERS': 'Fichier clients & Suivi des comptes',
  'customers': 'Fichier clients & Suivi des comptes',
  'DEBTS': 'Suivi des dettes & Crédits clients',
  'debts': 'Suivi des dettes & Crédits clients',
  'EXPENSES': 'Dépenses & Charges de caisse',
  'expenses': 'Dépenses & Charges de caisse',
  'CASH_SESSIONS': 'Sessions de caisse & Clôtures',
  'cash_sessions': 'Sessions de caisse & Clôtures',
  'cashSessions': 'Sessions de caisse & Clôtures',
  'REPORTS_BASIC': 'Statistiques de base & Chiffre d\'affaires',
  'REPORTS_ADVANCED': 'Analyses financières avancées & Marges',
  'reports': 'Statistiques & Analyses commerciales',
  'SYNC': 'Fonctionnement 100% Hors-ligne & Sync Cloud',
  'sync': 'Fonctionnement 100% Hors-ligne & Sync Cloud',
  'CLOUD_SYNC': 'Sauvegarde Cloud automatique',
  'cloud_sync': 'Sauvegarde Cloud automatique',

  // Modules Pro & Business
  'SALES_ORDERS': 'Commandes clients & Bons de livraison',
  'sales_orders': 'Commandes clients & Bons de livraison',
  'salesOrders': 'Commandes clients & Bons de livraison',
  'PROCUREMENT': 'Approvisionnements & Commandes fournisseurs',
  'procurement': 'Approvisionnements & Commandes fournisseurs',
  'purchases': 'Approvisionnements & Commandes fournisseurs',
  'AUDIT_LOG': 'Journal d\'audit & Sécurité',
  'audit_log': 'Journal d\'audit & Sécurité',
  'audit': 'Journal d\'audit & Sécurité',
  'STOCK_TRANSFERS': 'Transferts de stock inter-boutiques',
  'stock_transfers': 'Transferts de stock inter-boutiques',
  'stockTransfers': 'Transferts de stock inter-boutiques',
  'inventoryTransfer': 'Transferts de stock inter-boutiques',
  'MULTI_SHOP': 'Gestion multi-boutiques (Réseau)',
  'multi_shop': 'Gestion multi-boutiques (Réseau)',
  'multiShop': 'Gestion multi-boutiques (Réseau)',

  // Options & Addons
  'FX_CHANGE': 'Bureau de Change FX (Devises)',
  'FX_EXCHANGE': 'Bureau de Change FX (Devises)',
  'fx_exchange': 'Bureau de Change FX (Devises)',
  'fxExchange': 'Bureau de Change FX (Devises)',
  'AI_ASSISTANT': 'Assistant Vocal Intelligent ARIKE',
  'ai_assistant': 'Assistant Vocal Intelligent ARIKE',
  'assistant': 'Assistant Vocal Intelligent ARIKE',
  'API_ACCESS': 'Accès API dédiée & Intégrations',
  'api_access': 'Accès API dédiée & Intégrations',
  'apiAccess': 'Accès API dédiée & Intégrations',
  'ALL_MODULES': 'Tous les modules ARIKE inclus',
  'CUSTOM_INTEGRATIONS': 'Intégrations sur mesure',
  'DEDICATED_SUPPORT': 'Support prioritaire 24/7 & Configuration',
  'EXTRA_SHOP': 'Boutique supplémentaire',
  'USER_PACK_5': 'Pack 5 utilisateurs supplémentaires',
  'INITIAL_TRAINING': 'Formation initiale & Démarrage',
  'PREMIUM_SUPPORT': 'Support prioritaire & Accompagnement',
};
