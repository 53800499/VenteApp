part of 'settings_bloc.dart';

enum SettingsStatus { initial, loading, loaded, failure }

class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.configuration,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.refreshSession = false,
  });

  final SettingsStatus status;
  final ShopConfiguration? configuration;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  final bool refreshSession;

  SettingsState copyWith({
    SettingsStatus? status,
    ShopConfiguration? configuration,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool? refreshSession,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SettingsState(
      status: status ?? this.status,
      configuration: configuration ?? this.configuration,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
      refreshSession: refreshSession ?? this.refreshSession,
    );
  }

  @override
  List<Object?> get props => [
        status,
        configuration,
        isSaving,
        errorMessage,
        successMessage,
        refreshSession,
      ];
}
