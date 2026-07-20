import '../entities/user_entities.dart';
import '../repositories/user_repository.dart';

class ListShopUsers {
  const ListShopUsers(this._repository);

  final UserRepository _repository;

  Future<List<ShopUser>> call({required int localShopId}) =>
      _repository.listShopUsers(localShopId: localShopId);
}

class GetUserAssignment {
  const GetUserAssignment(this._repository);

  final UserRepository _repository;

  Future<UserAssignment> call(int userId) =>
      _repository.getUserAssignment(userId);
}

class CreateShopUser {
  const CreateShopUser(this._repository);

  final UserRepository _repository;

  Future<ShopUser> call(CreateShopUserInput input) =>
      _repository.createShopUser(input);
}

class ChangeUserRole {
  const ChangeUserRole(this._repository);

  final UserRepository _repository;

  Future<ShopUser> call({
    required int userId,
    required String roleCode,
    String? reason,
  }) =>
      _repository.changeUserRole(
        userId: userId,
        roleCode: roleCode,
        reason: reason,
      );
}

class DeactivateShopUser {
  const DeactivateShopUser(this._repository);

  final UserRepository _repository;

  Future<void> call(int userId, {String? reason}) =>
      _repository.deactivateUser(userId, reason: reason);
}

class AssignUserShop {
  const AssignUserShop(this._repository);

  final UserRepository _repository;

  Future<void> call({
    required int userId,
    required int shopId,
    String? reason,
  }) =>
      _repository.assignUserShop(
        userId: userId,
        shopId: shopId,
        reason: reason,
      );
}

class GetUserShopAccess {
  const GetUserShopAccess(this._repository);

  final UserRepository _repository;

  Future<UserShopAccess> call(int userId) =>
      _repository.getUserShopAccess(userId);
}

class SyncUserShopAccess {
  const SyncUserShopAccess(this._repository);

  final UserRepository _repository;

  Future<UserShopAccess> call({
    required int userId,
    required List<ShopAccessGrant> grants,
  }) =>
      _repository.syncUserShopAccess(userId: userId, grants: grants);
}
