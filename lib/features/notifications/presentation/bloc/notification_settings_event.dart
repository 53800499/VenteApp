part of 'notification_settings_bloc.dart';

sealed class NotificationSettingsEvent extends Equatable {
  const NotificationSettingsEvent();

  @override
  List<Object?> get props => [];
}

class NotificationSettingsLoadRequested extends NotificationSettingsEvent {
  const NotificationSettingsLoadRequested();
}

class NotificationSettingsStockToggled extends NotificationSettingsEvent {
  const NotificationSettingsStockToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class NotificationSettingsDebtToggled extends NotificationSettingsEvent {
  const NotificationSettingsDebtToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class NotificationSettingsDebtDaysChanged extends NotificationSettingsEvent {
  const NotificationSettingsDebtDaysChanged(this.days);

  final int days;

  @override
  List<Object?> get props => [days];
}

class NotificationSettingsSummaryToggled extends NotificationSettingsEvent {
  const NotificationSettingsSummaryToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class NotificationSettingsSummaryTimeChanged extends NotificationSettingsEvent {
  const NotificationSettingsSummaryTimeChanged(this.time);

  final String time;

  @override
  List<Object?> get props => [time];
}

class NotificationSettingsBackupToggled extends NotificationSettingsEvent {
  const NotificationSettingsBackupToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class NotificationSettingsGoodDayToggled extends NotificationSettingsEvent {
  const NotificationSettingsGoodDayToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}
