class ShopItemDto {
  const ShopItemDto({
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

  factory ShopItemDto.fromJson(Map<String, dynamic> json) {
    return ShopItemDto(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
      isCurrent: json['isCurrent'] as bool? ?? false,
      createdAt: json['createdAt'] as int?,
    );
  }
}

class ShopListDataDto {
  const ShopListDataDto({
    required this.activeShopId,
    required this.shops,
  });

  final int activeShopId;
  final List<ShopItemDto> shops;

  factory ShopListDataDto.fromJson(Map<String, dynamic> json) {
    return ShopListDataDto(
      activeShopId: json['activeShopId'] as int,
      shops: (json['shops'] as List<dynamic>)
          .map((e) => ShopItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ShopDetailDto {
  const ShopDetailDto({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.isActive,
    required this.isDefault,
    this.createdAt,
  });

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final bool isDefault;
  final int? createdAt;

  factory ShopDetailDto.fromJson(Map<String, dynamic> json) {
    return ShopDetailDto(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] as int?,
    );
  }
}
