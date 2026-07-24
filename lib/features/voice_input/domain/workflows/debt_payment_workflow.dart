import '../../../debts/domain/entities/debt_entities.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../entities/voice_draft.dart';
import '../services/entity_matcher.dart';
import '../services/voice_intent_parser.dart';
import 'voice_workflow.dart';

typedef LoadCustomerOpenDebts = Future<List<Debt>> Function(int customerId);

/// Paiement dette : 0 / 1 / N factures, « tout » → batch confirmée.
class DebtPaymentWorkflow extends VoiceWorkflow {
  DebtPaymentWorkflow({
    required this.loadOpenDebts,
    required this.customers,
    this.matcher = const EntityMatcher(),
  });

  final LoadCustomerOpenDebts loadOpenDebts;
  final List<VoiceCatalogCustomer> customers;
  final EntityMatcher matcher;

  VoiceWorkflowStatus _status = VoiceWorkflowStatus.asking;
  VoiceWorkflowPrompt? _prompt;
  String? _failure;
  VoiceDebtPaymentDraft? _draft;
  List<VoiceDebtPaymentDraft> _batch = const [];
  String? _batchSummary;

  String _initialTranscript = '';
  VoiceCatalogCustomer? _customer;
  List<Debt> _debts = const [];
  _DebtStep _step = _DebtStep.resolveCustomer;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.debtPayment;

  @override
  VoiceWorkflowStatus get status => _status;

  @override
  VoiceWorkflowPrompt? get currentPrompt => _prompt;

  @override
  String? get failureMessage => _failure;

  @override
  VoiceDraft? get draft => _draft;

  @override
  List<VoiceDebtPaymentDraft> get batchDrafts => _batch;

  @override
  String? get batchSummary => _batchSummary;

  @override
  Future<void> bootstrap(String initialTranscript) async {
    _initialTranscript = initialTranscript;
    _step = _DebtStep.resolveCustomer;
    await _resolveCustomer(initialTranscript);
  }

  @override
  Future<void> advance(String transcript) async {
    if (_status != VoiceWorkflowStatus.asking) return;
    switch (_step) {
      case _DebtStep.resolveCustomer:
        await _resolveCustomer(transcript);
      case _DebtStep.chooseScope:
        await _handleScope(transcript);
      case _DebtStep.askAmount:
        await _handleAmount(transcript);
    }
  }

  @override
  void cancel() {
    _status = VoiceWorkflowStatus.cancelled;
    _prompt = null;
  }

  Future<void> _resolveCustomer(String transcript) async {
    final match = _matchCustomer(transcript);
    if (match == null) {
      _step = _DebtStep.resolveCustomer;
      _status = VoiceWorkflowStatus.asking;
      _prompt = const VoiceWorkflowPrompt(
        question: 'Quel client rembourse ?',
        details: 'Dites le nom du client, par exemple « Koffi ».',
      );
      return;
    }
    _customer = match;
    try {
      final debts = await loadOpenDebts(match.id);
      _debts = debts.where((d) => d.isRepayable).toList();
    } catch (e) {
      _fail('Impossible de charger les dettes : $e');
      return;
    }

    if (_debts.isEmpty) {
      _fail('${match.name} n’a aucune dette ouverte.');
      return;
    }

    if (_debts.length == 1) {
      final amount = VoiceWorkflowParsing.extractAmount(
        transcript.toLowerCase(),
      );
      final debt = _debts.first;
      if (amount != null && amount > 0) {
        _readySingle(debt, amount, transcript);
        return;
      }
      _step = _DebtStep.askAmount;
      _status = VoiceWorkflowStatus.asking;
      _prompt = VoiceWorkflowPrompt(
        question:
            'Quel montant pour ${match.name} ? (reste ${formatFcfa(debt.amountRemaining)})',
        details: debt.receiptNumber != null
            ? 'Facture ${debt.receiptNumber}'
            : null,
      );
      return;
    }

    // Multi-factures
    final tout = VoiceWorkflowParsing.isAll(transcript.toLowerCase());
    if (tout) {
      _readyAll(transcript);
      return;
    }

    final amount = VoiceWorkflowParsing.extractAmount(transcript.toLowerCase());
    // Montant seul sans « tout » ni numéro → demander le périmètre
    _step = _DebtStep.chooseScope;
    _status = VoiceWorkflowStatus.asking;
    _prompt = VoiceWorkflowPrompt(
      question:
          '${match.name} a ${_debts.length} factures ouvertes. Tout, une facture, ou un montant ?',
      details: _listDebtsDetails(seedAmount: amount),
    );
  }

  Future<void> _handleScope(String transcript) async {
    final lower = transcript.toLowerCase();
    if (VoiceWorkflowParsing.isAll(lower)) {
      _readyAll(transcript);
      return;
    }

    final idx = _parseInvoiceIndex(lower);
    if (idx != null && idx >= 0 && idx < _debts.length) {
      final debt = _debts[idx];
      final amount = VoiceWorkflowParsing.extractAmount(lower);
      if (amount != null && amount > 0) {
        _readySingle(debt, amount, transcript);
        return;
      }
      _step = _DebtStep.askAmount;
      _status = VoiceWorkflowStatus.asking;
      _prompt = VoiceWorkflowPrompt(
        question:
            'Quel montant pour la facture ${debt.receiptNumber ?? '#${debt.id}'} '
            '(reste ${formatFcfa(debt.amountRemaining)}) ?',
      );
      // Remember selected debt as sole focus
      _debts = [debt];
      return;
    }

    final amount = VoiceWorkflowParsing.extractAmount(lower);
    if (amount != null && amount > 0 && _debts.length == 1) {
      _readySingle(_debts.first, amount, transcript);
      return;
    }

    _status = VoiceWorkflowStatus.asking;
    _prompt = VoiceWorkflowPrompt(
      question: 'Dites « tout », le numéro de facture (1, 2…), ou un montant.',
      details: _listDebtsDetails(),
    );
  }

  Future<void> _handleAmount(String transcript) async {
    final amount = VoiceWorkflowParsing.extractAmount(transcript.toLowerCase());
    if (amount == null || amount <= 0) {
      _status = VoiceWorkflowStatus.asking;
      _prompt = const VoiceWorkflowPrompt(
        question: 'Quel montant en francs CFA ?',
      );
      return;
    }
    if (_debts.isEmpty) {
      _fail('Aucune dette sélectionnée.');
      return;
    }
    _readySingle(_debts.first, amount, transcript);
  }

  void _readySingle(Debt debt, int amount, String transcript) {
    final pay = amount > debt.amountRemaining ? debt.amountRemaining : amount;
    _draft = VoiceDebtPaymentDraft(
      transcript: transcript.isNotEmpty ? transcript : _initialTranscript,
      missingFields: const [],
      customerId: _customer?.id,
      customerName: _customer?.name,
      debtId: debt.id,
      amount: pay,
      amountRemaining: debt.amountRemaining,
      multipleDebts: false,
    );
    _batch = const [];
    _batchSummary = null;
    _prompt = null;
    _status = VoiceWorkflowStatus.ready;
  }

  void _readyAll(String transcript) {
    final lines = <String>[];
    final drafts = <VoiceDebtPaymentDraft>[];
    for (final d in _debts) {
      lines.add(
        '• ${d.receiptNumber ?? 'Dette #${d.id}'} : ${formatFcfa(d.amountRemaining)}',
      );
      drafts.add(
        VoiceDebtPaymentDraft(
          transcript: transcript.isNotEmpty ? transcript : _initialTranscript,
          missingFields: const [],
          customerId: _customer?.id,
          customerName: _customer?.name,
          debtId: d.id,
          amount: d.amountRemaining,
          amountRemaining: d.amountRemaining,
          multipleDebts: true,
        ),
      );
    }
    _batch = drafts;
    _batchSummary =
        'Payer tout pour ${_customer?.name ?? 'le client'} :\n${lines.join('\n')}';
    _draft = null;
    _prompt = null;
    _status = VoiceWorkflowStatus.readyBatch;
  }

  String _listDebtsDetails({int? seedAmount}) {
    final buf = StringBuffer();
    for (var i = 0; i < _debts.length; i++) {
      final d = _debts[i];
      buf.writeln(
        '${i + 1}. ${d.receiptNumber ?? '#${d.id}'} — reste ${formatFcfa(d.amountRemaining)}',
      );
    }
    if (seedAmount != null) {
      buf.writeln('Montant entendu : ${formatFcfa(seedAmount)}');
    }
    return buf.toString().trim();
  }

  int? _parseInvoiceIndex(String lower) {
    final facture = RegExp(
      r'facture\s*(?:n[°o]?\s*)?(\d+)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (facture != null) {
      final n = int.tryParse(facture.group(1)!);
      if (n != null && n >= 1) return n - 1;
    }
    if (RegExp(r'\b(premi[eè]re|premier)\b').hasMatch(lower)) return 0;
    if (RegExp(r'\b(deuxi[eè]me)\b').hasMatch(lower)) return 1;
    if (RegExp(r'\b(troisi[eè]me)\b').hasMatch(lower)) return 2;
    final bare = RegExp(r'^\s*(\d+)\s*$').firstMatch(lower);
    if (bare != null) {
      final n = int.tryParse(bare.group(1)!);
      if (n != null && n >= 1) return n - 1;
    }
    return null;
  }

  VoiceCatalogCustomer? _matchCustomer(String transcript) {
    for (final c in customers) {
      if (RegExp(
        r'\b' + RegExp.escape(c.name) + r'\b',
        caseSensitive: false,
      ).hasMatch(transcript)) {
        return c;
      }
    }
    // Fallback fuzzy on whole phrase tokens
    final cleaned = transcript
        .replaceAll(
          RegExp(
            r'\b(rembourse|rembourser|paie|payer|paiement|dette|cr[eé]dit|francs?|fcfa|vient)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\d+'), ' ')
        .trim();
    if (cleaned.length < 2) return null;
    final m = matcher.bestMatch(
      query: cleaned,
      items: customers.map((c) => (id: c.id, label: c.name)).toList(),
      minScore: 0.40,
    );
    if (m == null) return null;
    return customers.firstWhere((c) => c.id == m.id);
  }

  void _fail(String message) {
    _failure = message;
    _status = VoiceWorkflowStatus.failed;
    _prompt = null;
  }
}

enum _DebtStep { resolveCustomer, chooseScope, askAmount }
