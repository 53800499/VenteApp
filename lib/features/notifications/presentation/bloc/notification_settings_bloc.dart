import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../domain/entities/notification_entities.dart';
import '../../domain/usecases/notification_usecases.dart';

part 'notification_settings_event.dart';
part 'notification_settings_state.dart';

class NotificationSettingsBloc
    extends Bloc<NotificationSettingsEvent, NotificationSettingsState> {
  NotificationSettingsBloc({
    required GetNotificationPreferences getPreferences,
    required UpdateNotificationPreferences updatePreferences,
    required int shopId,
  })  : _getPreferences = getPreferences,
        _updatePreferences = updatePreferences,
        _shopId = shopId,
        super(const NotificationSettingsState()) {
    on<NotificationSettingsLoadRequested>(_onLoad);
    on<NotificationSettingsStockToggled>(_onStockToggled);
    on<NotificationSettingsDebtToggled>(_onDebtToggled);
    on<NotificationSettingsDebtDaysChanged>(_onDebtDaysChanged);
    on<NotificationSettingsSummaryToggled>(_onSummaryToggled);
    on<NotificationSettingsSummaryTimeChanged>(_onSummaryTimeChanged);
    on<NotificationSettingsBackupToggled>(_onBackupToggled);
    on<NotificationSettingsGoodDayToggled>(_onGoodDayToggled);
  }

  final GetNotificationPreferences _getPreferences;
  final UpdateNotificationPreferences _updatePreferences;
  final int _shopId;

  Future<void> _onLoad(
    NotificationSettingsLoadRequested event,
    Emitter<NotificationSettingsState> emit,
  ) async {
    emit(state.copyWith(status: NotificationSettingsStatus.loading));
    try {
      final prefs = await _getPreferences(shopId: _shopId);
      emit(
        state.copyWith(
          status: NotificationSettingsStatus.success,
          preferences: prefs,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: NotificationSettingsStatus.failure,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _save(
    Emitter<NotificationSettingsState> emit,
    UpdateNotificationSettingsInput input,
  ) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final prefs = await _updatePreferences(shopId: _shopId, input: input);
      emit(
        state.copyWith(
          isSaving: false,
          preferences: prefs,
          status: NotificationSettingsStatus.success,
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

  Future<void> _onStockToggled(
    NotificationSettingsStockToggled event,
    Emitter<NotificationSettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateNotificationSettingsInput(enableStockAlerts: event.enabled),
    );
  }

  Future<void> _onDebtToggled(
    NotificationSettingsDebtToggled event,
    Emitter<NotificationSettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateNotificationSettingsInput(enableDebtReminders: event.enabled),
    );
  }

  Future<void> _onDebtDaysChanged(
    NotificationSettingsDebtDaysChanged event,
    Emitter<NotificationSettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateNotificationSettingsInput(debtReminderDays: event.days),
    );
  }

  Future<void> _onSummaryToggled(
    NotificationSettingsSummaryToggled event,
    Emitter<NotificationSettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateNotificationSettingsInput(enableDailySummary: event.enabled),
    );
  }

  Future<void> _onSummaryTimeChanged(
    NotificationSettingsSummaryTimeChanged event,
    Emitter<NotificationSettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateNotificationSettingsInput(dailySummaryTime: event.time),
    );
  }

  Future<void> _onBackupToggled(
    NotificationSettingsBackupToggled event,
    Emitter<NotificationSettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateNotificationSettingsInput(enableBackupReminder: event.enabled),
    );
  }

  Future<void> _onGoodDayToggled(
    NotificationSettingsGoodDayToggled event,
    Emitter<NotificationSettingsState> emit,
  ) async {
    await _save(
      emit,
      UpdateNotificationSettingsInput(enableGoodDayAlert: event.enabled),
    );
  }
}
