import '../../../procurement/domain/entities/procurement.dart';
import '../entities/voice_draft.dart';
import 'voice_workflow.dart';

typedef ListReceivableOrdersFn = Future<List<PurchaseOrder>> Function();
typedef FindPurchaseOrderFn = Future<PurchaseOrder?> Function(int id);

/// Réception camion / PO : sélection → mono-ligne vocal (+ refus), multi → formulaire.
class ReceivePoWorkflow extends VoiceWorkflow {
  ReceivePoWorkflow({
    required this.shopId,
    required this.listOrders,
    required this.findOrder,
  });

  final int shopId;
  final ListReceivableOrdersFn listOrders;
  final FindPurchaseOrderFn findOrder;

  VoiceWorkflowStatus _status = VoiceWorkflowStatus.asking;
  VoiceWorkflowPrompt? _prompt;
  String? _failure;
  VoiceReceivePurchaseDraft? _draft;
  PurchaseOrder? _formTarget;

  String _transcript = '';
  List<PurchaseOrder> _candidates = const [];
  PurchaseOrder? _selected;
  PurchaseOrderItem? _item;
  int _remaining = 0;
  int _accepted = 0;
  int _refused = 0;
  String? _refusalReasonCode;
  bool _preferFullRefuse = false;
  _PoStep _step = _PoStep.pickOrder;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.receivePurchase;

  @override
  VoiceWorkflowStatus get status => _status;

  @override
  VoiceWorkflowPrompt? get currentPrompt => _prompt;

  @override
  String? get failureMessage => _failure;

  @override
  VoiceDraft? get draft => _draft;

  @override
  Object? get formTarget => _formTarget;

  @override
  Future<void> bootstrap(String initialTranscript) async {
    _transcript = initialTranscript;
    _preferFullRefuse = _looksLikeSupplierRefusal(initialTranscript);
    final receivable = <PurchaseOrderStatus>{
      PurchaseOrderStatus.validated,
      PurchaseOrderStatus.sent,
      PurchaseOrderStatus.partiallyReceived,
    };

    List<PurchaseOrder> all;
    try {
      all = await listOrders();
    } catch (e) {
      _fail('Impossible de lister les commandes : $e');
      return;
    }

    _candidates = all.where((o) => receivable.contains(o.status)).toList();
    if (_candidates.isEmpty) {
      _fail(
        'Aucune commande en attente de réception '
        '(validée, envoyée ou partielle).',
      );
      return;
    }

    if (_candidates.length == 1) {
      await _selectOrder(_candidates.first);
      return;
    }

    if (await _trySelectFromPhrase(initialTranscript)) return;

    _step = _PoStep.pickOrder;
    _status = VoiceWorkflowStatus.asking;
    _prompt = VoiceWorkflowPrompt(
      question: 'Plusieurs commandes. Laquelle ?',
      details: _orderListDetails(),
    );
  }

  @override
  Future<void> advance(String transcript) async {
    if (_status != VoiceWorkflowStatus.asking) return;
    switch (_step) {
      case _PoStep.pickOrder:
        if (await _trySelectFromPhrase(transcript)) return;
        _prompt = VoiceWorkflowPrompt(
          question: 'Dites « la dernière », un numéro, ou le fournisseur.',
          details: _orderListDetails(),
        );
      case _PoStep.askAcceptedQty:
        await _onAcceptedQty(transcript);
      case _PoStep.askRefusedQty:
        await _onRefusedQty(transcript);
      case _PoStep.askRefusalReason:
        await _onRefusalReason(transcript);
      case _PoStep.askPrice:
        final lower = transcript.toLowerCase();
        if (VoiceWorkflowParsing.isNo(lower)) {
          _openForm(_selected!);
          return;
        }
        if (_draft == null) {
          _fail('Réception incomplète.');
          return;
        }
        _status = VoiceWorkflowStatus.ready;
        _prompt = null;
    }
  }

  @override
  void cancel() {
    _status = VoiceWorkflowStatus.cancelled;
    _prompt = null;
  }

  Future<bool> _trySelectFromPhrase(String transcript) async {
    final lower = transcript.toLowerCase();
    if (VoiceWorkflowParsing.isLast(lower)) {
      await _selectOrder(_candidates.first);
      return true;
    }
    final n = VoiceWorkflowParsing.extractInt(lower);
    if (n != null && n >= 1 && n <= _candidates.length) {
      await _selectOrder(_candidates[n - 1]);
      return true;
    }
    for (final o in _candidates) {
      if (lower.contains(o.number.toLowerCase())) {
        await _selectOrder(o);
        return true;
      }
    }
    for (final o in _candidates) {
      final name = o.supplierName;
      if (name != null &&
          name.length >= 2 &&
          RegExp(
            r'\b' + RegExp.escape(name) + r'\b',
            caseSensitive: false,
          ).hasMatch(transcript)) {
        await _selectOrder(o);
        return true;
      }
    }
    return false;
  }

  Future<void> _selectOrder(PurchaseOrder summary) async {
    final full = await findOrder(summary.id);
    if (full == null) {
      _fail('Commande introuvable.');
      return;
    }
    _selected = full;

    final items = (full.items ?? [])
        .where((it) => it.quantityRemaining > 0)
        .toList();
    if (items.isEmpty) {
      _fail('Rien à réceptionner sur ${full.number}.');
      return;
    }

    if (items.length > 1) {
      _openForm(full);
      return;
    }

    _item = items.first;
    _remaining = _item!.quantityRemaining;
    _accepted = 0;
    _refused = 0;
    _refusalReasonCode = null;

    _step = _PoStep.askAcceptedQty;
    _status = VoiceWorkflowStatus.asking;
    if (_preferFullRefuse) {
      _prompt = VoiceWorkflowPrompt(
        question:
            'Tout refusé pour ${_item!.productName ?? 'produit'} '
            '(reste $_remaining) ?',
        details: 'Oui = tout refusé, ou dites la quantité acceptée.\n'
            'Commande ${full.number}'
            '${full.supplierName != null ? ' — ${full.supplierName}' : ''}',
      );
    } else {
      _prompt = VoiceWorkflowPrompt(
        question:
            'Quantité acceptée pour ${_item!.productName ?? 'produit'} '
            '(reste $_remaining, 0 possible) ?',
        details: 'Commande ${full.number}'
            '${full.supplierName != null ? ' — ${full.supplierName}' : ''}',
      );
    }
  }

  Future<void> _onAcceptedQty(String transcript) async {
    final lower = transcript.toLowerCase();
    if (_preferFullRefuse && VoiceWorkflowParsing.isYes(lower)) {
      _accepted = 0;
      _refused = _remaining;
      await _afterAcceptedResolved();
      return;
    }
    final qty = VoiceWorkflowParsing.extractInt(lower);
    if (qty == null || qty < 0) {
      _prompt = VoiceWorkflowPrompt(
        question:
            'Quelle quantité acceptée ? (0 à $_remaining)',
      );
      return;
    }
    _accepted = qty > _remaining ? _remaining : qty;
    await _afterAcceptedResolved();
  }

  Future<void> _afterAcceptedResolved() async {
    if (_accepted < _remaining) {
      final defaultRefused = _remaining - _accepted;
      if (_refused > 0 && _refused == defaultRefused) {
        await _afterRefusedResolved();
        return;
      }
      _step = _PoStep.askRefusedQty;
      _status = VoiceWorkflowStatus.asking;
      _prompt = VoiceWorkflowPrompt(
        question: 'Le reste ($defaultRefused) est refusé ?',
        details: 'Oui, ou dites la quantité refusée (0 = rien refusé).',
      );
      return;
    }
    _refused = 0;
    _refusalReasonCode = null;
    await _finishOrAskPrice();
  }

  Future<void> _onRefusedQty(String transcript) async {
    final lower = transcript.toLowerCase();
    final defaultRefused = _remaining - _accepted;
    if (VoiceWorkflowParsing.isYes(lower)) {
      _refused = defaultRefused;
      await _afterRefusedResolved();
      return;
    }
    if (VoiceWorkflowParsing.isNo(lower)) {
      _refused = 0;
      _refusalReasonCode = null;
      await _finishOrAskPrice();
      return;
    }
    final qty = VoiceWorkflowParsing.extractInt(lower);
    if (qty == null || qty < 0) {
      _prompt = VoiceWorkflowPrompt(
        question: 'Quantité refusée ? (max $defaultRefused)',
      );
      return;
    }
    _refused = qty > defaultRefused ? defaultRefused : qty;
    await _afterRefusedResolved();
  }

  Future<void> _afterRefusedResolved() async {
    if (_accepted + _refused <= 0) {
      _prompt = VoiceWorkflowPrompt(
        question: 'Indiquez une quantité acceptée ou refusée (reste $_remaining).',
      );
      _step = _PoStep.askAcceptedQty;
      return;
    }
    if (_refused > 0) {
      _step = _PoStep.askRefusalReason;
      _status = VoiceWorkflowStatus.asking;
      _prompt = const VoiceWorkflowPrompt(
        question: 'Motif du refus ?',
        details: 'Casse, humidité, qualité, manquant, ou autre.',
      );
      return;
    }
    _refusalReasonCode = null;
    await _finishOrAskPrice();
  }

  Future<void> _onRefusalReason(String transcript) async {
    final reason = parseSupplierRefusalReason(transcript);
    if (reason == null) {
      _prompt = const VoiceWorkflowPrompt(
        question: 'Motif non reconnu. Lequel ?',
        details: 'Casse, humidité, qualité, manquant, ou autre.',
      );
      return;
    }
    _refusalReasonCode = reason.code;
    await _finishOrAskPrice();
  }

  Future<void> _finishOrAskPrice() async {
    final po = _selected;
    final it = _item;
    if (po == null || it == null) {
      _fail('Réception incomplète.');
      return;
    }

    _draft = VoiceReceivePurchaseDraft(
      transcript: _transcript,
      missingFields: const [],
      poId: po.id,
      poNumber: po.number,
      supplierName: po.supplierName,
      purchaseOrderItemId: it.id,
      productId: it.productId,
      productName: it.productName ?? 'Produit',
      quantityReceived: _accepted,
      quantityRefused: _refused > 0 ? _refused : null,
      refusalReasonCode: _refusalReasonCode,
      unitCost: it.unitCost,
      remainingBefore: _remaining,
    );

    if (_accepted > 0) {
      _step = _PoStep.askPrice;
      _status = VoiceWorkflowStatus.asking;
      _prompt = const VoiceWorkflowPrompt(
        question: 'Prix identique à la commande ?',
        details: 'Oui (défaut) ou non pour ouvrir le formulaire.',
      );
      return;
    }

    _status = VoiceWorkflowStatus.ready;
    _prompt = null;
  }

  void _openForm(PurchaseOrder po) {
    _formTarget = po;
    _draft = null;
    _prompt = null;
    _status = VoiceWorkflowStatus.openForm;
  }

  String _orderListDetails() {
    final buf = StringBuffer('Dites « la dernière » ou un numéro :\n');
    final max = _candidates.length > 5 ? 5 : _candidates.length;
    for (var i = 0; i < max; i++) {
      final o = _candidates[i];
      buf.writeln(
        '${i + 1}. ${o.number}'
        '${o.supplierName != null ? ' — ${o.supplierName}' : ''}',
      );
    }
    if (_candidates.length > 5) {
      buf.writeln('… et ${_candidates.length - 5} autre(s)');
    }
    return buf.toString().trim();
  }

  void _fail(String message) {
    _failure = message;
    _status = VoiceWorkflowStatus.failed;
    _prompt = null;
  }

  static bool _looksLikeSupplierRefusal(String transcript) {
    final lower = transcript.toLowerCase();
    if (!RegExp(r'\b(refuse|refus|refusee|refuser)\b').hasMatch(lower)) {
      return false;
    }
    // Refus client → autre intent ; ici = refus fournisseur / réception.
    if (RegExp(r'\b(client|clients)\b').hasMatch(lower)) return false;
    return true;
  }
}

enum _PoStep {
  pickOrder,
  askAcceptedQty,
  askRefusedQty,
  askRefusalReason,
  askPrice,
}

/// Mapping mots-clés → motif refus fournisseur.
SupplierRefusalReason? parseSupplierRefusalReason(String transcript) {
  final lower = transcript.toLowerCase();
  if (RegExp(r'cass|dechir|bris').hasMatch(lower)) {
    return SupplierRefusalReason.breakage;
  }
  if (RegExp(r'humid|mouill').hasMatch(lower)) {
    return SupplierRefusalReason.humidity;
  }
  if (RegExp(r'qualit|mauvais|defect').hasMatch(lower)) {
    return SupplierRefusalReason.quality;
  }
  if (RegExp(r'manquan|manque|incomplet|short').hasMatch(lower)) {
    return SupplierRefusalReason.shortDelivery;
  }
  if (RegExp(r'\bautre').hasMatch(lower)) {
    return SupplierRefusalReason.other;
  }
  return null;
}
