import '../entities/user_entities.dart';

abstract class UserRepository {
  Future<List<ShopUser>> listShopUsers({required int localShopId});

  Future<UserAssignment> getUserAssignment(int userId);

  Future<ShopUser> createShopUser(CreateShopUserInput input);

  Future<ShopUser> changeUserRole({
    required int userId,
    required String roleCode,
    String? reason,
  });

  Future<void> deactivateUser(int userId, {String? reason});

  Future<void> assignUserShop({
    required int userId,
    required int shopId,
    String? reason,
  });
}
