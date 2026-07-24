import '../../../sales_orders/domain/entities/sales_order.dart';
import '../entities/voice_draft.dart';
import 'voice_workflow.dart';

typedef ListDeliverableOrdersFn = Future<List<SalesOrder>> Function();
typedef FindSalesOrderFn = Future<SalesOrder?> Function(int id);

/// Livraison / refus client : choisir une commande → ouvrir le formulaire.
class DeliverSalesOrderWorkflow extends VoiceWorkflow {
  DeliverSalesOrderWorkflow({
    required this.shopId,
    required this.listOrders,
    required this.findOrder,
  });

  final int shopId;
  final ListDeliverableOrdersFn listOrders;
  final FindSalesOrderFn findOrder;

  VoiceWorkflowStatus _status = VoiceWorkflowStatus.asking;
  VoiceWorkflowPrompt? _prompt;
  String? _failure;
  VoiceDeliverSalesOrderDraft? _draft;
  SalesOrder? _formTarget;

  String _transcript = '';
  List<SalesOrder> _candidates = const [];

  @override
  VoiceIntentKind get kind => VoiceIntentKind.deliverSalesOrder;

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

    List<SalesOrder> all;
    try {
      all = await listOrders();
    } catch (e) {
      _fail('Impossible de lister les commandes clients : $e');
      return;
    }

    _candidates = all.where((o) => o.canDeliver).toList();
    if (_candidates.isEmpty) {
      _fail(
        'Aucune commande client à livrer '
        '(confirmée, en préparation ou partielle).',
      );
      return;
    }

    if (_candidates.length == 1) {
      await _selectOrder(_candidates.first);
      return;
    }

    if (await _trySelectFromPhrase(initialTranscript)) return;

    _status = VoiceWorkflowStatus.asking;
    _prompt = VoiceWorkflowPrompt(
      question: 'Plusieurs commandes clients. Laquelle livrer ?',
      details: _orderListDetails(),
    );
  }

  @override
  Future<void> advance(String transcript) async {
    if (_status != VoiceWorkflowStatus.asking) return;
    if (await _trySelectFromPhrase(transcript)) return;
    _prompt = VoiceWorkflowPrompt(
      question: 'Dites « la dernière », un numéro, le n° SO ou le client.',
      details: _orderListDetails(),
    );
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
      final name = o.customerName;
      if (name.length >= 2 &&
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

  Future<void> _selectOrder(SalesOrder summary) async {
    final full = await findOrder(summary.id);
    if (full == null) {
      _fail('Commande introuvable.');
      return;
    }
    if (!full.canDeliver) {
      _fail('${full.number} n\'est plus livrable.');
      return;
    }
    if (full.totalRemaining <= 0) {
      _fail('Rien à livrer sur ${full.number}.');
      return;
    }

    _formTarget = full;
    _draft = VoiceDeliverSalesOrderDraft(
      transcript: _transcript,
      missingFields: const [],
      salesOrderId: full.id,
      orderNumber: full.number,
      customerName: full.customerName,
    );
    _prompt = null;
    _status = VoiceWorkflowStatus.openForm;
  }

  String _orderListDetails() {
    final buf = StringBuffer('Dites « la dernière » ou un numéro :\n');
    final max = _candidates.length > 5 ? 5 : _candidates.length;
    for (var i = 0; i < max; i++) {
      final o = _candidates[i];
      buf.writeln(
        '${i + 1}. ${o.number} — ${o.customerName}'
        ' (reste ${o.totalRemaining})',
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
