part of 'user_list_bloc.dart';

sealed class UserListEvent extends Equatable {
  const UserListEvent();

  @override
  List<Object?> get props => [];
}

class UserListLoadRequested extends UserListEvent {
  const UserListLoadRequested();
}

class UserListRefreshRequested extends UserListEvent {
  const UserListRefreshRequested();
}

class UserCreateRequested extends UserListEvent {
  const UserCreateRequested(this.input);

  final CreateShopUserInput input;

  @override
  List<Object?> get props => [input];
}

class UserChangeRoleRequested extends UserListEvent {
  const UserChangeRoleRequested({
    required this.userId,
    required this.role,
    this.reason,
  });

  final int userId;
  final UserRole role;
  final String? reason;

  @override
  List<Object?> get props => [userId, role, reason];
}

class UserDeactivateRequested extends UserListEvent {
  const UserDeactivateRequested({required this.userId, this.reason});

  final int userId;
  final String? reason;

  @override
  List<Object?> get props => [userId, reason];
}

class UserAssignShopRequested extends UserListEvent {
  const UserAssignShopRequested({
    required this.userId,
    required this.shopId,
    this.reason,
  });

  final int userId;
  final int shopId;
  final String? reason;

  @override
  List<Object?> get props => [userId, shopId, reason];
}
