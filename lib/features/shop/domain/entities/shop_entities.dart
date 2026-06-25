class ManagedShop {
  const ManagedShop({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.isActive,
    required this.isDefault,
    required this.isCurrent,
    this.createdAt,
  });

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final bool isDefault;
  final bool isCurrent;
  final int? createdAt;
}

class ShopListResult {
  const ShopListResult({
    required this.activeShopId,
    required this.shops,
  });

  final int activeShopId;
  final List<ManagedShop> shops;

  List<ManagedShop> get activeShops =>
      shops.where((shop) => shop.isActive).toList();
}

class CreateShopInput {
  const CreateShopInput({
    required this.name,
    this.address,
    this.phone,
  });

  final String name;
  final String? address;
  final String? phone;
}

class UpdateShopInput {
  const UpdateShopInput({
    this.name,
    this.address,
    this.phone,
  });

  final String? name;
  final String? address;
  final String? phone;
}
