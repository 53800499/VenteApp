import '../../../sales/domain/entities/sale_entities.dart';
import '../entities/voice_draft.dart';
import '../services/voice_intent_parser.dart';
import '../services/voice_replace_xy_parser.dart';
import 'voice_workflow.dart';

typedef ListRecentSaleRowsFn = Future<List<SaleListRow>> Function();
typedef FindSaleFn = Future<Sale?> Function(int id);

/// Remplacement post-vente : choisir une vente (+ X par Y) → formulaire prérempli.
class OpenSaleReplacementWorkflow extends VoiceWorkflow {
  OpenSaleReplacementWorkflow({
    required this.shopId,
    required this.listSales,
    required this.findSale,
    required this.products,
    VoiceIntentParser? parser,
  }) : parser = parser ?? VoiceIntentParser();

  final int shopId;
  final ListRecentSaleRowsFn listSales;
  final FindSaleFn findSale;
  final List<VoiceCatalogProduct> products;
  final VoiceIntentParser parser;

  VoiceWorkflowStatus _status = VoiceWorkflowStatus.asking;
  VoiceWorkflowPrompt? _prompt;
  String? _failure;
  VoiceOpenSaleReplacementDraft? _draft;
  Sale? _formTarget;

  String _transcript = '';
  List<SaleListRow> _candidates = const [];
  Sale? _selected;
  VoiceReplaceXYParse? _xy;
  String? _returnedQuery;
  String? _issuedQuery;
  int? _quantity;
  int? _returnedProductId;
  String? _returnedProductName;
  int? _issuedProductId;
  String? _issuedProductName;
  _ReplaceStep _step = _ReplaceStep.pickSale;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.openSaleReplacement;

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
    _xy = parseReplaceXY(initialTranscript);
    if (_xy != null) {
      _returnedQuery = _xy!.returnedQuery;
      _issuedQuery = _xy!.issuedQuery;
      _quantity = _xy!.quantity;
    }

    List<SaleListRow> all;
    try {
      all = await listSales();
    } catch (e) {
      _fail('Impossible de lister les ventes : $e');
      return;
    }

    _candidates = all
        .where(
          (s) =>
              s.status == SaleStatus.completed &&
              s.saleType == SaleType.standard,
        )
        .toList();
    if (_candidates.isEmpty) {
      _fail('Aucune vente standard récente à remplacer.');
      return;
    }

    if (_candidates.length == 1) {
      await _selectSale(_candidates.first);
      return;
    }

    if (await _trySelectFromPhrase(initialTranscript)) return;

    _step = _ReplaceStep.pickSale;
    _status = VoiceWorkflowStatus.asking;
    _prompt = VoiceWorkflowPrompt(
      question: 'Plusieurs ventes. Laquelle remplacer ?',
      details: _saleListDetails(),
    );
  }

  @override
  Future<void> advance(String transcript) async {
    if (_status != VoiceWorkflowStatus.asking) return;
    switch (_step) {
      case _ReplaceStep.pickSale:
        if (await _trySelectFromPhrase(transcript)) return;
        _prompt = VoiceWorkflowPrompt(
          question: 'Dites « la dernière », un numéro ou le n° de reçu.',
          details: _saleListDetails(),
        );
      case _ReplaceStep.askReturned:
        _returnedQuery = transcript.trim();
        if (_returnedQuery!.length < 2) {
          _prompt = const VoiceWorkflowPrompt(
            question: 'Quel produit revient ?',
          );
          return;
        }
        await _resolveProductsAndFinish();
      case _ReplaceStep.askIssued:
        _issuedQuery = transcript.trim();
        if (_issuedQuery!.length < 2) {
          _prompt = const VoiceWorkflowPrompt(
            question: 'Par quel produit ?',
          );
          return;
        }
        await _resolveProductsAndFinish();
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
      await _selectSale(_candidates.first);
      return true;
    }
    final n = VoiceWorkflowParsing.extractInt(lower);
    if (n != null && n >= 1 && n <= _candidates.length) {
      await _selectSale(_candidates[n - 1]);
      return true;
    }
    for (final s in _candidates) {
      final receipt = s.receiptNumber;
      if (receipt != null && lower.contains(receipt.toLowerCase())) {
        await _selectSale(s);
        return true;
      }
    }
    for (final s in _candidates) {
      final name = s.customerName;
      if (name != null &&
          name.length >= 2 &&
          RegExp(
            r'\b' + RegExp.escape(name) + r'\b',
            caseSensitive: false,
          ).hasMatch(transcript)) {
        await _selectSale(s);
        return true;
      }
    }
    return false;
  }

  Future<void> _selectSale(SaleListRow summary) async {
    final full = await findSale(summary.id);
    if (full == null) {
      _fail('Vente introuvable.');
      return;
    }
    if (full.isCancelled || full.saleType != SaleType.standard) {
      _fail('Cette vente ne peut pas être remplacée.');
      return;
    }
    if (full.items.isEmpty) {
      _fail('Aucun produit sur cette vente.');
      return;
    }

    _selected = full;
    await _resolveProductsAndFinish();
  }

  Future<void> _resolveProductsAndFinish() async {
    final sale = _selected;
    if (sale == null) {
      _fail('Vente non sélectionnée.');
      return;
    }

    final hasReturned =
        _returnedQuery != null && _returnedQuery!.trim().length >= 2;
    final hasIssued =
        _issuedQuery != null && _issuedQuery!.trim().length >= 2;

    // Option 1 : « remplacer » sans X/Y → formulaire sans préremplissage.
    if (!hasReturned && !hasIssued) {
      _openFormBare(sale);
      return;
    }

    if (!hasReturned) {
      _step = _ReplaceStep.askReturned;
      _status = VoiceWorkflowStatus.asking;
      _prompt = const VoiceWorkflowPrompt(
        question: 'Quel produit revient ?',
      );
      return;
    }

    final returnedMatch = _matchOnSaleLines(sale, _returnedQuery!);
    if (returnedMatch == null) {
      _step = _ReplaceStep.askReturned;
      _status = VoiceWorkflowStatus.asking;
      _prompt = VoiceWorkflowPrompt(
        question: 'Produit « $_returnedQuery » introuvable sur la vente.',
        details: 'Dites le nom d’un produit de cette vente.',
      );
      return;
    }
    _returnedProductId = returnedMatch.$1;
    _returnedProductName = returnedMatch.$2;

    if (!hasIssued) {
      _step = _ReplaceStep.askIssued;
      _status = VoiceWorkflowStatus.asking;
      _prompt = const VoiceWorkflowPrompt(
        question: 'Par quel produit ?',
      );
      return;
    }

    final issued = parser.matchProductByName(_issuedQuery!, products);
    if (issued == null) {
      _step = _ReplaceStep.askIssued;
      _status = VoiceWorkflowStatus.asking;
      _prompt = VoiceWorkflowPrompt(
        question: 'Produit « $_issuedQuery » introuvable au catalogue.',
        details: 'Dites le nom du produit à donner.',
      );
      return;
    }
    _issuedProductId = issued.id;
    _issuedProductName = issued.name;

    _openFormWithSeed(sale);
  }

  void _openFormBare(Sale sale) {
    _formTarget = sale;
    _draft = VoiceOpenSaleReplacementDraft(
      transcript: _transcript,
      missingFields: const [],
      saleId: sale.id,
      receiptNumber: sale.receiptNumber,
      customerName: sale.customerName,
    );
    _prompt = null;
    _status = VoiceWorkflowStatus.openForm;
  }

  void _openFormWithSeed(Sale sale) {
    _formTarget = sale;
    _draft = VoiceOpenSaleReplacementDraft(
      transcript: _transcript,
      missingFields: const [],
      saleId: sale.id,
      receiptNumber: sale.receiptNumber,
      customerName: sale.customerName,
      returnedProductId: _returnedProductId,
      returnedProductName: _returnedProductName,
      rawReturnedQuery: _returnedQuery,
      issuedProductId: _issuedProductId,
      issuedProductName: _issuedProductName,
      rawIssuedQuery: _issuedQuery,
      quantity: _quantity,
    );
    _prompt = null;
    _status = VoiceWorkflowStatus.openForm;
  }

  /// Match produit retourné sur les lignes de la vente.
  (int, String)? _matchOnSaleLines(Sale sale, String query) {
    final catalogLike = <VoiceCatalogProduct>[
      for (final item in sale.items)
        if (item.productId != null)
          VoiceCatalogProduct(
            id: item.productId!,
            name: item.productName,
            priceSell: item.unitPrice,
            quantityInStock: item.quantity,
          ),
    ];
    final match = parser.matchProductByName(query, catalogLike);
    if (match == null) return null;
    return (match.id, match.name);
  }

  String _saleListDetails() {
    final buf = StringBuffer('Dites « la dernière » ou un numéro :\n');
    final max = _candidates.length > 5 ? 5 : _candidates.length;
    for (var i = 0; i < max; i++) {
      final s = _candidates[i];
      final label = s.receiptNumber ?? 'Vente #${s.id}';
      final client = s.customerName != null ? ' — ${s.customerName}' : '';
      buf.writeln('${i + 1}. $label$client');
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

enum _ReplaceStep { pickSale, askReturned, askIssued }
