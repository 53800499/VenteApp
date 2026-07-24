import '../entities/voice_draft.dart';
import '../services/voice_intent_parser.dart';
import 'voice_workflow.dart';

/// Vente : phrase structurée (prix optionnel = prix boutique).
class SaleCartWorkflow extends VoiceWorkflow {
  SaleCartWorkflow({
    required this.parser,
    required this.products,
    required this.customers,
  });

  final VoiceIntentParser parser;
  final List<VoiceCatalogProduct> products;
  final List<VoiceCatalogCustomer> customers;

  static const _formatHint =
      'Dites : produit Sac quantité 20\n'
      'ou : produit Sac quantité 20 prix 3000\n'
      'ou : produit Sac prix 3000 quantité 20\n'
      '(sans prix → prix boutique)';

  VoiceWorkflowStatus _status = VoiceWorkflowStatus.asking;
  VoiceWorkflowPrompt? _prompt;
  String? _failure;
  VoiceSaleDraft? _draft;

  @override
  VoiceIntentKind get kind => VoiceIntentKind.sale;

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
    _prompt = const VoiceWorkflowPrompt(
      question: 'Ligne de vente',
      details: _formatHint,
    );
    _status = VoiceWorkflowStatus.asking;
    if (_tryCommit(initialTranscript)) return;
  }

  @override
  Future<void> advance(String transcript) async {
    if (_status != VoiceWorkflowStatus.asking) return;
    if (_tryCommit(transcript)) return;
    _prompt = const VoiceWorkflowPrompt(
      question: 'Format non reconnu. Relisez la ligne.',
      details: _formatHint,
    );
  }

  @override
  void cancel() {
    _status = VoiceWorkflowStatus.cancelled;
    _prompt = null;
  }

  bool _tryCommit(String transcript) {
    final structured = parser.parseStructuredSaleLine(transcript);
    if (structured == null) return false;
    final product =
        parser.matchProductByName(structured.productQuery, products);
    if (product == null) {
      _prompt = VoiceWorkflowPrompt(
        question: 'Produit introuvable.',
        details: '« ${structured.productQuery} » n’est pas dans le stock.\n'
            '$_formatHint',
      );
      return true;
    }
    if (structured.quantity > product.quantityInStock) {
      _prompt = VoiceWorkflowPrompt(
        question: 'Stock insuffisant (${product.quantityInStock}).',
        details: _formatHint,
      );
      return true;
    }
    final unitPrice = structured.unitPrice ?? product.priceSell;
    _draft = VoiceSaleDraft(
      transcript: transcript,
      missingFields: const [],
      lines: [
        VoiceSaleLine(
          productId: product.id,
          productName: product.name,
          quantity: structured.quantity,
          unitPrice: unitPrice,
          lineTotal: unitPrice * structured.quantity,
          stockAvailable: product.quantityInStock,
        ),
      ],
    );
    _status = VoiceWorkflowStatus.ready;
    _prompt = null;
    return true;
  }
}
