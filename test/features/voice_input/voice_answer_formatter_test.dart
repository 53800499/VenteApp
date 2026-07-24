import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/voice_input/domain/entities/voice_draft.dart';
import 'package:venteapp/features/voice_input/domain/services/voice_answer_formatter.dart';

void main() {
  test('format stock avec quantité', () {
    final text = formatVoiceAnswer(
      const VoiceStockQueryDraft(
        transcript: 'reste de ciment',
        missingFields: [],
        productId: 1,
        productName: 'Ciment 50 kg',
        quantityInStock: 42,
      ),
    );
    expect(text, contains('42'));
    expect(text, contains('Ciment 50 kg'));
  });

  test('format stock produit introuvable', () {
    final text = formatVoiceAnswer(
      const VoiceStockQueryDraft(
        transcript: 'reste de xyz',
        missingFields: ['produit'],
        rawProductQuery: 'xyz',
      ),
    );
    expect(text, contains('xyz'));
    expect(text, contains('introuvable'));
  });

  test('format solde FX sans session', () {
    final text = formatVoiceAnswer(
      const VoiceFxBalanceQueryDraft(
        transcript: 'solde nairas',
        missingFields: [],
        currencyCode: 'NGN',
        hasOpenSession: false,
      ),
    );
    expect(text, contains('session'));
    expect(text, contains('NGN'));
  });

  test('format solde FX avec montant', () {
    final text = formatVoiceAnswer(
      const VoiceFxBalanceQueryDraft(
        transcript: 'solde nairas',
        missingFields: [],
        currencyCode: 'NGN',
        hasOpenSession: true,
        balanceAmount: 150000,
      ),
    );
    expect(text, contains('Solde NGN'));
    expect(text, contains('150'));
  });

  test('format dépenses vides', () {
    final text = formatVoiceAnswer(
      const VoiceExpenseReportDraft(
        transcript: 'dépenses',
        missingFields: [],
        fromMs: 0,
        toMs: 1,
        count: 0,
        totalAmount: 0,
      ),
    );
    expect(text, contains('Aucune dépense'));
  });

  test('format dépenses avec lignes', () {
    final text = formatVoiceAnswer(
      const VoiceExpenseReportDraft(
        transcript: 'dépenses',
        missingFields: [],
        fromMs: 0,
        toMs: 1,
        count: 2,
        totalAmount: 30000,
        lines: [
          VoiceExpenseReportLine(title: 'Transport', amount: 10000),
          VoiceExpenseReportLine(title: 'Loyer', amount: 20000),
        ],
      ),
    );
    expect(text, contains('2 dépense'));
    expect(text, contains('Transport'));
    expect(text, contains('Loyer'));
  });

  test('format conseil stock vide', () {
    final text = formatVoiceAnswer(
      const VoiceStockAdviceDraft(
        transcript: 'quoi commander',
        missingFields: [],
        enriched: true,
      ),
    );
    expect(text, contains('Aucun produit'));
  });

  test('format conseil stock avec lignes', () {
    final text = formatVoiceAnswer(
      const VoiceStockAdviceDraft(
        transcript: 'quoi commander',
        missingFields: [],
        enriched: true,
        lines: [
          VoiceStockAdviceLine(
            productId: 1,
            name: 'Ciment',
            quantityInStock: 2,
            alertThreshold: 5,
            suggestedQty: 8,
          ),
          VoiceStockAdviceLine(
            productId: 2,
            name: 'Riz',
            quantityInStock: 0,
            alertThreshold: 10,
            suggestedQty: 20,
          ),
        ],
      ),
    );
    expect(text, contains('2 produit'));
    expect(text, contains('Ciment'));
    expect(text, contains('commander ~8'));
  });

  test('format caisse sans session', () {
    final text = formatVoiceAnswer(
      const VoiceCashExplainDraft(
        transcript: 'pourquoi caisse',
        missingFields: [],
        hasOpenSession: false,
        enriched: true,
      ),
    );
    expect(text, contains('Aucune session de caisse'));
  });

  test('format caisse avec totaux', () {
    final text = formatVoiceAnswer(
      const VoiceCashExplainDraft(
        transcript: 'pourquoi caisse',
        missingFields: [],
        hasOpenSession: true,
        openingCash: 50000,
        salesCash: 10000,
        expensesCash: 40000,
        withdrawalsCash: 5000,
        saleCount: 2,
        expectedCash: 15000,
        driverLines: ['Dépenses cash de 40 000 FCFA'],
        enriched: true,
      ),
    );
    expect(text, contains('Solde théorique'));
    expect(text, contains('Principales raisons'));
    expect(text, contains('Dépenses'));
  });

  test('format marge FX sans session', () {
    final text = formatVoiceAnswer(
      const VoiceFxMarginDraft(
        transcript: 'marge change',
        missingFields: [],
        hasOpenSession: false,
        enriched: true,
      ),
    );
    expect(text, contains('Aucune session de change'));
  });

  test('format marge FX avec opérations', () {
    final text = formatVoiceAnswer(
      const VoiceFxMarginDraft(
        transcript: 'marge change',
        missingFields: [],
        hasOpenSession: true,
        totalMarginFcfa: 12500,
        operationCount: 3,
        enriched: true,
      ),
    );
    expect(text, contains('Marge change'));
    expect(text, contains('3 opération'));
  });

  test('format dettes critiques vides', () {
    final text = formatVoiceAnswer(
      const VoiceDebtCriticalDraft(
        transcript: 'dettes critiques',
        missingFields: [],
        enriched: true,
      ),
    );
    expect(text, contains('Aucune dette critique'));
  });

  test('format dettes critiques avec lignes', () {
    final text = formatVoiceAnswer(
      const VoiceDebtCriticalDraft(
        transcript: 'dettes critiques',
        missingFields: [],
        enriched: true,
        totalBalanceDue: 75000,
        lines: [
          VoiceDebtCriticalLine(
            customerId: 1,
            customerName: 'Koffi',
            balanceDue: 50000,
            daysSinceActivity: 45,
          ),
          VoiceDebtCriticalLine(
            customerId: 2,
            customerName: 'Ama',
            balanceDue: 25000,
            daysSinceActivity: 60,
          ),
        ],
      ),
    );
    expect(text, contains('2 client'));
    expect(text, contains('Koffi'));
    expect(text, contains('45 j'));
  });
}
