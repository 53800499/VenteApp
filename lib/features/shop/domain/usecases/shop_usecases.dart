import '../entities/shop_entities.dart';
import '../repositories/shop_repository.dart';

class ListShops {
  const ListShops(this._repository);

  final ShopRepository _repository;

  Future<ShopListResult> call() => _repository.listShops();
}

class GetShop {
  const GetShop(this._repository);

  final ShopRepository _repository;

  Future<ManagedShop> call(int id) => _repository.getShop(id);
}

class CreateShop {
  const CreateShop(this._repository);

  final ShopRepository _repository;

  Future<ManagedShop> call(CreateShopInput input) =>
      _repository.createShop(input);
}

class UpdateShop {
  const UpdateShop(this._repository);

  final ShopRepository _repository;

  Future<ManagedShop> call(int id, UpdateShopInput input) =>
      _repository.updateShop(id, input);
}

class DeactivateShop {
  const DeactivateShop(this._repository);

  final ShopRepository _repository;

  Future<void> call(int id, {String? reason}) =>
      _repository.deactivateShop(id, reason: reason);
}

class SetDefaultShop {
  const SetDefaultShop(this._repository);

  final ShopRepository _repository;

  Future<void> call(int id) => _repository.setDefaultShop(id);
}
