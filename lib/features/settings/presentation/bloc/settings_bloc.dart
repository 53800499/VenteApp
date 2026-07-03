import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../domain/entities/settings_entities.dart';
import '../../domain/usecases/settings_usecases.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required GetShopConfiguration getConfiguration,
    required UpdateShopConfiguration updateConfiguration,
    required RecordShopBackup recordBackup,
    required UpdateShopSyncSettings updateSyncSettings,
    required int shopId,
  })  : _getConfiguration = getConfiguration,
        _updateConfiguration = updateConfiguration,
        _recordBackup = recordBackup,
        _updateSyncSettings = updateSyncSettings,
        _shopId = shopId,
        super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoad);
    on<SettingsShopSaveRequested>(_onShopSave);
    on<SettingsThresholdChanged>(_onThresholdChanged);
    on<SettingsPricingTiersChanged>(_onPricingTiersChanged);
    on<SettingsAutoLockChanged>(_onAutoLockChanged);
    on<SettingsReceiptSaveRequested>(_onReceiptSave);
    on<SettingsBackupRecordRequested>(_onBackupRecord);
    on<SettingsSyncToggled>(_onSyncToggled);
    on<SettingsFeedbackDismissed>(_onFeedbackDismissed);
    on<SettingsSessionRefreshAcknowledged>(_onSessionRefreshAcknowledged);
  }

  final GetShopConfiguration _getConfiguration;
  final UpdateShopConfiguration _updateConfiguration;
  final RecordShopBackup _recordBackup;
  final UpdateShopSyncSettings _updateSyncSettings;
  final int _shopId;

  Future<void> _onLoad(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(status: SettingsStatus.loading, clearError: true));
    try {
      final config = await _getConfiguration(shopId: _shopId);
      emit(
        state.copyWith(
          status: SettingsStatus.loaded,
          configuration: config,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onShopSave(
    SettingsShopSaveRequested event,
    Emitter<SettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateShopSettingsInput(
        shopName: event.name,
        shopPhone: event.phone,
        shopAddress: event.address,
      ),
      successMessage: 'Identité boutique enregistrée.',
      refreshSession: true,
    );
  }

  Future<void> _onThresholdChanged(
    SettingsThresholdChanged event,
    Emitter<SettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateShopSettingsInput(defaultAlertThreshold: event.threshold),
      successMessage: 'Seuil d\'alerte mis à jour.',
    );
  }

  Future<void> _onPricingTiersChanged(
    SettingsPricingTiersChanged event,
    Emitter<SettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateShopSettingsInput(pricingTiersEnabled: event.enabled),
      successMessage: event.enabled
          ? 'Grilles tarifaires activées.'
          : 'Grilles tarifaires désactivées.',
    );
  }

  Future<void> _onAutoLockChanged(
    SettingsAutoLockChanged event,
    Emitter<SettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateShopSettingsInput(autoLockMinutes: event.minutes),
      successMessage: 'Verrouillage automatique mis à jour.',
      refreshSession: true,
    );
  }

  Future<void> _onReceiptSave(
    SettingsReceiptSaveRequested event,
    Emitter<SettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateShopSettingsInput(receiptFooter: event.footer),
      successMessage: 'Pied de reçu enregistré.',
    );
  }

  Future<void> _onBackupRecord(
    SettingsBackupRecordRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _recordBackup(
        shopId: _shopId,
        input: RecordBackupInput(path: event.path),
      );
      final config = await _getConfiguration(shopId: _shopId);
      emit(
        state.copyWith(
          isSaving: false,
          configuration: config,
          successMessage: 'Sauvegarde enregistrée.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onSyncToggled(
    SettingsSyncToggled event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _updateSyncSettings(
        shopId: _shopId,
        input: UpdateSyncSettingsInput(enabled: event.enabled),
      );
      final config = await _getConfiguration(shopId: _shopId);
      emit(
        state.copyWith(
          isSaving: false,
          configuration: config,
          successMessage: event.enabled
              ? 'Synchronisation cloud activée.'
              : 'Synchronisation cloud désactivée.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _save(
    Emitter<SettingsState> emit,
    UpdateShopSettingsInput input, {
    required String successMessage,
    bool refreshSession = false,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final config = await _updateConfiguration(
        shopId: _shopId,
        input: input,
      );
      emit(
        state.copyWith(
          isSaving: false,
          configuration: config,
          successMessage: successMessage,
          refreshSession: refreshSession,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  void _onFeedbackDismissed(
    SettingsFeedbackDismissed event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  void _onSessionRefreshAcknowledged(
    SettingsSessionRefreshAcknowledged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(refreshSession: false));
  }
}
