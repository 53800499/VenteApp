import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechRecognitionException implements Exception {
  SpeechRecognitionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Annulation volontaire de l'écoute (pas une erreur utilisateur).
class SpeechCancelledException implements Exception {
  @override
  String toString() => 'Écoute annulée.';
}

/// Wrap STT local / appareil.
///
/// Important : Android envoie souvent `done` / `notListening` au milieu
/// d’une phrase. On **ne valide pas** automatiquement : seule
/// [finishListening] ou le délai max [listenFor] termine la session.
/// Si le moteur coupe trop tôt, on relance l’écoute pour continuer.
class SpeechRecognitionService {
  SpeechRecognitionService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  String? _localeId;
  Completer<String>? _listenCompleter;
  String _latestWords = '';
  double _latestConfidence = -1;

  /// true uniquement après [finishListening] ou timeout max.
  bool _finishRequested = false;
  bool _restarting = false;
  Duration _activeListenFor = const Duration(seconds: 45);
  Duration _activePauseFor = const Duration(seconds: 12);
  void Function(String partial)? _activeOnPartial;
  Timer? _hardTimeout;

  bool get isAvailable => _initialized && _speech.isAvailable;
  bool get isListening => _speech.isListening;
  String? get activeLocaleId => _localeId;

  Future<bool> ensureReady() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw SpeechRecognitionException(
        'Permission micro refusée. Autorisez le micro dans les réglages.',
      );
    }

    if (_initialized) {
      _localeId ??= await _resolveFrenchLocale();
      return _speech.isAvailable;
    }

    final ready = await _speech.initialize(
      onError: (error) {
        final isPermanent = error.permanent == true;
        if (_listenCompleter != null &&
            !(_listenCompleter!.isCompleted) &&
            _latestWords.isEmpty &&
            isPermanent &&
            _finishRequested) {
          _listenCompleter!.completeError(
            SpeechRecognitionException(
              'Reconnaissance interrompue. Réessayez.',
            ),
          );
        }
      },
      onStatus: _onEngineStatus,
    );
    _initialized = ready == true;
    if (!_initialized) {
      throw SpeechRecognitionException(
        'Reconnaissance vocale indisponible sur cet appareil.',
      );
    }

    _localeId = await _resolveFrenchLocale();
    return true;
  }

  /// Préfère fr_FR / fr-FR (meilleure qualité) puis autres FR.
  Future<String?> _resolveFrenchLocale() async {
    final locales = await _speech.locales();
    if (locales.isEmpty) {
      return (await _speech.systemLocale())?.localeId;
    }

    String norm(String id) =>
        id.toLowerCase().replaceAll('-', '_').trim();

    LocaleName? pick(bool Function(String id) test) {
      for (final l in locales) {
        if (test(norm(l.localeId))) return l;
      }
      return null;
    }

    final preferred = pick((id) => id == 'fr_fr' || id.startsWith('fr_fr_')) ??
        pick((id) => id == 'fr_be' || id.startsWith('fr_be_')) ??
        pick((id) => id == 'fr_bj' || id.startsWith('fr_bj_')) ??
        pick((id) => id == 'fr_ci' || id.startsWith('fr_ci_')) ??
        pick((id) => id == 'fr_sn' || id.startsWith('fr_sn_')) ??
        pick((id) => id.startsWith('fr_') || id == 'fr') ??
        pick((id) => id.contains('fr'));

    if (preferred != null) return preferred.localeId;

    final system = await _speech.systemLocale();
    return system?.localeId;
  }

  void _onEngineStatus(String status) {
    final c = _listenCompleter;
    if (c == null || c.isCompleted) return;
    if (status != 'done' && status != 'notListening') return;

    // Validation volontaire ou timeout → terminer après un court délai.
    if (_finishRequested) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          _completeListen();
        }),
      );
      return;
    }

    // Coupe précoce du moteur : relancer l’écoute, ne pas soumettre.
    unawaited(_restartListenIfNeeded());
  }

  Future<void> _restartListenIfNeeded() async {
    final c = _listenCompleter;
    if (c == null || c.isCompleted || _finishRequested || _restarting) {
      return;
    }
    _restarting = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_listenCompleter == null ||
          _listenCompleter!.isCompleted ||
          _finishRequested) {
        return;
      }
      if (_speech.isListening) return;
      await _startEngineListen();
    } catch (_) {
      // Si la relance échoue, on garde le texte déjà capturé ;
      // l’utilisateur valide avec « J’ai fini ».
    } finally {
      _restarting = false;
    }
  }

  Future<void> _startEngineListen() async {
    await _speech.listen(
      onResult: (r) {
        _absorbResult(r, _activeOnPartial);
      },
      listenOptions: SpeechListenOptions(
        listenFor: _activeListenFor,
        pauseFor: _activePauseFor,
        localeId: _localeId,
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        onDevice: false,
        autoPunctuation: true,
      ),
    );
  }

  /// Écoute longue (phrases métier). Utiliser [finishListening] pour valider.
  Future<String> listenOnce({
    Duration listenFor = const Duration(seconds: 60),
    Duration pauseFor = const Duration(seconds: 12),
    void Function(String partial)? onPartial,
  }) async {
    await ensureReady();
    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    _latestWords = '';
    _latestConfidence = -1;
    _finishRequested = false;
    _restarting = false;
    _activeListenFor = listenFor;
    _activePauseFor = pauseFor;
    _activeOnPartial = onPartial;
    _listenCompleter = Completer<String>();
    _hardTimeout?.cancel();

    try {
      await _startEngineListen();
    } catch (e) {
      _listenCompleter = null;
      throw SpeechRecognitionException(
        'Impossible de démarrer le micro. Réessayez.',
      );
    }

    // Seule limite dure : durée max de session (pas la pause moteur).
    _hardTimeout = Timer(listenFor, () {
      if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
        _finishRequested = true;
        _completeListen();
      }
    });

    try {
      final text = await _listenCompleter!.future;
      final cleaned = _normalizeTranscript(text);
      if (cleaned.isEmpty) {
        throw SpeechRecognitionException(
          'Aucune parole détectée. Réessayez près du micro, '
          'puis touchez « J’ai fini ».',
        );
      }
      return cleaned;
    } finally {
      _hardTimeout?.cancel();
      _hardTimeout = null;
      _listenCompleter = null;
      _activeOnPartial = null;
      _finishRequested = false;
      _restarting = false;
    }
  }

  void _absorbResult(
    SpeechRecognitionResult r,
    void Function(String partial)? onPartial,
  ) {
    final candidate = _bestAlternateText(r);
    if (candidate.isEmpty) return;

    final conf = r.hasConfidenceRating ? r.confidence : -1.0;
    final longer = candidate.length > _latestWords.length;
    final sameLenBetterConf = candidate.length == _latestWords.length &&
        conf >= 0 &&
        conf > _latestConfidence;
    final extendsCurrent = _latestWords.isNotEmpty &&
        candidate.toLowerCase().startsWith(
              _latestWords.toLowerCase().trim(),
            );

    if (_latestWords.isEmpty || longer || sameLenBetterConf || extendsCurrent) {
      _latestWords = candidate;
      if (conf >= 0) _latestConfidence = conf;
      onPartial?.call(_latestWords);
    }
  }

  String _bestAlternateText(SpeechRecognitionResult r) {
    if (r.alternates.isEmpty) return '';
    var best = r.alternates.first;
    for (final a in r.alternates.skip(1)) {
      final aConf = a.hasConfidenceRating ? a.confidence : -1.0;
      final bestConf = best.hasConfidenceRating ? best.confidence : -1.0;
      if (aConf >= 0 && bestConf >= 0) {
        if (aConf > bestConf) best = a;
      } else if (a.recognizedWords.trim().length >
          best.recognizedWords.trim().length) {
        best = a;
      }
    }
    return best.recognizedWords.trim();
  }

  /// Légères normalisations FR métier (STT confond souvent ces formes).
  String _normalizeTranscript(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return t;
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceAll(
      RegExp(r'\b(f\s*cfa|fc fa|f\.?\s*c\.?\s*f\.?\s*a\.?)\b', caseSensitive: false),
      'FCFA',
    );
    t = t.replaceAll(
      RegExp(r'\bfrancs?\s+cfa\b', caseSensitive: false),
      'francs CFA',
    );
    return t.trim();
  }

  void _completeListen() {
    final c = _listenCompleter;
    if (c == null || c.isCompleted) return;
    c.complete(_latestWords);
    unawaited(_speech.stop());
  }

  /// L'utilisateur valide manuellement la phrase en cours.
  Future<void> finishListening() async {
    _finishRequested = true;
    _hardTimeout?.cancel();
    if (_listenCompleter == null || _listenCompleter!.isCompleted) {
      if (_speech.isListening) await _speech.stop();
      return;
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
    // Laisser arriver le dernier chunk après stop.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _completeListen();
  }

  Future<void> stop() async => finishListening();

  Future<void> cancel() async {
    _finishRequested = true;
    _hardTimeout?.cancel();
    _hardTimeout = null;
    if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
      _listenCompleter!.completeError(SpeechCancelledException());
    }
    _listenCompleter = null;
    _activeOnPartial = null;
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
