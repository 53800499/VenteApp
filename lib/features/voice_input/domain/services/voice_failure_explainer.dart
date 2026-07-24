import '../entities/voice_draft.dart';

/// Explique en français pourquoi une commande vocale ne peut pas aboutir.
String explainVoiceDraftFailure(VoiceDraft draft) {
  if (draft is VoiceUnknownDraft) {
    return 'Je n’ai pas reconnu l’intention.\n\n'
        '${draft.hint}\n\n'
        'Vous avez dit : « ${draft.transcript} ».';
  }

  final reasons = <String>[];

  switch (draft) {
    case VoiceSaleDraft d:
      if (d.lines.isEmpty || d.lines.every((l) => l.productId == null)) {
        if (d.rawProductQuery != null && d.rawProductQuery!.trim().isNotEmpty) {
          reasons.add(
            'Produit « ${d.rawProductQuery} » introuvable dans le stock.',
          );
        } else {
          reasons.add('Aucun produit reconnu dans votre phrase.');
        }
      } else {
        for (var i = 0; i < d.lines.length; i++) {
          final line = d.lines[i];
          final n = d.lines.length > 1 ? ' (ligne ${i + 1})' : '';
          if (line.productId == null) {
            final q = line.rawProductQuery;
            reasons.add(
              q != null && q.trim().isNotEmpty
                  ? 'Produit « $q » introuvable$n.'
                  : 'Produit manquant$n.',
            );
          }
          if (line.quantity == null || line.quantity! <= 0) {
            reasons.add('Quantité manquante ou invalide$n.');
          }
          if (line.resolvedUnitPrice == null ||
              line.resolvedUnitPrice! <= 0) {
            reasons.add('Prix introuvable$n.');
          }
        }
      }
      if (d.rawCustomerQuery != null &&
          d.rawCustomerQuery!.trim().isNotEmpty &&
          d.customerId == null) {
        reasons.add(
          'Client « ${d.rawCustomerQuery} » non trouvé (la vente peut quand même être enregistrée sans client).',
        );
      }
    case VoiceCreateProductDraft d:
      if (d.name == null || d.name!.trim().length < 2) {
        reasons.add('Nom du produit manquant.');
      }
      if (d.priceSell == null || d.priceSell! <= 0) {
        reasons.add('Prix de vente manquant.');
      }
      if (d.rawCategoryQuery != null &&
          d.rawCategoryQuery!.trim().isNotEmpty &&
          d.categoryId == null) {
        reasons.add(
          'Catégorie « ${d.rawCategoryQuery} » non trouvée '
          '(choisissez-la sur le formulaire).',
        );
      }
    case VoiceCreateCategoryDraft d:
      if (d.name == null || d.name!.trim().length < 2) {
        reasons.add('Nom de la catégorie manquant.');
      }
    case VoiceExpenseDraft d:
      if (d.title == null || d.title!.trim().length < 2) {
        reasons.add('Titre de la dépense manquant.');
      }
      if (d.amount == null || d.amount! <= 0) {
        reasons.add('Montant manquant ou invalide.');
      }
      if (d.rawCategoryQuery != null &&
          d.rawCategoryQuery!.trim().isNotEmpty &&
          d.categoryId == null) {
        reasons.add(
          'Catégorie « ${d.rawCategoryQuery} » non trouvée (optionnelle).',
        );
      }
    case VoiceDebtPaymentDraft d:
      if (d.customerId == null) {
        if (d.rawCustomerQuery != null &&
            d.rawCustomerQuery!.trim().isNotEmpty) {
          reasons.add('Client « ${d.rawCustomerQuery} » introuvable.');
        } else {
          reasons.add('Client débiteur non reconnu.');
        }
      }
      if (d.debtId == null && d.customerId != null) {
        reasons.add('Aucune dette ouverte pour ce client.');
      }
      if (d.amount == null || d.amount! <= 0) {
        reasons.add('Montant du paiement manquant ou invalide.');
      }
    case VoiceFxDraft d:
      if (d.sessionId == null) {
        reasons.add('Aucune session de change ouverte aujourd’hui.');
      }
      if (d.operationTypeCode == null) {
        reasons.add('Précisez achat ou vente de devise.');
      }
      if (d.foreignCurrency == null) {
        reasons.add('Devise non reconnue.');
      }
      if (d.fromAmount == null || d.fromAmount! <= 0) {
        reasons.add('Montant manquant ou invalide.');
      }
      if (d.rateLabel == null && d.toAmount == null) {
        reasons.add('Taux indisponible pour cette devise.');
      }
    case VoiceProcurementDraft d:
      if (d.productId == null) {
        if (d.rawProductQuery != null && d.rawProductQuery!.trim().isNotEmpty) {
          reasons.add(
            'Produit « ${d.rawProductQuery} » introuvable.',
          );
        } else {
          reasons.add('Produit non reconnu.');
        }
      }
      if (d.quantity == null || d.quantity! <= 0) {
        reasons.add('Quantité manquante ou invalide.');
      }
      if (d.rawSupplierQuery != null &&
          d.rawSupplierQuery!.trim().isNotEmpty &&
          d.supplierId == null) {
        reasons.add('Fournisseur « ${d.rawSupplierQuery} » non trouvé.');
      }
    case VoiceReceivePurchaseDraft d:
      if (d.poId == null) {
        reasons.add('Commande fournisseur non sélectionnée.');
      }
      if (d.quantityReceived == null || d.quantityReceived! <= 0) {
        reasons.add('Quantité reçue manquante ou invalide.');
      }
    case VoiceStockQueryDraft d:
      if (d.productId == null) {
        if (d.rawProductQuery != null && d.rawProductQuery!.trim().isNotEmpty) {
          reasons.add('Produit « ${d.rawProductQuery} » introuvable.');
        } else {
          reasons.add('Produit non reconnu dans la question.');
        }
      }
    case VoiceStockAdviceDraft _:
      break;
    case VoiceFxBalanceQueryDraft d:
      if (d.currencyCode == null) {
        reasons.add('Devise non reconnue.');
      } else if (!d.hasOpenSession) {
        reasons.add('Aucune session de change ouverte.');
      }
    case VoiceFxMarginDraft d:
      if (!d.hasOpenSession && d.enriched) {
        reasons.add('Aucune session de change ouverte.');
      }
    case VoiceExpenseReportDraft _:
      break;
    case VoiceCashExplainDraft d:
      if (!d.hasOpenSession && d.enriched) {
        reasons.add('Aucune session de caisse ouverte.');
      }
    case VoiceDebtCriticalDraft _:
      break;
    case VoiceUnknownDraft _:
      break;
  }

  if (reasons.isEmpty && draft.missingFields.isNotEmpty) {
    reasons.add(
      'Informations manquantes : ${draft.missingFields.join(', ')}.',
    );
  }

  if (reasons.isEmpty) {
    return 'La commande vocale est incomplète.\n\n'
        'Vous avez dit : « ${draft.transcript} ».';
  }

  var message =
      '${reasons.join('\n')}\n\nVous avez dit : « ${draft.transcript} ».';
  if (draft is VoiceSaleDraft) {
    message +=
        '\n\nFormat attendu :\n'
        '• produit Sac quantité 20\n'
        '• produit Sac quantité 20 prix 3000\n'
        '• produit Sac prix 3000 quantité 20\n'
        '(sans prix → prix boutique)';
  }
  if (draft is VoiceCreateProductDraft) {
    message +=
        '\n\nFormat attendu :\n'
        '• nom Ciment prix vente 5000\n'
        '• nom Ciment prix 5000 catégorie Alimentation stock 20';
  }
  if (draft is VoiceCreateCategoryDraft) {
    message +=
        '\n\nFormat attendu :\n'
        '• nom Boissons\n'
        '• catégorie Boissons description Rayon frais';
  }
  return message;
}

/// Message court pour bannière / aperçu (sans reprise de la transcription).
String explainVoiceDraftFailureShort(VoiceDraft draft) {
  final full = explainVoiceDraftFailure(draft);
  final withoutTranscript = full.split('\n\nVous avez dit').first.trim();
  return withoutTranscript;
}

/// Exemples de phrases qui passent bien (selon l’intent détecté).
List<String> voiceExamplePhrasesFor(VoiceIntentKind kind) {
  return switch (kind) {
    VoiceIntentKind.sale => const [
        'produit Sac quantité 20',
        'produit Sac quantité 20 prix 3000',
        'produit Sac prix 3000 quantité 20',
      ],
    VoiceIntentKind.createProduct => const [
        'nom Ciment prix vente 5000',
        'nom Riz prix 12000 catégorie Alimentation stock 50',
      ],
    VoiceIntentKind.createCategory => const [
        'nom Boissons',
        'catégorie Alimentation description Produits alimentaires',
      ],
    VoiceIntentKind.expense => const [
        'Ajoute une dépense de 25 000 francs pour le transport.',
        'Dépense 15 000 francs pour le carburant.',
      ],
    VoiceIntentKind.debtPayment => const [
        'Koffi paie.',
        'Rembourse 10 000 francs de la dette de Koffi.',
        'Verse 5 000 francs pour la dette de Ama.',
      ],
    VoiceIntentKind.fxOperation => const [
        'Échanger cinq cent mille francs CFA en nairas.',
        'Change 100 dollars en francs CFA.',
      ],
    VoiceIntentKind.procurementOrder => const [
        'Commande 100 tonnes de ciment chez CIMBENIN.',
        'Commander 50 sacs de riz chez le fournisseur.',
      ],
    VoiceIntentKind.receivePurchase => const [
        'Le camion est arrivé.',
        'Réception de la livraison.',
        'La dernière commande est livrée.',
      ],
    VoiceIntentKind.stockQuery => const [
        'Combien me reste-t-il de ciment ?',
        'Quel est le stock de riz ?',
      ],
    VoiceIntentKind.stockAdviceQuery => const [
        'Qu’est-ce que je dois commander ?',
        'Quels produits sont en stock bas ?',
      ],
    VoiceIntentKind.fxBalanceQuery => const [
        'Quel est mon solde en nairas ?',
        'Solde en dollars.',
      ],
    VoiceIntentKind.fxMarginQuery => const [
        'Quelle est ma marge change aujourd’hui ?',
        'Combien de marge sur le change ?',
      ],
    VoiceIntentKind.expenseReportQuery => const [
        'Montre les dépenses d’aujourd’hui.',
        'Combien de dépenses aujourd’hui ?',
      ],
    VoiceIntentKind.cashExplainQuery => const [
        'Pourquoi ma caisse est faible ?',
        'Explique l’état de la caisse.',
      ],
    VoiceIntentKind.debtCriticalQuery => const [
        'Quelles sont les dettes critiques ?',
        'Quels clients sont en retard de paiement ?',
      ],
    VoiceIntentKind.unknown => const [
        'produit Sac quantité 20',
        'Qu’est-ce que je dois commander ?',
        'Pourquoi ma caisse est faible ?',
        'Le camion est arrivé.',
      ],
  };
}

