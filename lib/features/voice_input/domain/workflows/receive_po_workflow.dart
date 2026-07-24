import '../../../procurement/domain/entities/procurement.dart';
import '../entities/voice_draft.dart';
import 'voice_workflow.dart';

typedef ListReceivableOrdersFn = Future<List<PurchaseOrder>> Function();
typedef FindPurchaseOrderFn = Future<PurchaseOrder?> Function(int id);

/// Réception camion / PO : sélection → mono-ligne vocal, multi → formulaire.
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
      case _PoStep.askQty:
        final qty = VoiceWorkflowParsing.extractInt(transcript.toLowerCase());
        if (qty == null || qty <= 0) {
          _prompt = const VoiceWorkflowPrompt(
            question: 'Quelle quantité livrée ?',
          );
          return;
        }
        await _afterQty(qty);
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
        .where((it) => it.quantityOrdered - it.quantityReceived > 0)
        .toList();
    if (items.isEmpty) {
      _fail('Rien à réceptionner sur ${full.number}.');
      return;
    }

    if (items.length > 1) {
      _openForm(full);
      return;
    }

    final it = items.first;
    final remaining = it.quantityOrdered - it.quantityReceived;
    _step = _PoStep.askQty;
    _status = VoiceWorkflowStatus.asking;
    _prompt = VoiceWorkflowPrompt(
      question:
          'Quantité livrée pour ${it.productName ?? 'produit'} '
          '(reste $remaining) ?',
      details: 'Commande ${full.number}'
          '${full.supplierName != null ? ' — ${full.supplierName}' : ''}',
    );
  }

  Future<void> _afterQty(int qty) async {
    final po = _selected;
    if (po == null) {
      _fail('Commande non sélectionnée.');
      return;
    }
    final items = (po.items ?? [])
        .where((it) => it.quantityOrdered - it.quantityReceived > 0)
        .toList();
    if (items.length != 1) {
      _openForm(po);
      return;
    }
    final it = items.first;
    final remaining = it.quantityOrdered - it.quantityReceived;
    final received = qty > remaining ? remaining : qty;

    _draft = VoiceReceivePurchaseDraft(
      transcript: _transcript,
      missingFields: const [],
      poId: po.id,
      poNumber: po.number,
      supplierName: po.supplierName,
      purchaseOrderItemId: it.id,
      productId: it.productId,
      productName: it.productName ?? 'Produit',
      quantityReceived: received,
      unitCost: it.unitCost,
      remainingBefore: remaining,
    );

    _step = _PoStep.askPrice;
    _status = VoiceWorkflowStatus.asking;
    _prompt = const VoiceWorkflowPrompt(
      question: 'Prix identique à la commande ?',
      details: 'Oui (défaut) ou non pour ouvrir le formulaire.',
    );
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
}

enum _PoStep { pickOrder, askQty, askPrice }
