import '../entities/voice_draft.dart';

/// Catalogue de formulations FR → intent.
/// L’intent reste stable ; on enrichit ces listes (fon/yoruba plus tard)
/// sans toucher aux workflows.
class VoiceIntentTriggerCatalog {
  const VoiceIntentTriggerCatalog._();

  /// Phrases normalisées (sans accents) qui renforcent fortement un intent.
  static const Map<VoiceIntentKind, List<String>> phrases = {
    VoiceIntentKind.receivePurchase: [
      'camion est arrive',
      'camion arrive',
      'le camion arrive',
      'camion est la',
      'le camion est la',
      'camion arrivee',
      'on a recu le camion',
      'j ai recu le camion',
      'on vient de recevoir le camion',
      'fournisseur est arrive',
      'le fournisseur est arrive',
      'fournisseur arrive',
      'livraison est arrivee',
      'livraison arrivee',
      'livraison recue',
      'livraison est recue',
      'marchandise est recue',
      'marchandise recue',
      'marchandises recues',
      'on a recu la livraison',
      'on a recu la marchandise',
      'reception commande',
      'receptionner la commande',
      'receptionner commande',
      'faire la reception',
    ],
    VoiceIntentKind.debtPayment: [
      'vient payer',
      'vient de payer',
      'vient rembourser',
      'paie sa dette',
      'payer sa dette',
      'rembourse sa dette',
      'remboursement de dette',
      'versement sur dette',
      'regle sa dette',
      'reglement de dette',
    ],
    VoiceIntentKind.stockQuery: [
      'combien me reste',
      'combien reste',
      'reste t il',
      'reste til',
      'quel stock',
      'stock de',
      'il me reste',
      'quantite restante',
      'combien j ai de',
      'combien on a de',
    ],
    VoiceIntentKind.stockAdviceQuery: [
      'quoi commander',
      'que dois je commander',
      'qu est ce que je dois commander',
      'dois je commander',
      'faut il commander',
      'stock bas',
      'stocks bas',
      'en rupture',
      'risque de rupture',
      'produits a commander',
      'a surveiller en stock',
    ],
    VoiceIntentKind.sale: [
      'je vends',
      'j ai vendu',
      'je viens de vendre',
      'on vend',
      'on a vendu',
      'on vient de vendre',
      'faire une vente',
      'passer une vente',
      'passe une vente',
      'creer une vente',
      'cree une vente',
      'nouvelle vente',
      'enregistrer une vente',
      'enregistrer la vente',
      'enregistre une vente',
      'vente de',
      'vendu a',
      'vendue a',
      'vendus a',
      'facture pour',
      'facturer',
      'faire une facture',
      'encaisser',
      'client achete',
      'a achete',
      'vient acheter',
      'vient d acheter',
      'je donne',
      'on donne',
      'je sors',
      'on sort',
    ],
    VoiceIntentKind.createProduct: [
      'nouveau produit',
      'creer un produit',
      'cree un produit',
      'ajouter un produit',
      'ajoute un produit',
      'enregistrer un produit',
      'creer produit',
    ],
    VoiceIntentKind.createCategory: [
      'nouvelle categorie',
      'creer une categorie',
      'cree une categorie',
      'ajouter une categorie',
      'ajoute une categorie',
      'creer categorie',
    ],
    VoiceIntentKind.expense: [
      'ajoute une depense',
      'ajouter une depense',
      'nouvelle depense',
      'enregistrer une depense',
      'fais une depense',
    ],
  };

  /// Bonus si une phrase du catalogue est contenue dans le texte normalisé.
  static int phraseBonus(VoiceIntentKind kind, String normalized) {
    final list = phrases[kind];
    if (list == null) return 0;
    for (final phrase in list) {
      if (normalized.contains(phrase)) return 8;
    }
    return 0;
  }
}
