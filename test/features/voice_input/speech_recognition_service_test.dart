import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/voice_input/data/speech_recognition_service.dart';

void main() {
  group('SpeechRecognitionService.mergeTranscripts', () {
    test('retourne candidate quand accumulated est vide', () {
      expect(
        SpeechRecognitionService.mergeTranscripts('', 'Vends 10 sachets'),
        equals('Vends 10 sachets'),
      );
    });

    test('retourne accumulated quand candidate est vide', () {
      expect(
        SpeechRecognitionService.mergeTranscripts('Vends 10 sachets', ''),
        equals('Vends 10 sachets'),
      );
    });

    test('reprend candidate si candidate commence par accumulated (contexte complet)', () {
      expect(
        SpeechRecognitionService.mergeTranscripts(
          'Vends 10 sachets',
          'Vends 10 sachets de lait',
        ),
        equals('Vends 10 sachets de lait'),
      );
    });

    test('conserve accumulated sans doublons si candidate est déjà contenu à la fin', () {
      expect(
        SpeechRecognitionService.mergeTranscripts(
          'Vends 10 sachets de lait',
          'sachets de lait',
        ),
        equals('Vends 10 sachets de lait'),
      );
    });

    test('fusionne avec détection de chevauchement de mot aux frontières', () {
      expect(
        SpeechRecognitionService.mergeTranscripts(
          'Vends 10 sachets',
          'sachets de lait',
        ),
        equals('Vends 10 sachets de lait'),
      );
    });

    test('concatène proprement deux segments distincts sans chevauchement', () {
      expect(
        SpeechRecognitionService.mergeTranscripts(
          'Vends 10 sachets de lait',
          'et deux cartons de sucre',
        ),
        equals('Vends 10 sachets de lait et deux cartons de sucre'),
      );
    });

    test('gère les majuscules et espaces irréguliers lors de la fusion', () {
      expect(
        SpeechRecognitionService.mergeTranscripts(
          '  VENDS 10  SACHETS  ',
          'sachets   DE LAIT  ',
        ),
        equals('VENDS 10 SACHETS DE LAIT'),
      );
    });
  });
}
