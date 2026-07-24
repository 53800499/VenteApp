import '../../../fx_exchange/domain/entities/fx_exchange_entities.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../entities/voice_draft.dart';
import '../services/voice_intent_parser.dart';
import 'voice_workflow.dart';

typedef FindOpenFxSessionFn = Future<FxSession?> Function({required int shopId});
typedef PreviewFxOperationFn = Future<FxOperationPreview> Function({
  required int shopId,
  required CreateFxOperationInput input,
  int? sessionId,
});

/// Change : session → devise → montant → PreviewFx → oui/non.
class FxExchangeWorkflow extends VoiceWorkflow {
  FxExchangeWorkflow({
    required this.shopId,
    required this.findOpenFxSession,
    required this.previewFxOperation,
    required this.fxRates,
    this.seed,
  });

  final int shopId;
  final FindOpenFxSessionFn findOpenFxSession;
  final PreviewFxOperationFn previewFxOperation;
  final List<VoiceFxRateInfo> fxRates;
  final VoiceFxDraft? seed;

  VoiceWorkflowStatus _status = VoiceWorkflowStatus.asking;
  VoiceWorkflowPrompt? _prompt;
  String? _failure;
  VoiceFxDraft? _draft;

  String _transcript = '';
  int? _sessionId;
  String? _opCode;
  String? _foreign;
  int? _fromAmount;
  _FxStep _step = _FxStep.session;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.fxOperation;

  @override
  VoiceWorkflowStatus get status => _status;

  @override
  VoiceWorkflowPrompt? get currentPrompt => _prompt;

  @override
  String? get failureMessage => _failure;

  @override
  VoiceDraft? get draft => _draft;

  @override
  Future<void> bootstrap(String initialTranscript) async {
    _transcript = initialTranscript;
    _opCode = seed?.operationTypeCode ?? 'sell';
    _foreign = seed?.foreignCurrency;
    _fromAmount = seed?.fromAmount;
    _sessionId = seed?.sessionId;

    final open = await findOpenFxSession(shopId: shopId);
    if (open == null) {
      _fail(
        'Aucune session de change ouverte. Ouvrez une session dans Bureau de change.',
      );
      return;
    }
    _sessionId = open.id;

    if (_foreign == null) {
      _step = _FxStep.currency;
      _status = VoiceWorkflowStatus.asking;
      _prompt = const VoiceWorkflowPrompt(
        question: 'Vers quelle devise ?',
        details: 'Par exemple : nairas, dollars, euros.',
      );
      return;
    }
    if (_fromAmount == null || _fromAmount! <= 0) {
      _step = _FxStep.amount;
      _status = VoiceWorkflowStatus.asking;
      _prompt = VoiceWorkflowPrompt(
        question: 'Quel montant en ${_opCode == 'buy' ? _foreign : 'FCFA'} ?',
      );
      return;
    }
    await _buildPreviewAndAsk();
  }

  @override
  Future<void> advance(String transcript) async {
    if (_status != VoiceWorkflowStatus.asking) return;
    final lower = transcript.toLowerCase();
    switch (_step) {
      case _FxStep.session:
        return;
      case _FxStep.currency:
        final c = _detectCurrency(lower);
        if (c == null) {
          _prompt = const VoiceWorkflowPrompt(
            question: 'Devise non reconnue. Nairas, dollars ou euros ?',
          );
          return;
        }
        _foreign = c;
        if (_fromAmount == null || _fromAmount! <= 0) {
          _step = _FxStep.amount;
          _prompt = VoiceWorkflowPrompt(
            question:
                'Quel montant en ${_opCode == 'buy' ? _foreign : 'FCFA'} ?',
          );
          return;
        }
        await _buildPreviewAndAsk();
      case _FxStep.amount:
        final amount = VoiceWorkflowParsing.extractAmount(lower);
        if (amount == null || amount <= 0) {
          _prompt = const VoiceWorkflowPrompt(
            question: 'Quel montant ? (ex. 500 000 francs)',
          );
          return;
        }
        _fromAmount = amount;
        await _buildPreviewAndAsk();
      case _FxStep.confirm:
        if (VoiceWorkflowParsing.isYes(lower)) {
          _status = VoiceWorkflowStatus.ready;
          _prompt = null;
          return;
        }
        if (VoiceWorkflowParsing.isNo(lower)) {
          _status = VoiceWorkflowStatus.cancelled;
          _prompt = null;
          return;
        }
        _prompt = const VoiceWorkflowPrompt(
          question: 'Confirmer l’opération ? Dites oui ou non.',
        );
    }
  }

  @override
  void cancel() {
    _status = VoiceWorkflowStatus.cancelled;
    _prompt = null;
  }

  Future<void> _buildPreviewAndAsk() async {
    final foreign = _foreign;
    final amount = _fromAmount;
    final sessionId = _sessionId;
    final op = _opCode ?? 'sell';
    if (foreign == null || amount == null || sessionId == null) {
      _fail('Informations de change incomplètes.');
      return;
    }

    String fromCurrency;
    String toCurrency;
    if (op == 'sell') {
      fromCurrency = 'XOF';
      toCurrency = foreign;
    } else {
      fromCurrency = foreign;
      toCurrency = 'XOF';
    }

    var toAmount = seed?.toAmount;
    String? rateLabel = seed?.rateLabel;
    for (final r in fxRates) {
      if (r.quoteCurrency.toUpperCase() == foreign) {
        if (op == 'sell') {
          toAmount = (amount * r.sellDenominator) ~/ r.sellNumerator;
          rateLabel =
              '${r.sellDenominator} $foreign = ${r.sellNumerator} FCFA';
        } else {
          toAmount = (amount * r.buyNumerator) ~/ r.buyDenominator;
          rateLabel =
              '${r.buyDenominator} $foreign = ${r.buyNumerator} FCFA';
        }
        break;
      }
    }

    if (toAmount == null) {
      _fail('Taux indisponible pour $foreign.');
      return;
    }

    try {
      final preview = await previewFxOperation(
        shopId: shopId,
        sessionId: sessionId,
        input: CreateFxOperationInput(
          operationType:
              op == 'buy' ? FxOperationType.buy : FxOperationType.sell,
          fromCurrency: fromCurrency,
          fromAmount: amount,
          toCurrency: toCurrency,
          toAmount: toAmount,
          note: 'Saisie vocale',
        ),
      );
      toAmount = preview.toAmount;
      rateLabel =
          '${preview.appliedRateDenominator} ${preview.quoteCurrency} = '
          '${preview.appliedRateNumerator} FCFA';
    } catch (_) {
      // Garder estimation locale si preview échoue (offline)
    }

    _draft = VoiceFxDraft(
      transcript: _transcript,
      missingFields: const [],
      operationTypeCode: op,
      foreignCurrency: foreign,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      fromAmount: amount,
      toAmount: toAmount,
      sessionId: sessionId,
      rateLabel: rateLabel,
    );

    final received =
        op == 'sell' ? '$toAmount $foreign' : formatFcfa(toAmount!);
    final given = op == 'sell' ? formatFcfa(amount) : '$amount $foreign';

    _step = _FxStep.confirm;
    _status = VoiceWorkflowStatus.asking;
    _prompt = VoiceWorkflowPrompt(
      question: 'Taux : ${rateLabel ?? '—'}. Vous donnez $given, '
          'vous recevez $received. Confirmer ?',
      details: 'Dites oui pour enregistrer, non pour annuler.',
    );
  }

  String? _detectCurrency(String lower) {
    if (RegExp(r'\b(naira|nairas|ngn)\b').hasMatch(lower)) return 'NGN';
    if (RegExp(r'\b(dollar|dollars|usd)\b').hasMatch(lower)) return 'USD';
    if (RegExp(r'\b(euro|euros|eur)\b').hasMatch(lower)) return 'EUR';
    if (RegExp(r'\b(cedi|cedis|ghs)\b').hasMatch(lower)) return 'GHS';
    return null;
  }

  void _fail(String message) {
    _failure = message;
    _status = VoiceWorkflowStatus.failed;
    _prompt = null;
  }
}

enum _FxStep { session, currency, amount, confirm }
