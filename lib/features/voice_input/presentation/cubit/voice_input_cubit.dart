import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/speech_recognition_service.dart';
import '../../data/voice_input_preferences.dart';
import '../../domain/entities/voice_draft.dart';
import '../../domain/entities/voice_intent_detection.dart';
import '../../domain/services/voice_intent_parser.dart';

enum VoiceInputStatus {
  idle,
  preparing,
  listening,
  parsing,
  preview,
  cancelled,
  error,
}

class VoiceInputState extends Equatable {
  const VoiceInputState({
    this.status = VoiceInputStatus.idle,
    this.partialText = '',
    this.draft,
    this.detection = VoiceIntentDetection.empty,
    this.errorMessage,
    this.enabled = true,
  });

  final VoiceInputStatus status;
  final String partialText;
  final VoiceDraft? draft;
  final VoiceIntentDetection detection;
  final String? errorMessage;
  final bool enabled;

  VoiceInputState copyWith({
    VoiceInputStatus? status,
    String? partialText,
    VoiceDraft? draft,
    VoiceIntentDetection? detection,
    String? errorMessage,
    bool? enabled,
    bool clearDraft = false,
    bool clearError = false,
    bool clearDetection = false,
  }) {
    return VoiceInputState(
      status: status ?? this.status,
      partialText: partialText ?? this.partialText,
      draft: clearDraft ? null : (draft ?? this.draft),
      detection: clearDetection
          ? VoiceIntentDetection.empty
          : (detection ?? this.detection),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  List<Object?> get props =>
      [status, partialText, draft, detection, errorMessage, enabled];
}

class VoiceInputCubit extends Cubit<VoiceInputState> {
  VoiceInputCubit({
    required SpeechRecognitionService speech,
    required VoiceIntentParser parser,
    required VoiceInputPreferences preferences,
  })  : _speech = speech,
        _parser = parser,
        _preferences = preferences,
        super(VoiceInputState(enabled: preferences.isEnabled));

  final SpeechRecognitionService _speech;
  final VoiceIntentParser _parser;
  final VoiceInputPreferences _preferences;

  void refreshEnabled() {
    emit(state.copyWith(enabled: _preferences.isEnabled));
  }

  void markPreparing() {
    emit(
      state.copyWith(
        status: VoiceInputStatus.preparing,
        partialText: '',
        clearDraft: true,
        clearDetection: true,
        clearError: true,
      ),
    );
  }

  Future<void> setEnabled(bool value) async {
    await _preferences.setEnabled(value);
    emit(state.copyWith(enabled: value));
  }

  Future<void> capture({
    required VoiceIntentKind expectedKind,
    List<VoiceCatalogProduct> products = const [],
    List<VoiceCatalogCustomer> customers = const [],
    List<VoiceCatalogCategory> categories = const [],
    List<VoiceCatalogSupplier> suppliers = const [],
    List<VoiceCatalogOpenDebt> openDebts = const [],
    List<VoiceFxRateInfo> fxRates = const [],
    int? fxSessionId,
  }) async {
    await _captureInternal(
      expectedKind: expectedKind,
      products: products,
      customers: customers,
      categories: categories,
      suppliers: suppliers,
      openDebts: openDebts,
      fxRates: fxRates,
      fxSessionId: fxSessionId,
    );
  }

  /// Détection automatique d'intent (assistant global V2).
  Future<void> captureAuto({
    List<VoiceCatalogProduct> products = const [],
    List<VoiceCatalogCustomer> customers = const [],
    List<VoiceCatalogCategory> categories = const [],
    List<VoiceCatalogSupplier> suppliers = const [],
    List<VoiceCatalogOpenDebt> openDebts = const [],
    List<VoiceFxRateInfo> fxRates = const [],
    int? fxSessionId,
  }) {
    return _captureInternal(
      expectedKind: null,
      products: products,
      customers: customers,
      categories: categories,
      suppliers: suppliers,
      openDebts: openDebts,
      fxRates: fxRates,
      fxSessionId: fxSessionId,
    );
  }

  Future<void> _captureInternal({
    required VoiceIntentKind? expectedKind,
    List<VoiceCatalogProduct> products = const [],
    List<VoiceCatalogCustomer> customers = const [],
    List<VoiceCatalogCategory> categories = const [],
    List<VoiceCatalogSupplier> suppliers = const [],
    List<VoiceCatalogOpenDebt> openDebts = const [],
    List<VoiceFxRateInfo> fxRates = const [],
    int? fxSessionId,
  }) async {
    if (!state.enabled) {
      emit(
        state.copyWith(
          status: VoiceInputStatus.error,
          errorMessage: 'La saisie vocale est désactivée dans les paramètres.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: VoiceInputStatus.listening,
        partialText: '',
        clearDraft: true,
        clearDetection: true,
        clearError: true,
      ),
    );

    try {
      final transcript = await _speech.listenOnce(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 12),
        onPartial: (p) {
          if (!isClosed) {
            emit(state.copyWith(partialText: p));
          }
        },
      );

      emit(
        state.copyWith(
          status: VoiceInputStatus.parsing,
          partialText: transcript,
        ),
      );

      final detection = expectedKind == null
          ? _parser.detectDetailed(transcript)
          : VoiceIntentDetection(
              kind: expectedKind,
              confidence: 1,
              rawScore: 20,
            );

      final draft = _parser.parse(
        transcript: transcript,
        expectedKind: expectedKind ??
            (detection.kind == VoiceIntentKind.unknown
                ? null
                : detection.kind),
        products: products,
        customers: customers,
        categories: categories,
        suppliers: suppliers,
        openDebts: openDebts,
        fxRates: fxRates,
        fxSessionId: fxSessionId,
      );

      emit(
        state.copyWith(
          status: VoiceInputStatus.preview,
          draft: draft,
          detection: detection,
          partialText: transcript,
        ),
      );
    } on SpeechCancelledException {
      emit(
        state.copyWith(
          status: VoiceInputStatus.cancelled,
          clearDraft: true,
          clearError: true,
          partialText: '',
        ),
      );
    } on SpeechRecognitionException catch (e) {
      emit(
        state.copyWith(
          status: VoiceInputStatus.error,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: VoiceInputStatus.error,
          errorMessage: 'Erreur vocale : $e',
        ),
      );
    }
  }

  /// Ré-analyse le transcript avec une intention choisie (clarification).
  void reparseWithKind({
    required VoiceIntentKind kind,
    List<VoiceCatalogProduct> products = const [],
    List<VoiceCatalogCustomer> customers = const [],
    List<VoiceCatalogCategory> categories = const [],
    List<VoiceCatalogSupplier> suppliers = const [],
    List<VoiceCatalogOpenDebt> openDebts = const [],
    List<VoiceFxRateInfo> fxRates = const [],
    int? fxSessionId,
  }) {
    final transcript = state.draft?.transcript ?? state.partialText;
    if (transcript.trim().isEmpty) return;

    final draft = _parser.parse(
      transcript: transcript,
      expectedKind: kind,
      products: products,
      customers: customers,
      categories: categories,
      suppliers: suppliers,
      openDebts: openDebts,
      fxRates: fxRates,
      fxSessionId: fxSessionId,
    );

    emit(
      state.copyWith(
        status: VoiceInputStatus.preview,
        draft: draft,
        detection: VoiceIntentDetection(
          kind: kind,
          confidence: 1,
          rawScore: 20,
        ),
        partialText: transcript,
      ),
    );
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: VoiceInputStatus.cancelled,
        clearDraft: true,
        clearError: true,
        partialText: '',
      ),
    );
  }

  /// Écoute une réponse de workflow sans parser d'intent.
  /// Retourne le transcript, ou `null` si annulé / erreur.
  Future<String?> captureTranscriptOnly() async {
    if (!state.enabled) {
      emit(
        state.copyWith(
          status: VoiceInputStatus.error,
          errorMessage: 'La saisie vocale est désactivée dans les paramètres.',
        ),
      );
      return null;
    }

    emit(
      state.copyWith(
        status: VoiceInputStatus.listening,
        partialText: '',
        clearDraft: true,
        clearError: true,
      ),
    );

    try {
      final transcript = await _speech.listenOnce(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 12),
        onPartial: (p) {
          if (!isClosed) {
            emit(state.copyWith(partialText: p));
          }
        },
      );
      if (isClosed) return null;
      emit(
        state.copyWith(
          status: VoiceInputStatus.idle,
          partialText: transcript,
        ),
      );
      return transcript.trim().isEmpty ? null : transcript.trim();
    } on SpeechCancelledException {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: VoiceInputStatus.cancelled,
            clearDraft: true,
            clearError: true,
            partialText: '',
          ),
        );
      }
      return null;
    } on SpeechRecognitionException catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: VoiceInputStatus.error,
            errorMessage: e.message,
          ),
        );
      }
      return null;
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: VoiceInputStatus.error,
            errorMessage: 'Erreur vocale : $e',
          ),
        );
      }
      return null;
    }
  }

  /// Valide la phrase en cours sans attendre le silence.
  Future<void> finishListening() => _speech.finishListening();

  void reset() {
    emit(
      state.copyWith(
        status: VoiceInputStatus.idle,
        partialText: '',
        clearDraft: true,
        clearDetection: true,
        clearError: true,
        enabled: _preferences.isEnabled,
      ),
    );
  }
}
