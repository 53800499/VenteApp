import 'package:flutter_test/flutter_test.dart';

import 'package:venteapp/features/voice_input/domain/entities/voice_draft.dart';
import 'package:venteapp/features/voice_input/domain/services/voice_failure_explainer.dart';

void main() {
  test('explique intention inconnue', () {
    final text = explainVoiceDraftFailure(
      const VoiceUnknownDraft(transcript: 'bonjour'),
    );
    expect(text, contains('n’ai pas reconnu'));
    expect(text, contains('bonjour'));
  });

  test('explique produit introuvable', () {
    final text = explainVoiceDraftFailure(
      const VoiceSaleDraft(
        transcript: 'vends 2 riz',
        missingFields: ['produit'],
        lines: [
          VoiceSaleLine(rawProductQuery: 'riz', quantity: 2),
        ],
      ),
    );
    expect(text, contains('riz'));
    expect(text, contains('introuvable'));
  });

  test('explique dette sans client', () {
    final text = explainVoiceDraftFailureShort(
      const VoiceDebtPaymentDraft(
        transcript: 'rembourse 5000',
        missingFields: ['client', 'dette'],
        amount: 5000,
      ),
    );
    expect(text, contains('Client'));
    expect(text, isNot(contains('Vous avez dit')));
  });

  test('exemples de phrases selon intent', () {
    final sale = voiceExamplePhrasesFor(VoiceIntentKind.sale);
    expect(sale.first, contains('produit'));
    expect(sale.any((e) => e.contains('quantité')), isTrue);
    final unknown = voiceExamplePhrasesFor(VoiceIntentKind.unknown);
    expect(unknown.length, greaterThanOrEqualTo(3));
  });
}
