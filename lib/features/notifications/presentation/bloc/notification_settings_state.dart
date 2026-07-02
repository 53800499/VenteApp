part of 'notification_settings_bloc.dart';

enum NotificationSettingsStatus { initial, loading, success, failure }

class NotificationSettingsState extends Equatable {
  const NotificationSettingsState({
    this.status = NotificationSettingsStatus.initial,
    this.preferences,
    this.isSaving = false,
    this.errorMessage,
  });

  final NotificationSettingsStatus status;
  final NotificationPreferences? preferences;
  final bool isSaving;
  final String? errorMessage;

  NotificationSettingsState copyWith({
    NotificationSettingsStatus? status,
    NotificationPreferences? preferences,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationSettingsState(
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, preferences, isSaving, errorMessage];
}
