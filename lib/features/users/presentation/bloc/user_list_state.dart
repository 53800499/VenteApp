part of 'user_list_bloc.dart';

enum UserListStatus { initial, loading, loaded, failure }

class UserListState extends Equatable {
  const UserListState({
    this.status = UserListStatus.initial,
    this.users = const [],
    this.isRefreshing = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
  });

  final UserListStatus status;
  final List<ShopUser> users;
  final bool isRefreshing;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  UserListState copyWith({
    UserListStatus? status,
    List<ShopUser>? users,
    bool? isRefreshing,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return UserListState(
      status: status ?? this.status,
      users: users ?? this.users,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        users,
        isRefreshing,
        isSubmitting,
        errorMessage,
        successMessage,
      ];
}
