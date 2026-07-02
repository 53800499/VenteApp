part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

class SettingsShopSaveRequested extends SettingsEvent {
  const SettingsShopSaveRequested({
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;

  @override
  List<Object?> get props => [name, phone, address];
}

class SettingsThresholdChanged extends SettingsEvent {
  const SettingsThresholdChanged(this.threshold);

  final int threshold;

  @override
  List<Object?> get props => [threshold];
}

class SettingsAutoLockChanged extends SettingsEvent {
  const SettingsAutoLockChanged(this.minutes);

  final int minutes;

  @override
  List<Object?> get props => [minutes];
}

class SettingsReceiptSaveRequested extends SettingsEvent {
  const SettingsReceiptSaveRequested(this.footer);

  final String footer;

  @override
  List<Object?> get props => [footer];
}

class SettingsBackupRecordRequested extends SettingsEvent {
  const SettingsBackupRecordRequested({this.path});

  final String? path;

  @override
  List<Object?> get props => [path];
}

class SettingsSyncToggled extends SettingsEvent {
  const SettingsSyncToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class SettingsFeedbackDismissed extends SettingsEvent {
  const SettingsFeedbackDismissed();
}

class SettingsSessionRefreshAcknowledged extends SettingsEvent {
  const SettingsSessionRefreshAcknowledged();
}
