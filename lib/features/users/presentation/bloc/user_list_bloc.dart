import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entities.dart';
import '../../domain/usecases/user_usecases.dart';

part 'user_list_event.dart';
part 'user_list_state.dart';

class UserListBloc extends Bloc<UserListEvent, UserListState> {
  UserListBloc({
    required ListShopUsers listShopUsers,
    required CreateShopUser createShopUser,
    required ChangeUserRole changeUserRole,
    required DeactivateShopUser deactivateShopUser,
    required AssignUserShop assignUserShop,
    required int localShopId,
    required int currentUserId,
  })  : _listShopUsers = listShopUsers,
        _createShopUser = createShopUser,
        _changeUserRole = changeUserRole,
        _deactivateShopUser = deactivateShopUser,
        _assignUserShop = assignUserShop,
        _localShopId = localShopId,
        _currentUserId = currentUserId,
        super(const UserListState()) {
    on<UserListLoadRequested>(_onLoad);
    on<UserListRefreshRequested>(_onRefresh);
    on<UserCreateRequested>(_onCreate);
    on<UserChangeRoleRequested>(_onChangeRole);
    on<UserDeactivateRequested>(_onDeactivate);
    on<UserAssignShopRequested>(_onAssignShop);
    on<UserFeedbackDismissed>(_onFeedbackDismissed);
  }

  final ListShopUsers _listShopUsers;
  final CreateShopUser _createShopUser;
  final ChangeUserRole _changeUserRole;
  final DeactivateShopUser _deactivateShopUser;
  final AssignUserShop _assignUserShop;
  final int _localShopId;
  final int _currentUserId;

  Future<void> _onLoad(
    UserListLoadRequested event,
    Emitter<UserListState> emit,
  ) async {
    emit(state.copyWith(status: UserListStatus.loading, clearError: true));
    await _fetch(emit);
  }

  Future<void> _onRefresh(
    UserListRefreshRequested event,
    Emitter<UserListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<UserListState> emit) async {
    try {
      final users = await _listShopUsers(localShopId: _localShopId);
      emit(
        state.copyWith(
          status: UserListStatus.loaded,
          users: users,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: UserListStatus.failure,
          errorMessage: friendlyErrorMessage(e),
          isRefreshing: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: UserListStatus.failure,
          errorMessage: friendlyErrorMessage(error),
          isRefreshing: false,
        ),
      );
    }
  }

  Future<void> _onCreate(
    UserCreateRequested event,
    Emitter<UserListState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _createShopUser(event.input);
      await _fetch(emit);
      emit(state.copyWith(
        isSubmitting: false,
        successMessage: 'Utilisateur créé.',
      ));
    } on Failure catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onChangeRole(
    UserChangeRoleRequested event,
    Emitter<UserListState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _changeUserRole(
        userId: event.userId,
        roleCode: event.roleCode,
        reason: event.reason,
      );
      await _fetch(emit);
      emit(state.copyWith(
        isSubmitting: false,
        successMessage: 'Rôle mis à jour.',
      ));
    } on Failure catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onDeactivate(
    UserDeactivateRequested event,
    Emitter<UserListState> emit,
  ) async {
    if (event.userId == _currentUserId) {
      emit(
        state.copyWith(
          errorMessage: 'Impossible de désactiver votre propre compte.',
        ),
      );
      return;
    }
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _deactivateShopUser(event.userId, reason: event.reason);
      await _fetch(emit);
      emit(state.copyWith(
        isSubmitting: false,
        successMessage: 'Utilisateur désactivé.',
      ));
    } on Failure catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onAssignShop(
    UserAssignShopRequested event,
    Emitter<UserListState> emit,
  ) async {
    if (event.userId == _currentUserId) {
      emit(
        state.copyWith(
          errorMessage: 'Impossible de modifier votre propre affectation.',
        ),
      );
      return;
    }
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _assignUserShop(
        userId: event.userId,
        shopId: event.shopId,
        reason: event.reason,
      );
      await _fetch(emit);
      emit(state.copyWith(
        isSubmitting: false,
        successMessage: 'Utilisateur réaffecté.',
      ));
    } on Failure catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  void _onFeedbackDismissed(
    UserFeedbackDismissed event,
    Emitter<UserListState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
